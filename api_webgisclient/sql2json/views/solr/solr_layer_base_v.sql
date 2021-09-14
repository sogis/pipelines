
--DROP VIEW IF EXISTS simi.solr_layer_base_v;

--CREATE VIEW simi.solr_layer_base_v AS
 

WITH

bglayer_overrides AS ( -- Uebersteuerung der Eigenschaften der Background-Layer
    SELECT 
      * 
    FROM (
      VALUES 
        ('ch.so.agi.hintergrundkarte_farbig', 'background'), 
        ('ch.so.agi.hintergrundkarte_sw', 'background'), 
        ('ch.so.agi.hintergrundkarte_ortho', 'background')
    ) 
    AS t (bg_ident, bg_facet)
),

dp_base AS ( -- Umfasst alle für solr notwendigen Informationen eines DataProducts
  SELECT 
    identifier,    
    COALESCE(title, identifier) as title,
    CASE dp.dtype
      WHEN 'simiData_TableView' THEN 'datasetview'
      WHEN 'simiProduct_FacadeLayer' THEN 'facadelayer'
      WHEN 'simiProduct_LayerGroup' THEN 'layergroup'
      WHEN 'simiData_RasterView' THEN 'datasetview'
      ELSE 'ERR:UnknownType'
    END AS dp_typ,    
    COALESCE(bg.bg_facet, 'foreground') AS facet,
    (description IS NOT NULL) AS dprod_has_info, -- Metainformationen vorhanden?
    description,
    keywords,
    synonyms,
    split_part(identifier, '.', 3) AS amt_ident,
    dp.id AS dp_id,
    dp.pub_scope_id 
  FROM 
    simi.simiproduct_data_product dp 
  LEFT JOIN
    simi.simiproduct_map m ON dp.id = m.id
  LEFT JOIN 
    bglayer_overrides bg ON dp.identifier = bg.bg_ident
  WHERE
    m.id IS NULL -- EXCLUDE maps
),

dp_published AS ( -- Alle Dataproducts, welche für sich stehend (Eigene Zeile) im solr INDEX vorkommen
  SELECT 
    dp.*
  FROM 
    dp_base dp
  JOIN  
    simi.simiproduct_data_product_pub_scope ps on dp.pub_scope_id = ps.id 
  WHERE
      pub_to_wgc IS TRUE
    AND 
      pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' --zu löschen
),

prodlist_children AS ( -- Alle Kinder von Produktlisten, welche nicht als zu löschen markiert sind
  SELECT 
    pil.product_list_id AS pl_id,
    sort,
    jsonb_build_object(
      'subclass', dp_typ,
      'ident', identifier,
      'display', title,
      'dset_info', dprod_has_info      
    ) AS json_obj,
    title,
    synonyms,
    keywords,
    description
  FROM
    simi.simiproduct_properties_in_list pil
  JOIN
    dp_base dp ON pil.single_actor_id = dp.dp_id
  WHERE 
    dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- Zu löschende entfernen
),

prodlist_children_agg_ AS (
  SELECT
    jsonb_agg(json_obj ORDER BY sort) AS json_arr,
    string_agg(title, ', ') AS titles_c,
    string_agg(synonyms, ', ') AS synonyms_c,
    string_agg(keywords, ', ') AS keywords_c,
    string_agg(description, ', ') AS description_c,  
    pl_id
  FROM
    prodlist_children
  GROUP BY 
    pl_id
),

prodlist_children_bgkorr AS (
  SELECT 
    c.*
  FROM
    prodlist_children_agg_ c
  JOIN
    simi.simi.simiproduct_data_product dp ON c.pl_id = dp.id
  LEFT JOIN
    bglayer_overrides bg ON dp.identifier = bg.bg_ident
  WHERE 
    bg.bg_ident IS NULL -- Kinder der Hintergrundkarten ausschliessen, da facadelayer
),

amt_lookup AS (
  SELECT 
    * 
  FROM (
    VALUES 
      ('agi', 'Amt für Geoinformation'), 
      ('ada', 'Amt für Denkmalschutz und Archäologie'), 
      ('avt', 'Amt für Verkehr und Tiefbau'), 
      ('arp', 'Amt für Raumplanung'),
      ('awjf', 'Amt für Wald, Jagd und Fischerei'),
      ('alw', 'Amt für Landwirtschaft')
  ) 
  AS t (amt_ident, amt_name)
),

solr_record AS (
  SELECT 
    json_build_array(dp_typ, identifier::TEXT)::text AS id,
    title AS display,
    json_arr::text AS dset_children,
    dprod_has_info AS dset_info,
    concat_ws(', ', title, synonyms) AS search_1_stem,
    concat_ws(', ', title, synonyms, description, amt_name, keywords, titles_c, synonyms_c) AS search_2_stem,
    concat_ws(', ', title, synonyms, description, amt_name, keywords, titles_c, synonyms_c, keywords_c, description_c) AS search_3_stem,
    CASE
      WHEN identifier IN ('ch.so.agi.hintergrundkarte_sw','ch.so.agi.hintergrundkarte_farbig','ch.so.agi.hintergrundkarte_ortho') THEN 'background'
      ELSE 'foreground'
    END AS facet
  FROM 
    dp_published dp
  LEFT JOIN
    prodlist_children_bgkorr c ON dp.dp_id = c.pl_id
  LEFT JOIN
    amt_lookup a ON dp.amt_ident = a.amt_ident
)

SELECT 
  * 
FROM
  solr_record 
;
/*
GRANT ALL ON TABLE simi.solr_layer_base_v TO admin
;
GRANT SELECT ON TABLE simi.solr_layer_base_v TO simi_write, sogis_service
;*/