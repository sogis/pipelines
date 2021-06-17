DROP VIEW IF EXISTS simi.trafo_wms_tableview_attribute_v;

CREATE VIEW simi.trafo_wms_tableview_attribute_v AS 

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