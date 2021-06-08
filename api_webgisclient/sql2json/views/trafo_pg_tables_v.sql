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