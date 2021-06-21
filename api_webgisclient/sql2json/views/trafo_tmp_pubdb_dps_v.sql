
DROP VIEW IF EXISTS simi.trafo_tmp_pubdb_dps_v;

CREATE VIEW simi.trafo_tmp_pubdb_dps_v AS 

/*
 * Enthält die ID aller DSV, Facadelayer, Layergroups, welche sich aus mindestens
 * einer pub-db Tabelle zusammensetzen.
 */
WITH 

tableview AS (
  SELECT 
    v.id AS tv_id
  FROM
    simi.simidata_table_view v
  JOIN
    simi.simidata_postgres_table t ON v.postgres_table_id = t.id 
  JOIN 
    simi.simidata_data_theme dt ON t.data_theme_id = dt.id
  JOIN
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id
  WHERE 
    db.db_name = 'DB Pub'
),

facadelayer AS (
  SELECT 
    p.facade_layer_id AS fl_id
  FROM
    simi.simiproduct_properties_in_facade p
  JOIN
    tableview v ON p.data_set_view_id = v.tv_id
  GROUP BY
    facade_layer_id
),

singleactor AS (
  SELECT tv_id AS sa_id FROM tableview
  UNION ALL
  SELECT fl_id AS sa_id FROM facadelayer
),

productlist AS (
  SELECT 
    p.product_list_id AS pl_id
  FROM
    simi.simiproduct_properties_in_list p
  JOIN
    singleactor s ON p.single_actor_id = s.sa_id
  GROUP BY
    p.product_list_id 
)

SELECT pl_id AS dp_id FROM productlist
UNION ALL 
SELECT sa_id AS dp_id FROM singleactor
;