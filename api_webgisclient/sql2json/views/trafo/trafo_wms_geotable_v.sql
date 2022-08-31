/* 
 * Gibt die "identifizierenden" Eigenschaften einer postgis Geo-Tabelle zurück
 */
CREATE VIEW simi.trafo_wms_geotable_v AS 

SELECT 
  tv.id AS  tv_id,
  jsonb_build_object(
    'dbconnection', concat('service=', db.db_service_url),
    'schema', schema_name,
    'table', COALESCE(row_filter_view_name, table_name),
    'unique_key', id_field_name,
    'geometry_field', geo_field_name,
    'geometry_type', geo_type,
    'srid', geo_epsg_code
    ) AS tbl_json
FROM  
  simi.simidata_table_view tv
JOIN 
  simi.simidata_postgres_table tbl ON tv.postgres_table_id = tbl.id
JOIN 
  simi.simidata_db_schema s ON tbl.db_schema_id = s.id 
JOIN 
  simi.simidata_postgres_db db ON s.postgres_db_id = db.id 
WHERE
    geo_field_name IS NOT NULL
  AND
    geo_type IS NOT NULL
  AND
    geo_epsg_code IS NOT NULL
;
