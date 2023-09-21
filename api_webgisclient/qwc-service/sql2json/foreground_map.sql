/* 
 * Generiert die Kartenobjekte für den Web GIS Client.
 * Neben der Standardkarte ("id": "default") sind auch vom AGI gepflegte Karten enthalten, 
 * die zum Beispiel im Zusammenhang mit externen Fachapplikationen zum Einsatz kommen.
 * 
 * Das Query ist komplex, da aufgrund der Internas von qwc2 sehr viele für alle Karten geltende Konfigurationen 
 * mittels "CROSS JOIN" allen Karten zugewiesen werden müssen.
 * 
 * Im CTE "constant_fields" sind viele der für alle Karten geltenden Eigenschaften definiert. Diese können/müssen 
 * direkt in "constant_fields" für alle Karten angepasst werden.
 * Die immer verfügbaren Suchebenen sind in "const_search_providers" als Konstante definiert.
 * 
 * Mittels "||"-Operator werden die kartenübergreifenden und die kartenspezifischen Eigenschaften in das jeweilige
 * output Json-Objekt vereinigt.
 * */
WITH

constant_fields AS (
  SELECT
    'somap' AS const_wms_name,
    '/ows/somap' AS const_wms_url,
    CAST('{"Title":"Kt. Solothurn","OnlineResource":"https://www.so.ch/verwaltung/bau-und-justizdepartement/amt-fuer-geoinformation/geoportal/"}' AS jsonb) AS const_attribution,
    '' AS const_keywords,
    'EPSG:2056' AS const_map_crs,
    CAST('{"crs":"EPSG:2056","bounds":[2590000,1210000,2650000,1270000]}' AS jsonb) AS const_bbox,
    CAST('{"crs":"EPSG:2056","bounds":[2570000,1208000,2667000,1268000]}' AS jsonb) AS const_bbox_initial, 
    CAST('[{"name":"hintergrundkarte_sw","printLayer":"ch.so.agi.hintergrundkarte_sw","visibility":true},{"name":"hintergrundkarte_farbig","printLayer":"ch.so.agi.hintergrundkarte_farbig"},{"name":"hintergrundkarte_ortho","printLayer":"ch.so.agi.hintergrundkarte_ortho"}]' AS jsonb) AS const_wmts_background,
    CAST('[{"name":"A3 hoch","map":{"name":"map0","width":287,"height":395},"labels":["Titel"],"default":false},{"name":"A3 quer","map":{"name":"map0","width":410,"height":272},"labels":["Titel"],"default":false},{"name":"A4 hoch","map":{"name":"map0","width":200,"height":268},"labels":["Titel"],"default":true},{"name":"A4 quer","map":{"name":"map0","width":287,"height":185},"labels":["Titel"],"default":false}]' AS jsonb) AS const_print_conf,
    CAST('{"Titel":{"rows":1,"maxLength":128}}' AS jsonb) AS const_printlabel_conf,
    CAST('["coordinates",{"provider":"solr","default":["foreground","ch.so.agi.av.bodenbedeckung","ch.so.agi.av.gebaeudeadressen.gebaeudeeingaenge","ch.so.agi.av.grundstuecke.projektierte","ch.so.agi.av.grundstuecke.rechtskraeftig","ch.so.agi.av.nomenklatur.flurnamen","ch.so.agi.av.nomenklatur.gelaendenamen","ch.so.agi.gemeindegrenzen"]}]' AS jsonb) AS const_search_providers,
    'This string is from foreground_map.sql. Abstract should not be necessary as map description is not displayed anywhere. bjsvwjek' AS const_map_desc,
    jsonb_build_array('EPSG:21781', 'EPSG:2056') AS const_mouse_crs,
    jsonb_build_array('image/jpeg','image/png') AS const_avail_formats,
    jsonb_build_array('text/plain','text/html','text/xml','application/vnd.ogc.gml','application/vnd.ogc.gml/3.1.1') AS const_info_formats,
    'img/mapthumbs/default.jpg' AS const_thumbnail,
    jsonb_build_array() AS const_external_layers
  FROM
    pg_catalog.generate_series(1,1)
),

published_dp AS (
  SELECT
    derived_identifier AS identifier,
    COALESCE(dp.title, t.title, dp.derived_identifier) as title,
    d.descr AS description,
    dp.id AS dp_id,
    CASE
      WHEN search_type = '2_if_loaded' THEN json_build_array(COALESCE(search_facet, derived_identifier))::jsonb 
    END AS searchterm
  FROM
    simi.simiproduct_data_product dp
  JOIN 
    simi.trafo_dprod_description_v d ON dp.id = d.dp_id
  LEFT JOIN 
    simi.simidata_table_view tv ON dp.id = tv.id
  LEFT JOIN
    simi.simidata_postgres_table t ON tv.postgres_table_id = t.id
  WHERE
    pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' 
),

published_dp_in_prodlist AS (
  SELECT
    product_list_id AS pl_id,
    visible,
    sort,
    dp.*
  FROM
    published_dp dp
  JOIN
    simi.simiproduct_properties_in_list pil ON dp.dp_id = pil.single_actor_id 
),

prodlist_sa_properties AS (
  SELECT
    pl_id,
    jsonb_agg(
      jsonb_build_object(
        'name', identifier,
        'title', title,
        'abstract', dp.description,
        'visibility', visible,
        'queryable', TRUE,
        'opacity', round(255 - (transparency::real/100*255)),
        'bbox', const_bbox,
		'searchterms', COALESCE(searchterm, '[]'::jsonb)
      ) ORDER BY sort
    ) AS sa_props_json
  FROM
    simi.simiproduct_single_actor sa
  JOIN
    published_dp_in_prodlist dp ON sa.id = dp.dp_id
  CROSS JOIN
    constant_fields
  GROUP BY
    pl_id
),

prodlist_sa_list AS (
  SELECT
    pl_id,
    jsonb_agg(identifier ORDER BY sort) AS sa_ident_json
  FROM
    published_dp_in_prodlist 
  GROUP BY
    pl_id
),

fieldtype_with_special_formtype AS (
  SELECT 
    * 
  FROM (
    VALUES 
      ('date', 'date'), 
      ('bool', 'boolean'), 
      ('int8', 'number'),
      ('int4', 'number'),
      ('int2', 'number')    
  ) 
  AS t (fieldtype, formtype)
),

tv_attribute AS (
  SELECT  
    vf.table_view_id AS tv_id,
    "name" AS attr_name,
    COALESCE(alias, "name") AS attr_alias,
    sort AS attr_sort,
    COALESCE(formtype, 'text') AS type_wgc
    /*,
    CASE 
      WHEN tf.str_length IS NOT NULL AND tf.str_length > 0 THEN jsonb_build_object('maxlength', tf.str_length)
      ELSE NULL
    END AS length_constraint*/
  FROM  
    simi.simidata_view_field vf
  JOIN 
    simi.simidata_table_field tf ON vf.table_field_id = tf.id 
  LEFT JOIN
    fieldtype_with_special_formtype ft ON tf.type_name = ft.fieldtype
  WHERE 
    vf.wgc_exposed IS TRUE 
),

tv_attribute_arr AS (
  SELECT
    tv_id,
    jsonb_agg(
      jsonb_strip_nulls(
        jsonb_build_object(
          'id', attr_name,
          'name', attr_alias,
          'type', type_wgc
          --'constraints', length_constraint
        )
      ) ORDER BY attr_sort
    ) AS attr_arr
  FROM 
    tv_attribute
  GROUP BY
    tv_id
),

write_dsv AS (
  SELECT
    data_set_view_id AS dsv_id
  FROM
    simi.simiiam_permission 
  GROUP BY
    data_set_view_id
  HAVING 
    max(level_) = '2_read_write'
),

edit_layers AS (
  SELECT
    jsonb_object_agg(
      identifier, 
      jsonb_build_object(
        'editDataset', identifier,
        'layerName', dp.title,
        'fields', attr_arr,
        'geomType', initcap(t.geo_type),
        'form', '/forms/autogen/somap_'::character varying || identifier || '.ui'::character varying	
      )
    ) AS edit_keyval
  FROM
    simi.simi.simidata_table_view tv
  JOIN
    published_dp dp ON tv.id = dp.dp_id
  JOIN
    write_dsv w ON dp.dp_id = w.dsv_id
  JOIN
    tv_attribute_arr a ON dp.dp_id = a.tv_id
  JOIN
    simi.simi.simidata_postgres_table t ON tv.postgres_table_id = t.id
),

allmaps_keyvals AS (
  SELECT
    jsonb_build_object(
      'wms_name', const_wms_name,
      'url', const_wms_url,
      'attribution', const_attribution,
      'keywords', const_keywords,
      'abstract', const_map_desc,
      'mapCrs', const_map_crs,
      'bbox', const_bbox,
      'initialBbox', const_bbox_initial,
      'expanded', TRUE,
      'backgroundLayers', const_wmts_background,
      'print', const_print_conf,
      'printLabelConfig', const_printlabel_conf,
      'searchProviders', const_search_providers,
      'editConfig', edit_keyval,
      'additionalMouseCrs', const_mouse_crs,
      'availableFormats', const_avail_formats,
      'tiled', FALSE,
      'skipEmptyFeatureAttributes', TRUE,
      'infoFormats', const_info_formats,
      'thumbnail', const_thumbnail,
      'externalLayers', const_external_layers
    ) AS keyvals
  FROM 
    constant_fields cf   
  CROSS JOIN
    edit_layers  
),

default_map AS (
  SELECT
    keyvals || jsonb_build_object(
      'id', 'default',
      'name', 'default',
      'title', 'Standardkarte',
      'sublayers', jsonb_build_array(),
      'drawingOrder', jsonb_build_array()
    ) AS map_obj
  FROM
    allmaps_keyvals
),

foreground_map AS (
  SELECT
     jsonb_build_object(
      'id', identifier,
      'name', identifier,
      'title', title,
      'sublayers', sa_props_json,
      'drawingOrder', sa_ident_json
    ) || keyvals AS map_obj
  FROM
    simi.simi.simiproduct_map m
  JOIN 
    published_dp dp ON m.id = dp.dp_id
  JOIN
    prodlist_sa_properties sap ON dp.dp_id = sap.pl_id
  JOIN
    prodlist_sa_list sal ON dp.dp_id = sal.pl_id
  CROSS JOIN
    allmaps_keyvals c
  WHERE
    m.background IS FALSE 
)

SELECT map_obj FROM default_map
UNION ALL
SELECT map_obj FROM foreground_map
;
