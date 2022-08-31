CREATE VIEW simi.solr_layer_base_v AS

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
    derived_identifier AS identifier,    
    COALESCE(title, derived_identifier) as title,
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
    dp.id AS dp_id,
    dp.pub_scope_id 
  FROM 
    simi.simiproduct_data_product dp 
  LEFT JOIN
    simi.simiproduct_map m ON dp.id = m.id
  LEFT JOIN 
    bglayer_overrides bg ON dp.derived_identifier = bg.bg_ident
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
    simi.simiproduct_data_product dp ON c.pl_id = dp.id
  LEFT JOIN
    bglayer_overrides bg ON dp.derived_identifier  = bg.bg_ident
  WHERE 
    bg.bg_ident IS NULL -- Kinder der Hintergrundkarten ausschliessen, da facadelayer
),

-- Organisations-Einheit ***************************************

amt_amt AS (
  SELECT 
    o.id AS org_id,
    o."name" AS amt_name,
    a.abbreviation AS amt_kurz
  FROM
    simi.simitheme_org_unit o
  JOIN
    simi.simitheme_agency a ON o.id = a.id 
),

sub_amt AS (
  SELECT 
    o.id AS org_id,
    amt_name,
    amt_kurz
  FROM 
    simi.simitheme_org_unit o
  JOIN
    simi.simitheme_sub_org s ON o.id = s.id 
  JOIN 
    amt_amt a ON s.agency_id = a.org_id
),

org_amt AS (
  SELECT org_id, amt_name, amt_kurz FROM amt_amt
  UNION ALL 
  SELECT org_id, amt_name, amt_kurz FROM sub_amt
),

dp_amt AS (
  SELECT 
    amt_name, 
    amt_kurz,
    dp.id AS dp_id
  FROM
    org_amt a
  JOIN
    simi.simitheme_theme t ON a.org_id = t.data_owner_id 
  JOIN
    simi.simitheme_theme_publication tp ON t.id = tp.theme_id 
  JOIN 
    simi.simiproduct_data_product dp ON tp.id = dp.theme_publication_id 
),

solr_record AS (
  SELECT 
    json_build_array(dp_typ, identifier::TEXT)::text AS id,
    title AS display,
    json_arr::text AS dset_children,
    dprod_has_info AS dset_info,
    concat_ws(', ', title, synonyms) AS search_1_stem,
    concat_ws(', ', title, synonyms, description, amt_kurz, amt_name, keywords, titles_c, synonyms_c) AS search_2_stem,
    concat_ws(', ', title, synonyms, description, amt_kurz, amt_name, keywords, titles_c, synonyms_c, keywords_c, description_c) AS search_3_stem,
    CASE
      WHEN identifier IN ('ch.so.agi.hintergrundkarte_sw','ch.so.agi.hintergrundkarte_farbig','ch.so.agi.hintergrundkarte_ortho') THEN 'background'
      ELSE 'foreground'
    END AS facet
  FROM 
    dp_published dp
  LEFT JOIN
    prodlist_children_bgkorr c ON dp.dp_id = c.pl_id
  JOIN
    dp_amt a ON dp.dp_id = a.dp_id
)

SELECT 
  * 
FROM
  solr_record 
;