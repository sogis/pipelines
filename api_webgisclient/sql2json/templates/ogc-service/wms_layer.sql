
WITH 

tableview AS (
  SELECT 
    identifier,
    root_published,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'title', title_ident,
      'attributes', a.attr_names_json, 
      'queryable', TRUE 
    ) AS layer_json,
    dp.dp_id AS tv_id
  FROM 
    simi.trafo_wms_published_dp_v dp
  JOIN
    simi.trafo_tableview_attr_geo_append_v a ON dp.dp_id = a.tv_id
),

rasterview AS (
  SELECT 
    identifier,
    root_published,
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'title', title_ident,
      'queryable', TRUE 
    ) AS layer_json,
    rv.id AS rv_id
  FROM
    simi.trafo_wms_published_dp_v dp
  JOIN 
    simi.simidata_data_set_view dsv ON dp.dp_id = dsv.id
  JOIN 
    simi.simidata_raster_view rv ON dsv.id = rv.id
  JOIN 
    simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id   
), 

datasetview AS (
  SELECT identifier, root_published, layer_json, rv_id AS dsv_id FROM rasterview
  UNION ALL 
  SELECT identifier, root_published, layer_json, tv_id AS dsv_id FROM tableview
),

facadelayer_children AS (
  SELECT
    p.facade_layer_id AS fl_id,
    jsonb_agg(layer_json ORDER BY p.sort) AS child_layers
  FROM
    simi.simiproduct_properties_in_facade p
  JOIN
    datasetview d ON p.data_set_view_id = d.dsv_id
  GROUP BY 
    p.facade_layer_id 
),

facadelayer AS (
  SELECT
    identifier,
    dp.root_published,
    jsonb_build_object(
      'name', identifier,
      'title', title_ident,
      'type', 'layergroup',
      'hide_sublayers', TRUE,
      'layers', child_layers
    ) AS layer_json,
    fl.id AS fl_id
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN 
    simi.trafo_wms_published_dp_v dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children c ON fl.id = c.fl_id
),

single_actor AS (
  SELECT fl_id AS sa_id, root_published, layer_json FROM facadelayer
  UNION ALL
  SELECT dsv_id AS sa_id, root_published, layer_json FROM datasetview
),

prodlist_children AS (
  SELECT
    p.product_list_id AS pl_id,
    jsonb_agg(layer_json ORDER BY p.sort) AS child_layers
  FROM
    simi.simiproduct_properties_in_list p
  JOIN
    single_actor s ON p.single_actor_id = s.sa_id
  GROUP BY 
    p.product_list_id 
),

prodlist AS ( -- Alle publizierten Productlists, mit ihren publizierten Kindern. (Background-)Map.print_only = TRUE, Layergroup.print_only = FALSE 
  SELECT 
    identifier,
    dp.root_published, 
    jsonb_build_object(
      'name', identifier,
      'type', 'layergroup',
      'title', title_ident,
      'layers', child_layers
    ) AS layer_json,
    (m.id IS NOT NULL) AS print_only
  FROM 
    simi.simiproduct_product_list p
  JOIN
    simi.trafo_wms_published_dp_v dp ON p.id = dp.dp_id
  JOIN
    prodlist_children c ON p.id = c.pl_id    
  LEFT JOIN 
    simi.simiproduct_map m ON dp.dp_id = m.id
),

all_layers AS (
  SELECT identifier, root_published, layer_json FROM datasetview
  UNION ALL 
  SELECT identifier, root_published, layer_json FROM facadelayer 
  UNION ALL 
  SELECT identifier, root_published, layer_json FROM prodlist 
)

SELECT
  layer_json
FROM 
  all_layers
WHERE 
  root_published IS TRUE 
and identifier like 'ch.so.agi.av.amtliche_vermessung%'
ORDER BY
  identifier


