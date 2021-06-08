DROP VIEW IF EXISTS simi.trafo_qgs_layers_v;

CREATE VIEW simi.trafo_qgs_layers_v AS 

WITH

dp_common_props AS (
  SELECT 
    dp.id AS dp_id, 
    identifier,
    COALESCE(title, identifier) as title,
    ps.id AS pub_scope_id,
    pub_to_wms    
  FROM 
    simi.simiproduct_data_product dp 
  INNER JOIN  
    simi.simiproduct_data_product_pub_scope ps on dp.pub_scope_id = ps.id 
),

productlist_children AS ( -- Alle Kinder, ausser die "zu löschenden"
  SELECT  
    pil.product_list_id, 
    jsonb_agg(identifier) AS ident_json
  FROM 
    simi.simiproduct_properties_in_list pil 
  JOIN 
    dp_common_props pdp ON pil.single_actor_id = pdp.dp_id
  WHERE 
    pdp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- = status zu löschen
  GROUP BY 
    product_list_id  
),

productlist AS (
  SELECT 
    dp_id AS pl_id,
    pub_to_wms,
    jsonb_build_object(
      'name', identifier,
      'type', 'productset',
      'title', title,
      'sublayers', ident_json
    ) AS layer_json
  FROM 
    dp_common_props dp
  JOIN
    productlist_children sa ON dp.dp_id = sa.product_list_id
),

layergroup AS (
  SELECT 
    FALSE AS print_only,
    layer_json
  FROM 
    productlist pl
  JOIN 
    simi.simiproduct_layer_group lg ON pl.pl_id = lg.id
  WHERE 
    pub_to_wms IS TRUE 
),

background_map AS (
  SELECT 
    TRUE AS print_only,
    layer_json
  FROM 
    productlist pl
  JOIN 
    simi.simiproduct_map m ON pl.pl_id = m.id
  WHERE 
    background IS TRUE  -- $td prüfen, sobald dataproducts erstellt werden können
),

facadelayer_children AS ( -- Alle Kinder, ausser die "zu löschenden"
  SELECT  
    pif.facade_layer_id,
    jsonb_agg(identifier) AS ident_json
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN 
    dp_common_props pdp ON pif.data_set_view_id = pdp.dp_id
  WHERE 
    pdp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- zu löschen
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
    dp_common_props dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children dsv ON dp.dp_id = dsv.facade_layer_id
  WHERE 
    pub_to_wms IS TRUE 
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
      'qml_base64', encode(convert_to(style_server, 'UTF8'), 'base64'),
      'qml_assets', assetfiles_json,
      'attributes', attr_json      
    ) AS layer_json
  FROM
    dp_common_props dp
  JOIN 
    simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
  JOIN 
    simi.simidata_table_view tv ON dsv.id = tv.id
  JOIN 
    simi.trafo_tableview_attributes_v tv_attr ON tv.id = tv_attr.table_view_id
  JOIN 
    simi.trafo_pg_tables_v tbl ON tv.postgres_table_id = tbl.table_id 
  LEFT JOIN 
    dsv_qml_assetfiles files ON dsv.id = files.dsv_id
  WHERE 
    tbl.has_geometry IS TRUE 
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
    dp_common_props dp
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
    title,    
    jsonb_build_object(
      'wms_url', url,
      'layers', dp.identifier,
      'format', 'image/jpeg',
      'srid', 2056
    ) AS wms_datasource_json
  FROM
    dp_common_props dp
  CROSS JOIN 
    simi.simiproduct_external_map_service es
  WHERE 
    service_type = 'WMS'
      AND identifier = 'ch.so.agi.gemeindegrenzen' --$td remove this CONDITION AND REPLACE CROSS JOIN WITH INNER JOIN 
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
    dp_common_props dp
  CROSS JOIN 
    simi.simiproduct_external_map_service es
  WHERE 
    service_type = 'WMTS'
      AND identifier = 'ch.so.agi.gemeindegrenzen' --$td remove this CONDITION AND REPLACE CROSS JOIN WITH INNER JOIN 
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
)

SELECT print_only, layer_json FROM layergroup
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
UNION ALL 
SELECT print_only, layer_json FROM background_map
;