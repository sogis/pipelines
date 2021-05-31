
-- trafo_pg_tables_v
DROP VIEW IF EXISTS simi.trafo_pg_tables_v;

CREATE VIEW simi.trafo_pg_tables_v AS 
  SELECT 
    tbl.id AS  table_id,
    (geo_field_name IS NOT NULL) AS has_geometry,
    jsonb_build_object(
      'dbconnection', db_service_url,
      'schema', schema_name,
      'table', table_name,
      'unique_key', id_field_name,
      'geometry_field', geo_field_name,
      'geometry_type', geo_type,
      'srid', geo_epsg_code
    ) AS tbl_json
  FROM  
    simi.simidata_postgres_table tbl 
  JOIN 
    simi.simidata_data_theme dt ON tbl.data_theme_id = dt.id 
  JOIN 
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
;

-- trafo_tableview_attributes_v
DROP VIEW IF EXISTS simi.trafo_tableview_attributes_v;

CREATE VIEW simi.trafo_tableview_attributes_v AS 

  WITH 
  
  tv_attribute AS (
    SELECT  
      vf.table_view_id,
      jsonb_build_object(
        'name', "name",
        'alias', coalesce(alias, name)
      ) AS attr_json
    FROM  
      simi.simidata_view_field vf
    JOIN 
      simi.simidata_table_field tf ON vf.table_field_id = tf.id 
  )
  
  SELECT 
    table_view_id,
    jsonb_agg(attr_json) AS attr_json
  FROM 
    tv_attribute
  GROUP BY 
    table_view_id
;