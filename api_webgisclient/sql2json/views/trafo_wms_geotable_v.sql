DROP VIEW IF EXISTS simi.trafo_wms_geotable_v;

/* 
 * Gibt die "identifizierenden" Eigenschaften einer postgis Geo-Tabelle zurück
 */
CREATE VIEW simi.trafo_wms_geotable_v AS 
  SELECT 
    tbl.id AS  table_id,
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
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL
;