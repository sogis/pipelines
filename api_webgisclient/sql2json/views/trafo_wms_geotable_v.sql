DROP VIEW IF EXISTS simi.trafo_wms_geotable_v;

/* 
 * Gibt die "identifizierenden" Eigenschaften einer postgis Geo-Tabelle zurück
 */
CREATE VIEW simi.trafo_wms_geotable_v AS 

WITH 

pgconf_name_db_map AS (
  SELECT 
    * 
  FROM (
    VALUES 
      ('Geo DB alt', 'name1'),
      ('DB Pub', 'name2'), 
      ('DB Edit', 'name3'),
      ('Oereb DB', 'name4')
  ) 
  AS t (db_name, pg_conf_name)
)


SELECT 
  tbl.id AS  table_id,
  jsonb_build_object(
    'dbconnection', COALESCE(pg_conf_name, '!!ERROR DB Name mismatch in cte pgconf_name_db_map'),
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
LEFT JOIN
  pgconf_name_db_map m ON db.db_name = m.db_name
WHERE
    geo_field_name IS NOT NULL
  AND
    geo_type IS NOT NULL
  AND
    geo_epsg_code IS NOT NULL
;

GRANT SELECT ON TABLE simi.trafo_wms_geotable_v TO simi_write;