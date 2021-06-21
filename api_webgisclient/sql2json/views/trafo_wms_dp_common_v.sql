DROP VIEW IF EXISTS simi.trafo_wms_dp_common_v;

CREATE VIEW simi.trafo_wms_dp_common_v AS 

WITH 

dp_common_props_bgmap AS (
  SELECT 
    id AS bgmap_id
  FROM
    simi.simiproduct_map
  WHERE 
    background IS TRUE 
),

dp_common_props_tableview AS (
  SELECT 
    v.id AS tv_id,
    db.db_name AS db_name
  FROM
    simi.simidata_table_view v
  JOIN
    simi.simidata_postgres_table t ON v.postgres_table_id = t.id 
  JOIN
    simi.simidata_data_theme dt ON t.data_theme_id = dt.id
  JOIN
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
)

SELECT 
  identifier,
  COALESCE(title, identifier) as title,
  ps.id AS pub_scope_id,
  pub_to_wms,
  dp.id AS dp_id
FROM 
  simi.simiproduct_data_product dp 
JOIN  
  simi.simiproduct_data_product_pub_scope ps on dp.pub_scope_id = ps.id 
JOIN
  simi.trafo_tmp_pubdb_dps_v pdb ON dp.id = pdb.dp_id
LEFT JOIN
  dp_common_props_bgmap bg ON dp.id = bg.bgmap_id
LEFT JOIN 
  dp_common_props_tableview tv ON dp.id = tv.tv_id    
;