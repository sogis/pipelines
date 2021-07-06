DROP VIEW IF EXISTS simi.trafo_wms_dp_pubstate_v;

CREATE VIEW simi.trafo_wms_dp_pubstate_v AS

/*
 * Leitet aufgrund des Pub-Scope (simiproduct_data_product_pub_scope) und der 
 * Beziehungen der Datenprodukte zu Facadelayern und Produktlisten ab, welche
 * Datenprodukte im WMS publiziert sind.
 * 
 * published: Kommen auf irgendeiner Hierarchiestufe des WMS vor.
 * root_published: Erscheinen auf der Root-Ebene des WMS.
 */
WITH 

dp_published AS ( -- Alle Dataproducts, welche nicht zum löschen markiert sind
  SELECT 
    identifier,
    COALESCE(title, identifier) as title,
    ps.display_text AS state_text,
    pub_to_wms,
    dp.id AS dp_id
  FROM 
    simi.simiproduct_data_product dp 
  JOIN  
    simi.simiproduct_data_product_pub_scope ps on dp.pub_scope_id = ps.id 
  WHERE
      ps.id != '55bdf0dd-d997-c537-f95b-7e641dc515df' --zu löschen
/*    AND 
      identifier LIKE 'test.%'*/
),

wms_published_map AS ( -- Background-Map-Kinder sind Teil des WMS, unabhängig vom pub_to_wms flag
  SELECT
    dp.*
  FROM 
    simi.simiproduct_map bm
  JOIN
    dp_published dp ON bm.id = dp.dp_id
  WHERE 
    bm.background IS true
),

wms_published_lg AS ( -- Layergruppen-Kinder sind Teil des WMS
  SELECT
    dp.*
  FROM 
    simi.simiproduct_layer_group lg
  JOIN
    dp_published dp ON lg.id = dp.dp_id
  WHERE
    pub_to_wms IS TRUE 
),

publ_pl AS ( -- WMS-publizierte Produktlisten
  SELECT dp_id AS pl_id, identifier, title FROM wms_published_map
  UNION ALL 
  SELECT dp_id AS pl_id, identifier, title FROM wms_published_lg
),

publ_pl_children AS ( -- Kind-IDs von publizierten Produklisten
  SELECT
    pil.single_actor_id AS sa_id,
    count(pil.id) AS pl_count
  FROM
    simi.simiproduct_properties_in_list pil
  JOIN
    publ_pl pl ON pil.product_list_id = pl.pl_id 
  GROUP BY
    pil.single_actor_id
),

sa_wms_state_part AS ( -- Publish-State von SingleActors in sich selbst und bezüglich Productlists. Beziehung DSV -> FL ist nicht berücksichtigt 
  SELECT
    identifier,
    pub_to_wms AS root_published,
    COALESCE(pl_count, 0) AS pl_count,
    title,
    dp.dp_id AS sa_id
  FROM
    simi.simiproduct_single_actor sa
  JOIN
    dp_published dp ON sa.id = dp.dp_id
  LEFT JOIN
    publ_pl_children plc ON sa.id = plc.sa_id
),

publ_fl_children AS ( -- DSV von direkt oder indirekt publizierten Facadelayern
  SELECT
    pif.data_set_view_id AS dsv_id,
    count(pif.id) AS fl_count
  FROM
    simi.simiproduct_properties_in_facade pif
  JOIN
    sa_wms_state_part fl ON pif.facade_layer_id = fl.sa_id
  WHERE
      fl.root_published IS TRUE
    OR
      fl.pl_count > 0
  GROUP BY
    pif.data_set_view_id
),

sa_wms_state AS ( -- Gibt aus, ob ein SingleActor für WMS publiziert ist
  SELECT
    sa.identifier,
    ((COALESCE(fl_count, 0) + pl_count) > 0) OR root_published AS published,
    root_published,  
    sa.title,
    sa_id AS dp_id
  FROM 
    sa_wms_state_part sa
  LEFT JOIN
    publ_fl_children flc ON sa.sa_id = flc.dsv_id
),

pl_wms_state AS (
  SELECT
    identifier,
    TRUE AS published,
    TRUE AS root_published,
    title,
    pl_id AS dp_id
  FROM
    publ_pl    
),

union_all AS (
  SELECT identifier, published, root_published, title, dp_id FROM pl_wms_state
  UNION ALL
  SELECT identifier, published, root_published, title, dp_id FROM sa_wms_state
)


SELECT 
  u.*   
FROM
  union_all u
;


/* Debug ...
SELECT 
  published, 
  root_published,
  dp.*
FROM
  union_all u
JOIN
  dp_published dp ON u.dp_id = dp.dp_id
ORDER BY
  identifier
;
*/