
DROP VIEW IF EXISTS simi.trafo_tableview_attr_with_geo_v CASCADE;

CREATE VIEW simi.trafo_tableview_attr_with_geo_v AS 

/* Gibt die Attribute (Spalten) einer Tableview inkl. Geometrie-Platzhalterspalte zurück.
 * 
 * attr_names_json: Array von Strings der technischen Attributnamen
 * attr_3props_json: Array mit Attribut-Objekten. 
 * Jedes Objekt mit den Eigenschaften name, alias, format (Null-Werte werden mit jsonb_strip_nulls(...) entfernt). 
 * */
WITH 

tableview_nongeo_attr AS (
  SELECT
    table_view_id as tv_id,
    tf."name" as attr_name,
    COALESCE(tf."alias",tf."name") as attr_alias_name,
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', name,
        'alias', alias,
        'format_base64', encode(convert_to(wms_fi_format, 'UTF8'), 'base64'),
        'json_attribute_aliases', display_props4_json::jsonb
      )
    ) AS attr_props_obj,
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', coalesce(alias,name),
        'alias', alias,
        'format_base64', encode(convert_to(wms_fi_format, 'UTF8'), 'base64'),
        'json_attribute_aliases', display_props4_json::jsonb
      )
    ) AS attr_alias_props_obj,
    vf.sort 
  FROM 
    simi.simidata_view_field vf 
  JOIN
    simi.simidata_table_field tf on vf.table_field_id = tf.id 
),
    
tableview_geo_attr as ( 
  SELECT  
    tv.id as tv_id,
    'geometry' AS attr_name,
    'geometry' AS attr_alias_name,
    jsonb_build_object(
      'name', 'geometry'
    ) AS attr_props_obj,
    jsonb_build_object(
      'name', 'geometry'
    ) AS attr_alias_props_obj,
    99999 AS sort
  FROM  
    simi.simidata_table_view tv
  JOIN 
    simi.simidata_postgres_table t ON tv.postgres_table_id = t.id
  WHERE 
      t.geo_field_name IS NOT NULL
    AND
      t.geo_type IS NOT NULL
    AND 
      t.geo_epsg_code IS NOT NULL 
),

tableview_attr_union AS (
  SELECT tv_id, attr_name, attr_alias_name,attr_props_obj,attr_alias_props_obj, sort FROM tableview_nongeo_attr
  UNION ALL 
  SELECT tv_id, attr_name, attr_alias_name, attr_props_obj, attr_alias_props_obj, sort FROM tableview_geo_attr
)

SELECT 
  tv_id,
  jsonb_agg(attr_name ORDER BY sort) AS attr_names_json,
  jsonb_agg(attr_alias_name ORDER BY sort) AS attr_alias_names_json,
  jsonb_agg(attr_props_obj ORDER BY sort) AS attr_props_json,
  jsonb_agg(attr_alias_props_obj ORDER BY sort) AS attr_alias_props_json
FROM
  tableview_attr_union
GROUP BY 
  tv_id
;

GRANT SELECT ON TABLE simi.trafo_tableview_attr_with_geo_v TO simi_write;
GRANT SELECT ON TABLE simi.trafo_tableview_attr_with_geo_v TO simi_read;
GRANT SELECT ON TABLE simi.trafo_tableview_attr_with_geo_v TO sogis_service;





