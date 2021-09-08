
WITH 

constant_fields AS (
  SELECT
    jsonb_build_array() AS const_synonyms_arr,
    jsonb_build_array() AS const_keywords_arr,
    CAST('[{"organisation":{"id":-99,"name":"dummy contact org"}}]' AS jsonb) AS const_contacts_arr,
    '$$WMS_SERVICE_URL$$' AS const_wms_service_url,
    TRUE AS const_queryable,
    255 AS const_opacity,
    'EPSG:2056' AS const_crs,
    'somap' AS const_root_name
  FROM
    generate_series(1,1)
),

dprod AS (
  SELECT 
    pub.identifier,
    title_ident,
    root_published,
    encode(convert_to(COALESCE(description, 'Keine Beschreibung. Wird nach Schemakorrektur auf NULL gesetzt - bjsvwjek'), 'UTF8'), 'base64') AS desc_b64, --$td: COALESCE entfernen nachdem SCHEMA bug behoben ist https://github.com/simi-so/json2qgs/issues/30
    dp_id
  FROM
    simi.trafo_published_dp_v pub
  JOIN
    simi.simiproduct_data_product dp ON pub.dp_id = dp.id
),

tv_pgtable_props AS ( 
  SELECT 
    tv.id AS tv_id,
    'vector' AS vectype,
    jsonb_build_object(
      'dbconnection', db_service_url,
      'data_set_name', concat_ws('.', schema_name, table_name),
      'primary_key', id_field_name,
      'geometry_field', geo_field_name,
      'geometry_type', geo_type,
      'srid', geo_epsg_code
    ) AS tbl_json
  FROM 
    simi.simidata_table_view tv
  JOIN 
    simi.simidata_postgres_table tbl ON tv.postgres_table_id = tbl.id
  JOIN 
    simi.simidata_data_theme dt ON tbl.data_theme_id = dt.id 
  JOIN 
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL
),

rasterview_ds_props AS (
  SELECT 
    jsonb_build_object(
      'datasource', concat_ws('/', '/geodata/geodata', "path"),
      'srid', 2056
    ) AS raster_ds,
    rv.id AS rv_id
  FROM
    simi.simidata_raster_view rv
  JOIN
    simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id
),

ext_wms_layer_part AS (
  SELECT
    jsonb_build_object(
      'name', concat('wms:', s.url, '#/', l.identifier_list),
      'type', 'wms',
      'url', url,
      'params', jsonb_build_object('LAYERS', l.identifier_list)
    ) AS ext_layer_obj,
    jsonb_build_object(
      'service_url', url,
      'name', l.identifier_list
    ) AS wms_layer_obj,
    jsonb_build_array('text/plain') AS info_formats,
    l.id AS layer_id
  FROM
    simi.simiproduct_external_map_layers l
  JOIN
    simi.simi.simiproduct_external_map_service s ON l.service_id = s.id
),

ext_wms_layer AS (
  SELECT
    dp.identifier,
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', dp.identifier,
        'display', title_ident,
        'description_base64', desc_b64,
        'opacity', round(255 - (transparency::real/100*255)),
        'datatype', 'raster',
        'external_layer', ext_layer_obj,
        'wms_datasource', wms_layer_obj,
        'infoFormats', info_formats,
        'type', 'datasetview',
        'queryable', const_queryable, 
        'synonyms', const_synonyms_arr,
        'keywords', const_keywords_arr,
        'contacts', const_contacts_arr
      )
    ) AS layer_json 
  FROM
    ext_wms_layer_part l
  JOIN
    simi.simiproduct_single_actor sa ON l.layer_id = sa.id
  JOIN
    dprod dp ON l.layer_id = dp.dp_id
  CROSS JOIN
    constant_fields
),

tv_objsearch AS ( -- Solr facet ident von tableviews mit aktivierter Objektsuche (--> falls layer geladen ist)
  SELECT    
    COALESCE(tv.search_facet, dp.identifier) AS solr_facet_ident,
    tv.id AS sa_id
  FROM
    simi.simidata_table_view tv
  JOIN
    simi.simiproduct_data_product dp ON tv.id = dp.id  
  WHERE
    tv.search_type = '2_if_loaded'
),

fl_objsearch AS (
  SELECT
    solr_facet_ident,
    pif.facade_layer_id AS sa_id
  FROM
    simi.simiproduct_properties_in_facade pif
  JOIN
    tv_objsearch tv ON pif.data_set_view_id = tv.sa_id 
),

sa_objsearch AS (
  SELECT
    jsonb_agg(solr_facet_ident) AS solr_facet_ident_arr,
    sa_id
  FROM 
    (
      SELECT solr_facet_ident, sa_id FROM fl_objsearch
      UNION ALL 
      SELECT solr_facet_ident, sa_id FROM tv_objsearch
    ) uni 
  GROUP BY 
    sa_id
),

dsv AS (
  SELECT 
    dp.identifier,
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', dp.identifier,
        'display', title_ident,
        'description_base64', desc_b64,
        'qml_base64', encode(convert_to(COALESCE(style_desktop, style_server), 'UTF8'), 'base64'),
        'opacity', round(255 - (transparency::real/100*255)),
        'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
        'datatype', COALESCE(vectype, 'raster'), -- Falls raster ergibt der LEFT JOIN auf pg_table für vectype null
        'postgis_datasource', tbl_json,
        'raster_datasource', raster_ds,
        'type', 'datasetview',
        'searchterms', solr_facet_ident_arr,
        'queryable', const_queryable, 
        'synonyms', const_synonyms_arr,
        'keywords', const_keywords_arr,
        'contacts', const_contacts_arr
      )
    ) AS layer_json 
  FROM
    simi.simidata_data_set_view dsv
  JOIN
    simi.simiproduct_single_actor sa ON dsv.id = sa.id
  JOIN
    dprod dp ON dsv.id = dp.dp_id
  LEFT JOIN
    tv_pgtable_props t ON dsv.id = t.tv_id
  LEFT JOIN
    rasterview_ds_props r ON dsv.id = r.rv_id
  LEFT JOIN
    sa_objsearch os ON dsv.id = os.sa_id 
  CROSS JOIN
    constant_fields
  WHERE
    t.tv_id IS NOT NULL OR r.rv_id IS NOT NULL  
),

facadelayer_children AS ( -- Alle direkt oder indirekt publizierten Kinder eines Facadelayer, sortiert nach pif.sort
  SELECT  
    pif.facade_layer_id,
    jsonb_agg(
      jsonb_build_object(
        'identifier', identifier,
        'visibility', TRUE 
      ) ORDER BY pif.sort
    ) AS sublayer_json
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN 
    dprod dp ON pif.data_set_view_id = dp.dp_id
  LEFT JOIN
    tv_objsearch s ON dp.dp_id = s.sa_id
  GROUP BY 
    facade_layer_id  
),

facadelayer AS (
  SELECT 
    dp.identifier,
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', dp.identifier,
        'display', title_ident,
        'type', 'facadelayer',
        'synonyms', const_synonyms_arr,
        'keywords', const_keywords_arr,
        'contacts', const_contacts_arr,
        'description_base64', desc_b64,
        'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
        'opacity', round(255 - (transparency::real/100*255)),
        'queryable', const_queryable,
        --'crs', const_crs,
        'sublayers', sublayer_json,
        'searchterms', solr_facet_ident_arr
      )
    ) AS layer_json
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN
    simi.simiproduct_single_actor sa ON fl.id = sa.id 
  JOIN
    dprod dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children dsv ON fl.id = dsv.facade_layer_id
  LEFT JOIN
    simi.simiproduct_properties_in_list pil ON fl.id = pil.single_actor_id --Relation to parent decides 
  LEFT JOIN
    sa_objsearch os ON fl.id = os.sa_id 
  CROSS JOIN
    constant_fields
),

productlist_children AS ( -- Alle publizierten Kinder einer Productlist, sortiert nach pil.sort
  SELECT  
    pil.product_list_id, 
    jsonb_agg(
      jsonb_build_object(
        'identifier', identifier,
        'visibility', pil.visible 
      ) ORDER BY pil.sort
    ) AS sublayer_json
  FROM 
    simi.simiproduct_properties_in_list pil 
  JOIN 
    dprod dp ON pil.single_actor_id = dp.dp_id
  GROUP BY 
    product_list_id  
),

bglayer_overrides AS ( -- Uebersteuerung der Eigenschaften der Background-Layer
    SELECT 
      * 
    FROM (
      VALUES 
        ('ch.so.agi.hintergrundkarte_farbig', 'facadelayer', 'background'), 
        ('ch.so.agi.hintergrundkarte_sw', 'facadelayer', 'background'), 
        ('ch.so.agi.hintergrundkarte_ortho', 'facadelayer', 'background')
    ) 
    AS t (bg_ident, bg_layertype, bg_facet)
),

productlist AS ( -- Alle publizierten Productlists, mit ihren publizierten Kindern. (Background-)Map.print_or_ext = TRUE, Layergroup.print_or_ext = FALSE 
  SELECT 
    identifier, 
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', identifier,
        'type', COALESCE(bg_layertype, 'layergroup'),
        'display', title_ident,
        'synonyms', const_synonyms_arr,
        'keywords', const_keywords_arr,
        'contacts', const_contacts_arr,
        'description_base64', desc_b64,
        'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
        'opacity', const_opacity,
        'queryable', const_queryable,
        ---'crs', const_crs,      
        'sublayers', sublayer_json
      )
    ) AS layer_json
  FROM 
    dprod dp
  JOIN
    productlist_children sa ON dp.dp_id = sa.product_list_id
  LEFT JOIN 
    bglayer_overrides bg ON dp.identifier = bg.bg_ident
  CROSS JOIN
    constant_fields
),

root_layer AS (
  SELECT
    jsonb_agg(  
      jsonb_build_object(
        'identifier', identifier,
        'visibility', TRUE 
      ) 
    ) AS root_layer_json
  FROM
    dprod
  WHERE
    root_published IS TRUE   
),

root AS (
  SELECT 
    const_root_name AS identifier,
    jsonb_build_object(
      'identifier', const_root_name,
      'display', const_root_name,
      'type', 'layergroup',
      'description_base64', encode(convert_to('Auf root nicht zutreffend - bjsvwjek', 'UTF8'), 'base64'),
      'sublayers', root_layer_json,
      'synonyms', const_synonyms_arr,
      'keywords', const_keywords_arr,
      'contacts', const_contacts_arr     
    ) AS layer_json
  FROM
    root_layer
  CROSS JOIN
    constant_fields
),

union_all AS (
  SELECT identifier, layer_json FROM root
  UNION ALL
  SELECT identifier, layer_json FROM dsv
  UNION ALL 
  SELECT identifier, layer_json FROM ext_wms_layer
  UNION ALL 
  SELECT identifier, layer_json FROM facadelayer  
  UNION ALL 
  SELECT identifier, layer_json FROM productlist  
)

SELECT
  layer_json
FROM
  union_all