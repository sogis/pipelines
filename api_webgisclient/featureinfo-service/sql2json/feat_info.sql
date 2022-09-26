WITH

tv_with_geom AS (
  SELECT 
    attr_props_json,
    tv.id AS tv_id
  FROM
    simi.simidata_table_view tv 
  JOIN
    simi.trafo_wms_geotable_v tbl ON tv.id = tbl.tv_id
  JOIN
    simi.trafo_tableview_attr_with_geo_v a ON tv.id = a.tv_id
),

dsv_dependency_unique AS ( -- Gibt auch bei Fehlkonfigurationen pro Abhängigkeits- (Featinfo, Report, ...) maximal eine anzuzeigende Abhängigkeit zurück
  SELECT 
    data_set_view_id,
    d.dtype AS dependency_type,
    (max(dependency_id::varchar))::uuid AS dependency_id
  FROM
    simi.simiextended_relation r
  JOIN
    simi.simiextended_dependency d ON r.dependency_id = d.id
  WHERE
    r.relation_type = '1_display'
  GROUP BY
    data_set_view_id,
    d.dtype
),

report_datasources AS (
    SELECT 
    dependency_id,
    db_service_url
  FROM
    simi.simiextended_relation r
  JOIN
    simi.simiextended_dependency d ON r.dependency_id = d.id
  JOIN
    simi.simi.simidata_table_view tv ON r.data_set_view_id = tv.id 
  JOIN
    simi.simi.simidata_postgres_table t ON tv.postgres_table_id = t.id 
  JOIN 
    simi.simi.simidata_db_schema s ON t.db_schema_id = s.id
  JOIN 
    simi.simi.simidata_postgres_db db ON s.postgres_db_id = db.id 
  WHERE 
      r.relation_type = '2_data'
    AND
      d.dtype = 'simiExtended_FeatureInfo'
  GROUP BY 
    dependency_id,
    db_service_url
),

report_with_unique_datasource AS ( -- Aus Datenabhängigkeiten folgende db_service_url für Report mit SQL-Abfragen. HAVING count(*) = 1 stellt sicher, dass nur eindeutige ausgegeben werden
  SELECT 
    dependency_id,
    max(db_service_url) AS db_service_url
  FROM
    report_datasources
  GROUP BY
    dependency_id
  HAVING count(*) = 1
),

custom_info AS (
  SELECT
    py_module_name,
    sql_query, 
    display_template,
    CASE
      WHEN sql_query IS NOT NULL THEN 'sql'
      WHEN py_module_name IS NOT NULL THEN 'module'
      ELSE 'wms'
    END AS info_type,
    CASE
      WHEN sql_query IS NOT NULL THEN COALESCE('postgresql:///?service=' || db_service_url, 'err-no-db-url')
      ELSE NULL
    END AS sql_service_name,
    data_set_view_id
  FROM
    simi.simiextended_dependency d
  JOIN
    dsv_dependency_unique dd ON d.id = dd.dependency_id
  LEFT JOIN
    report_with_unique_datasource ds ON d.id = ds.dependency_id
  WHERE
    dependency_type = 'simiExtended_FeatureInfo'
),

custom_info_json AS (
  SELECT
    jsonb_strip_nulls(
      jsonb_build_object(
        'type', info_type,
        'db_url', sql_service_name,
        'sql_base64', encode(convert_to(sql_query, 'UTF8'), 'base64'),
        'module', py_module_name,
        'template_base64', encode(convert_to(display_template, 'UTF8'), 'base64')
      )
    ) AS info_json,
    data_set_view_id
  FROM
    custom_info
),

feature_report AS (
  SELECT
    name AS rep_name,
    data_set_view_id
  FROM
    simi.simiextended_dependency d
  JOIN
    dsv_dependency_unique dd ON d.id = dd.dependency_id
  WHERE
    dependency_type = 'simiExtended_Report'
),

dsv AS (
  SELECT 
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', identifier,
        'title', title_ident,
        'attributes', attr_props_json,
        'info_template', info_json,
        'feature_report', rep_name
      )
    ) AS dsv_json,
    root_published,
    dsv.id AS dsv_id
  FROM
    simi.simidata_data_set_view dsv
  JOIN
    simi.trafo_published_dp_v dp ON dsv.id = dp.dp_id
  LEFT JOIN
    tv_with_geom tg ON dsv.id = tg.tv_id
  LEFT JOIN
    custom_info_json i ON dsv.id = i.data_set_view_id
  LEFT JOIN
    feature_report rep ON dsv.id = rep.data_set_view_id 
),

facade_dsv AS (
  SELECT
    jsonb_agg(dsv_json) AS dsv_json,
    facade_layer_id AS fl_id
  FROM
    dsv d
  JOIN
    simi.simiproduct_properties_in_facade pif ON d.dsv_id = pif.data_set_view_id 
  GROUP BY 
    facade_layer_id
),

facade AS (
  SELECT
    jsonb_build_object(
        'name', identifier,
        'title', title_ident,
        'layers', dsv_json,
        'hide_sublayers', TRUE
    ) AS fl_json,
    root_published,
    fl.id AS fl_id
  FROM
    simi.simiproduct_facade_layer fl
  JOIN
    simi.trafo_published_dp_v dp ON fl.id = dp.dp_id
  JOIN
    facade_dsv fd ON fl.id = fd.fl_id
),

singleactor AS (
  SELECT dsv_json AS sa_json, dsv_id AS sa_id FROM dsv
  UNION ALL
  SELECT fl_json AS sa_json, fl_id AS sa_id FROM facade
),

prodlist_sa AS (
  SELECT
    jsonb_agg(sa_json) AS sa_json,
    pil.product_list_id AS pl_id
  FROM
    singleactor s
  JOIN
    simi.simiproduct_properties_in_list pil ON s.sa_id = pil.single_actor_id 
  GROUP BY 
    pil.product_list_id
),

layergroup AS (
  SELECT
    jsonb_build_object(
        'name', identifier,
        'title', title_ident,
        'layers', sa_json
    ) AS lg_json,
    root_published,
    lg.id AS lg_id
  FROM
    simi.simiproduct_layer_group lg
  JOIN
    simi.trafo_published_dp_v dp ON lg.id = dp.dp_id
  JOIN
    prodlist_sa sa ON lg.id = sa.pl_id
),

dataprod_union AS (
  SELECT lg_json AS dp_json, root_published, lg_id AS dp_id FROM layergroup
  UNION ALL 
  SELECT fl_json AS dp_json, root_published, fl_id AS dp_id FROM facade
  UNION ALL 
  SELECT dsv_json AS dp_json, root_published, dsv_id AS dp_id FROM dsv
)

SELECT 
  dp_json
FROM
  dataprod_union
WHERE
  root_published IS TRUE

