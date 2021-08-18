WITH 

geo_tbl AS ( --Tables mit vollständig ausgefüllten Infos zur Geometrie-Spalte
  SELECT
    jsonb_build_object(
      'geometry_column', geo_field_name,
      'geometry_type', geo_type,
      'srid', geo_epsg_code
    ) AS geo_props_obj,
    id AS tbl_id
  FROM
    simi.simidata_postgres_table t
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL
),

tbl AS (
  SELECT 
    schema_name,
    table_name,
    id_field_name,
    'postgresql:///?service=' || db.db_service_url AS pg_service_url,
    geo_props_obj,
    tbl_id
  FROM
    simi.simidata_postgres_table t
  JOIN
    simi.simidata_data_theme dt ON t.data_theme_id = dt.id
  JOIN
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
  LEFT JOIN
    geo_tbl geo ON t.id = geo.tbl_id 
),

attr_typemap AS (
  SELECT 
    * 
  FROM (
    VALUES 
      ('bool', 'boolean'),
      ('cardinal_number', 'integer'),
      ('char', 'character'),
      ('character_data', 'text'),
      ('date', 'date'),
      ('float4', 'real'),
      ('float8', 'double precision'),
      ('int2', 'smallint'),
      ('int4', 'integer'),
      ('int8', 'bigint'),
      ('json', 'json'),
      ('jsonb', 'jsonb'),
      ('numeric', 'numeric'),
      ('oid', 'bigint'),
      ('text', 'text'),
      ('time', 'time'),
      ('timestamp', 'timestamp without time zone'),
      ('timestamptz', 'timestamp with time zone'),
      ('uuid', 'uuid'),
      ('varchar', 'character varying'),
      ('yes_or_no', 'boolean')
  ) 
  AS t (pg_cat_type, srv_type)
),

tbl_fields AS (
  SELECT 
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', "name",
        'data_type', COALESCE(srv_type, 'text'),
        'constraints', ('{"maxlength": ' || str_length || ' }')::jsonb
      )
    ) AS field_obj,
    CASE 
      WHEN type_name IS NULL THEN 1
      ELSE 0
    END AS type_missing_count,
    CASE 
      WHEN srv_type IS NULL THEN 1
      ELSE 0
    END AS type_defaulted_count,   
    id AS tf_id
  FROM
    simi.simidata_table_field f
  LEFT JOIN
    attr_typemap tm ON f.type_name = tm.pg_cat_type
),

tableview_fields AS (
  SELECT
    jsonb_agg(field_obj) AS fields_arr,
    sum(type_missing_count) AS type_missing_count,
    sum(type_defaulted_count) AS type_defaulted_count,
    table_view_id
  FROM
    simi.simidata_view_field vf
  JOIN
    tbl_fields tf ON vf.table_field_id = tf.tf_id
  GROUP BY
    table_view_id
),

tableview AS (
  SELECT 
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', dp.identifier,
        'db_url', pg_service_url,
        'schema', schema_name,
        'table_name', table_name,
        'primary_key', id_field_name,
        'geometry', geo_props_obj,
        'fields', COALESCE(fields_arr, '[]'::jsonb) --$td remove AFTER SCHEMA update
      )
    ) AS tv_obj,
    dsv.raw_download,
    (dp_pub.dp_id IS NOT NULL) AS wms_published,
    COALESCE(type_missing_count, 0) AS type_missing_count,
    COALESCE(type_defaulted_count, 0) AS type_defaulted_count
  FROM
    simi.simidata_table_view tv
  JOIN
    simi.simidata_data_set_view dsv ON tv.id = dsv.id
  JOIN
    simi.simi.simiproduct_data_product dp ON tv.id = dp.id
  JOIN
    tbl ON tv.postgres_table_id = tbl.tbl_id
  LEFT JOIN
    simi.trafo_published_dp_v dp_pub ON tv.id = dp_pub.dp_id
  LEFT JOIN
    tableview_fields tf ON tv.id = tf.table_view_id
)

SELECT
  tv_obj
FROM 
  tableview
WHERE
    (wms_published OR raw_download) -- Neben raw_download=TRUE auch für Ebenen aktivieren, welche wms-publiziert sind, um die Abhängigkeit der WGC-URL-Schnittstelle auf den Dataservice zu "befriedigen"
  AND
    type_missing_count = 0 -- Ebenen mit fehlenden Attributtyp-Informationen bewusst ausschliessen, damit Fehler schneller gefunden wird
