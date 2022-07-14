DROP VIEW IF EXISTS simi.trafo_wms_layer_v CASCADE;

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
    simi.trafo_published_dp_v dp ON pil.single_actor_id = dp.dp_id
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
    simi.trafo_published_dp_v dp
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
    simi.trafo_published_dp_v dp ON pif.data_set_view_id = dp.dp_id
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
    simi.trafo_published_dp_v dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children dsv ON dp.dp_id = dsv.facade_layer_id
),

dsv_qml_assetfile AS (
  SELECT 
    dataset_set_view_id AS dsv_id,
    jsonb_build_object(
      'path', file_name,
      'base64', encode(file_content, 'base64')
    ) AS file_json
  FROM
    simi.simidata_styleasset     
  WHERE 
    is_for_server IS TRUE  
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
    jsonb_strip_nulls(
      jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'vector',
      'title', title_ident,
      'postgis_datasource', tbl_json,
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'qml_assets', COALESCE(assetfiles_json, jsonb_build_array()), --$td COALESCE entfernen
      'attributes', attr_name_js      
      )
    ) AS layer_json
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
    jsonb_strip_nulls(jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'datatype', 'raster',
      'title', title_ident,
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'raster_datasource', jsonb_build_object('datasource', concat_ws('/', '/geodata/geodata', "path"), 'srid', 2056) 
    )) AS layer_json
  FROM
    simi.trafo_published_dp_v dp
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
      'wms_url', concat(url, '/'), -- TRAILING slash für qgis server notwendig
      'layers', el.ext_identifier,
      'format', 'image/png',
      'srid', 2056,
      'styles', '',
      'featureCount', 300
    ) AS wms_datasource_json
  FROM
    simi.trafo_published_dp_v dp
  JOIN 
    simi.simiproduct_external_wms_layers el ON dp.dp_id = el.id
  JOIN
    simi.simiproduct_external_wms_service es ON el.service_id = es.id
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
)

SELECT 
  identifier,
  print_or_ext, 
  layer_json 
FROM
  layer_union
;

GRANT SELECT ON TABLE simi.trafo_wms_layer_v TO simi_write;

