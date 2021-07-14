
WITH 

dummy_fields AS (
  
)

tv_pgtable_props AS ( --$td merge TO view simi.trafo_wms_pg_table_v, adapt wms SQL
  SELECT 
    tv.id AS tv_id,
    'vector' AS vectype,
    jsonb_build_object(
      'dbconnection', db_service_url,
      'data_set_name', concat_ws('.', schema_name, table_name),
      'primary_key', id_field_name,
      'geometry_field', geo_field_name,
      'geometry_type', geo_type,
      'srid', geo_epsg_code
    ) AS tbl_json
  FROM 
    simi.simidata_table_view tv
  JOIN 
    simi.simidata_postgres_table tbl ON tv.postgres_table_id = tbl.id
  JOIN 
    simi.simidata_data_theme dt ON tbl.data_theme_id = dt.id 
  JOIN 
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL
),

rasterview_ds_props AS (
  SELECT 
    jsonb_build_object(
      'datasource', "path",
      'srid', '2056'
    ) AS raster_ds,
    rv.id AS rv_id
  FROM
    simi.simi.simidata_raster_view rv
  JOIN
    simi.simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id
),

dsv AS (
  SELECT 
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', dp.identifier,
        'display', COALESCE(dp.title, dp.identifier),
        'description', COALESCE(description, 'dummy description'),
        'qml', 'dummy',--encode(convert_to(COALESCE(style_desktop, style_server), 'UTF8'), 'base64'),
        'opacity', (255 - transparency),
        'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', 'dummy'),
        'datatype', COALESCE(vectype, 'raster'),
        'postgis_datasource', tbl_json,
        'raster_datasource', raster_ds,
        'type', 'datasetview',
        'visibility', TRUE, 
        'queryable', TRUE, 
        'synonyms', jsonb_build_array(),
        'keywords', jsonb_build_array(),
        'contacts', CAST('[{"organisation":{"id":-99,"name":"dummy contact org"}}]' AS jsonb)     
      )
    ) AS dsv_json,  
    root_published,
    dsv.id AS dsv_id
  FROM
    simi.simi.simidata_data_set_view dsv
  JOIN
    simi.simi.simiproduct_single_actor sa ON dsv.id = sa.id
  JOIN
    simi.simi.simiproduct_data_product dp ON dsv.id = dp.id
  JOIN
    simi.trafo_wms_dp_pubstate_v dps ON dsv.id = dps.dp_id 
  LEFT JOIN
    tv_pgtable_props t ON dsv.id = t.tv_id
  LEFT JOIN
    rasterview_ds_props r ON dsv.id = r.rv_id
  WHERE 
    published IS TRUE 
),

facade AS (
  
  
),



root_layer AS (
  SELECT
    jsonb_agg(identifier) AS root_layer_json
  FROM
    simi.trafo_wms_dp_pubstate_v
  WHERE
    root_published IS TRUE   
),

root AS (
  SELECT 
    jsonb_build_object(
      'identifier', 'ch.so.wms',
      'display', 'ch.so.wms',
      'type', 'layergroup',
      'description', '',
      'layers', root_layer_json,
      'synonyms', jsonb_build_array(),
      'keywords', jsonb_build_array(),
      'contacts', CAST('[{"organisation":{"id":-99,"name":"dummy contact org"}}]' AS jsonb)       
    ) AS root_json
  FROM
    root_layer
)

SELECT root_json AS lyr_json FROM root
UNION ALL 
SELECT dsv_json AS lyr_json FROM dsv