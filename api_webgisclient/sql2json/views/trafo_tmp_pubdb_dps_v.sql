
DROP VIEW IF EXISTS simi.trafo_tmp_pubdb_dps_v;

CREATE VIEW simi.trafo_tmp_pubdb_dps_v AS 

/*
 * Enthält die ID aller DSV, Facadelayer, Layergroups, welche sich aus mindestens
 * einer pub-db Tabelle zusammensetzen.
 */

-- facadelayer gebäudeadressen 4834b99e-8a1f-4d4c-8e9e-1c73198d6c40
-- tableview rohrleitungen a4762af9-25c3-44f3-8b1d-4d2a167a8973
-- tableview grundstücke rechtskräftig 1e7c5d4a-e23e-4566-aee2-07154fcf5fc2
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
  JOIN
    simi.simiproduct_properties_in_facade pf ON v.id = pf.data_set_view_id 
  WHERE 
    db.db_name = 'DB Pub'
/*  AND
    pf.facade_layer_id = '4834b99e-8a1f-4d4c-8e9e-1c73198d6c40'*/
),

facadelayer AS (
  SELECT 
    p.facade_layer_id AS fl_id
  FROM
    simi.simiproduct_properties_in_facade p
  JOIN
    tableview v ON p.data_set_view_id = v.tv_id
/*  WHERE 
    facade_layer_id = '4834b99e-8a1f-4d4c-8e9e-1c73198d6c40'*/
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
/*  WHERE 
    p.single_actor_id = '4834b99e-8a1f-4d4c-8e9e-1c73198d6c40'*/
  GROUP BY
    p.product_list_id 
)

SELECT pl_id AS dp_id FROM productlist
UNION ALL 
SELECT sa_id AS dp_id FROM singleactor
;