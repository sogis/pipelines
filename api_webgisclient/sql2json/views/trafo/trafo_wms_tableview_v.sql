DROP VIEW IF EXISTS simi.trafo_wms_tableview_v CASCADE;

CREATE VIEW simi.trafo_wms_tableview_v AS 

/* Gibt die für ogc-service und qgis-server relevanten Informationen
 * einer Tableview aus.
 * 
 * Die Attribut-Arrays werden mal als name/alias array und mal als einfaches 
 * name array benötigt. Darum sind in dieser Basisview beide Ausprägungen enthalten
 * */
WITH

tv_attribute AS (
  SELECT  
    vf.table_view_id AS tv_id,
    jsonb_build_object(
      'name', "name",
      'alias', coalesce(alias, name)
    ) AS attr_name_alias_js,
    jsonb_build_object(
      'name', "name"
    ) AS attr_name,
    vf.sort AS attr_sort
  FROM  
    simi.simidata_view_field vf
  JOIN 
    simi.simidata_table_field tf ON vf.table_field_id = tf.id 
),

tv_attributes AS (
  SELECT
    tv_id,
    jsonb_agg(attr_name_alias_js ORDER BY attr_sort) AS attr_name_alias_js,
    jsonb_agg(attr_name ORDER BY attr_sort) AS attr_name_js
  FROM 
    tv_attribute
  GROUP BY
    tv_id
)

SELECT 
  dp.identifier,
  dp.title_ident,
  dp.root_published,
  a.attr_name_js,
  a.attr_name_alias_js,
  tv.id AS tv_id,
  tv.postgres_table_id
FROM
  simi.trafo_published_dp_v dp
JOIN 
  simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
JOIN 
  simi.simidata_table_view tv ON dsv.id = tv.id
JOIN 
  simi.trafo_wms_geotable_v tbl ON tv.postgres_table_id = tbl.table_id
LEFT JOIN
  tv_attributes a ON tv.id = a.tv_id
;

GRANT SELECT ON TABLE simi.trafo_wms_tableview_v TO simi_write;
GRANT SELECT ON TABLE simi.trafo_wms_tableview_v TO simi_read;