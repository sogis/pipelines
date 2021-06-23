DROP VIEW IF EXISTS simi.trafo_wms_layer_v;

CREATE VIEW simi.trafo_wms_layer_v AS 


/*
 * Gibt für den WMS die Dataproducts (DP) mit ihren jeweiligen Detailinformationen aus.
 * 
 * Mittels Flag "print_only" wird unterschieden, ob das DP nur im Print-WMS erscheint. 
 */
WITH

productlist_children AS ( -- Alle publizierten Kinder einer Productlist, sortiert nach pil.sort
  SELECT  
    pil.product_list_id, 
    jsonb_agg(identifier ORDER BY pil.sort) AS ident_json
  FROM 
    simi.simiproduct_properties_in_list pil 
  JOIN 
    simi.trafo_wms_dp_pubstate_v dp ON pil.single_actor_id = dp.dp_id
  WHERE 
    dp.published IS TRUE 
  GROUP BY 
    product_list_id  
),

productlist AS ( -- Alle publizierten Productlists, mit ihren publizierten Kindern. (Background-)Map.print_only = TRUE, Layergroup.print_only = FALSE 
  SELECT 
    (m.id IS NOT NULL) AS print_only, 
    jsonb_build_object(
      'name', identifier,
      'type', 'productset',
      'title', title,
      'sublayers', ident_json
    ) AS layer_json
  FROM 
    simi.trafo_wms_dp_pubstate_v dp
  JOIN
    productlist_children sa ON dp.dp_id = sa.product_list_id
  LEFT JOIN 
    simi.simiproduct_map m ON dp.dp_id = m.id
  WHERE
    published IS TRUE 
),

facadelayer_children AS ( -- Alle direkt oder indirekt publizierten Kinder eines Facadelayer, sortiert nach pif.sort
  SELECT  
    pif.facade_layer_id,
    jsonb_agg(identifier ORDER BY pif.sort) AS ident_json
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN 
    simi.trafo_wms_dp_pubstate_v dp ON pif.data_set_view_id = dp.dp_id
  WHERE 
    dp.published IS TRUE 
  GROUP BY 
    facade_layer_id  
),

facadelayer AS (
  SELECT 
    FALSE AS print_only,
    jsonb_build_object(
      'name', identifier,
      'type', 'productset',
      'title', title,
      'sublayers', ident_json
    ) AS layer_json
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN 
    simi.trafo_wms_dp_pubstate_v dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children dsv ON dp.dp_id = dsv.facade_layer_id
  WHERE 
    dp.published IS TRUE 
),

/*
dsv_qml_assets AS (
  SELECT 
    dataset_set_view_id AS dsv_id,
    filename,
    encode(file_content, 'base64') AS data_base64
  FROM
    simi.simidata_styleasset     
  WHERE 
    is_for_server IS TRUE  
),
*/ 
dsv_qml_assetfile AS (  
  SELECT 
    'af15e983-4752-4111-adf0-69fc8f68b4b5'::uuid AS dsv_id,
    row_to_json(row('fuu/bar.svg','base64-dummy')) AS file_json
  FROM
    generate_series(1, 2) --$td REPLACE WITH REAL assets 
),

dsv_qml_assetfiles AS (
  SELECT 
    dsv_id,
    jsonb_agg(file_json) AS assetfiles_json
  FROM 
    dsv_qml_assetfile
  GROUP BY 
    dsv_id
),

vector_layer AS (
  SELECT 
    FALSE AS print_only,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'vector',
      'title', title,
      'postgis_datasource', tbl_json,
      --'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'qml_base64', encode(convert_to('DUMMY', 'UTF8'), 'base64'),
      'qml_assets', COALESCE(assetfiles_json, jsonb_build_array()), --$td COALESCE entfernen
      'attributes', attr_json      
    ) AS layer_json
  FROM
    simi.trafo_wms_dp_pubstate_v dp
  JOIN 
    simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
  JOIN 
    simi.simidata_table_view tv ON dsv.id = tv.id
  JOIN 
    simi.trafo_wms_tableview_attribute_v tv_attr ON tv.id = tv_attr.table_view_id --$td ATTRIBUTEin trafo_wms_tableview_attribute_v sortieren
  JOIN 
    simi.trafo_wms_pg_table_v tbl ON tv.postgres_table_id = tbl.table_id 
  LEFT JOIN 
    dsv_qml_assetfiles files ON dsv.id = files.dsv_id
  WHERE 
      tbl.has_geometry IS TRUE
    AND 
      dp.published IS TRUE 
),

raster_layer AS (
  SELECT 
    FALSE AS print_only,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'raster',
      'title', title,
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'raster_datasource', jsonb_build_object('datasource', rds."path", 'srid', 2056) 
    ) AS layer_json
  FROM
    simi.trafo_wms_dp_pubstate_v dp
  JOIN 
    simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
  JOIN 
    simi.simidata_raster_view rv ON dsv.id = rv.id
  JOIN 
    simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id   
  WHERE
    dp.published IS TRUE 
),

ext_wms_layerbase AS (
  SELECT  
    identifier,
    title,  
    jsonb_build_object(
      'wms_url', url,
      'layers', dp.identifier,
      'format', 'image/jpeg',
      'srid', 2056
    ) AS wms_datasource_json
  FROM
    simi.trafo_wms_dp_pubstate_v dp
  CROSS JOIN 
    simi.simiproduct_external_map_service es
  WHERE 
      service_type = 'WMS'
    AND 
      dp.published IS TRUE 
    AND 
      identifier = 'ch.so.agi.gemeindegrenzen' --$td remove this CONDITION AND REPLACE CROSS JOIN WITH INNER JOIN 
),

ext_wms AS (
  SELECT 
    TRUE AS print_only,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'wms',
      'title', title,
      'wms_datasource', wms_datasource_json
    ) AS layer_json
  FROM
    ext_wms_layerbase
),

ext_wmts_layerbase AS (
  SELECT  
    identifier,
    title,   
    jsonb_build_object(
      'wmts_capabilities_url', url,
      'layer', identifier,
      'style', identifier,
      'format', 'image/jpeg',
      'tile_matrix_set', '2056_27',
      'srid', 2056
    ) AS wmts_datasource_json
  FROM
    simi.trafo_wms_dp_pubstate_v dp
  CROSS JOIN 
    simi.simiproduct_external_map_service es
  WHERE 
      dp.published IS TRUE 
    AND 
      service_type = 'WMTS'
    AND 
      identifier = 'ch.so.agi.gemeindegrenzen' --$td remove this CONDITION AND REPLACE CROSS JOIN WITH INNER JOIN 
),

ext_wmts AS (
  SELECT 
    TRUE AS print_only,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'wmts',
      'title', title,
      'wmts_datasource', wmts_datasource_json
    ) AS layer_json
  FROM
    ext_wmts_layerbase
),

layer_union AS (
  SELECT print_only, layer_json FROM productlist
  UNION ALL 
  SELECT print_only, layer_json FROM facadelayer
  UNION ALL 
  SELECT print_only, layer_json FROM vector_layer
  UNION ALL 
  SELECT print_only, layer_json FROM raster_layer
  UNION ALL 
  SELECT print_only, layer_json FROM ext_wms
  UNION ALL 
  SELECT print_only, layer_json FROM ext_wmts
)

SELECT 
  print_only, 
  layer_json 
FROM
  layer_union
;