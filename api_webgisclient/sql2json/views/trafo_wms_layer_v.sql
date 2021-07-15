DROP VIEW IF EXISTS simi.trafo_wms_layer_v;

CREATE VIEW simi.trafo_wms_layer_v AS

/*
 * Gibt für den WMS die Dataproducts (DP) mit ihren jeweiligen Detailinformationen aus.
 * 
 * Mittels Flag "print_or_ext" wird unterschieden, ob das DP nur im "Print-WMS" erscheint. 
 */
WITH

productlist_children AS ( -- Alle publizierten Kinder einer Productlist, sortiert nach pil.sort
  SELECT  
    pil.product_list_id, 
    jsonb_agg(identifier ORDER BY pil.sort) AS ident_json
  FROM 
    simi.simiproduct_properties_in_list pil 
  JOIN 
    simi.trafo_wms_published_dp_v dp ON pil.single_actor_id = dp.dp_id
  GROUP BY 
    product_list_id  
),

productlist AS ( -- Alle publizierten Productlists, mit ihren publizierten Kindern. (Background-)Map.print_or_ext = TRUE, Layergroup.print_or_ext = FALSE 
  SELECT 
    identifier,
    print_or_ext, 
    jsonb_build_object(
      'name', identifier,
      'type', 'productset',
      'title', title_ident,
      'sublayers', ident_json
    ) AS layer_json
  FROM 
    simi.trafo_wms_published_dp_v dp
  JOIN
    productlist_children sa ON dp.dp_id = sa.product_list_id
  LEFT JOIN 
    simi.simiproduct_map m ON dp.dp_id = m.id
),

facadelayer_children AS ( -- Alle direkt oder indirekt publizierten Kinder eines Facadelayer, sortiert nach pif.sort
  SELECT  
    pif.facade_layer_id,
    jsonb_agg(identifier ORDER BY pif.sort) AS ident_json
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN 
    simi.trafo_wms_published_dp_v dp ON pif.data_set_view_id = dp.dp_id
  GROUP BY 
    facade_layer_id  
),

facadelayer AS (
  SELECT 
    identifier,
    print_or_ext,
    jsonb_build_object(
      'name', identifier,
      'type', 'productset',
      'title', title_ident,
      'sublayers', ident_json
    ) AS layer_json
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN 
    simi.trafo_wms_published_dp_v dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children dsv ON dp.dp_id = dsv.facade_layer_id
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
    identifier,
    FALSE AS print_or_ext,
    jsonb_strip_nulls(jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'vector',
      'title', title_ident,
      'postgis_datasource', tbl_json,
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'qml_assets', COALESCE(assetfiles_json, jsonb_build_array()), --$td COALESCE entfernen
      'attributes', attr_name_alias_js      
    )) AS layer_json
  FROM
    simi.trafo_wms_tableview_v tv
  JOIN
    simi.simidata_data_set_view dsv ON tv.tv_id = dsv.id
  JOIN 
    simi.trafo_wms_geotable_v tbl ON tv.postgres_table_id = tbl.table_id 
  LEFT JOIN 
    dsv_qml_assetfiles files ON tv.tv_id = files.dsv_id
),

raster_layer AS (
  SELECT 
    identifier,
    print_or_ext,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'raster',
      'title', title_ident,
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'raster_datasource', jsonb_build_object('datasource', rds."path", 'srid', 2056) 
    ) AS layer_json
  FROM
    simi.trafo_wms_published_dp_v dp
  JOIN 
    simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
  JOIN 
    simi.simidata_raster_view rv ON dsv.id = rv.id
  JOIN 
    simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id   
),

ext_wms_layerbase AS (
  SELECT  
    identifier,
    title_ident,  
    jsonb_build_object(
      'wms_url', url,
      'layers', el.identifier_list,
      'format', 'image/jpeg',
      'srid', 2056,
      'styles', '',
      'featureCount', 300
    ) AS wms_datasource_json
  FROM
    simi.trafo_wms_published_dp_v dp
  JOIN 
    simi.simiproduct_external_map_layers el ON dp.dp_id = el.id
  JOIN
    simi.simiproduct_external_map_service es ON el.service_id = es.id
  WHERE 
    service_type = 'WMS'
),

ext_wms AS (
  SELECT 
    identifier,
    TRUE AS print_or_ext,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'wms',
      'title', title_ident,
      'wms_datasource', wms_datasource_json
    ) AS layer_json
  FROM
    ext_wms_layerbase
),

ext_wmts_layerbase AS (
  SELECT  
    identifier,
    title_ident,   
    jsonb_build_object(
      'wmts_capabilities_url', url,
      'layer', el.identifier_list,
      'style', el.identifier_list,
      'format', 'image/jpeg',
      'tile_matrix_set', '2056_27',
      'srid', 2056
    ) AS wmts_datasource_json
  FROM
    simi.trafo_wms_published_dp_v dp
  JOIN 
    simi.simiproduct_external_map_layers el ON dp.dp_id = el.id
  JOIN
    simi.simiproduct_external_map_service es ON el.service_id = es.id
  WHERE 
    service_type = 'WMTS'
),

ext_wmts AS (
  SELECT 
    identifier,
    TRUE AS print_or_ext,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'wmts',
      'title', title_ident,
      'wmts_datasource', wmts_datasource_json
    ) AS layer_json
  FROM
    ext_wmts_layerbase
),

layer_union AS (
  SELECT identifier, print_or_ext, layer_json FROM productlist
  UNION ALL 
  SELECT identifier, print_or_ext, layer_json FROM facadelayer
  UNION ALL 
  SELECT identifier, print_or_ext, layer_json FROM vector_layer
  UNION ALL 
  SELECT identifier, print_or_ext, layer_json FROM raster_layer
  UNION ALL 
  SELECT identifier, print_or_ext, layer_json FROM ext_wms
  UNION ALL 
  SELECT identifier, print_or_ext, layer_json FROM ext_wmts
)

SELECT 
  identifier,
  print_or_ext, 
  layer_json 
FROM
  layer_union
;

