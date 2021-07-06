
WITH 

tableview AS (
  SELECT 
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'title', title,
      'attributes', attr_name_js,
      'queryable', TRUE 
    ) AS layer_json,
    tv_id, 
    root_published
  FROM 
    simi.trafo_wms_tableview_v
),

rasterview AS (
  SELECT 
    jsonb_build_object(
      'name', identifier,
      'type', 'layer',
      'title', title,
      'queryable', TRUE 
    ) AS layer_json,
    rv.id AS rv_id,
    root_published
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

datasetview AS (
  SELECT rv_id AS dsv_id, root_published, layer_json FROM rasterview
  UNION ALL 
  SELECT tv_id AS dsv_id, root_published, layer_json FROM tableview
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
    jsonb_build_object(
      'name', identifier,
      'title', title,
      'type', 'layergroup',
      'hide_sublayers', TRUE,
      'layers', child_layers
    ) AS layer_json,
    fl.id AS fl_id,
    dp.root_published 
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN 
    simi.trafo_wms_dp_pubstate_v dp ON fl.id = dp.dp_id
  JOIN
    facadelayer_children c ON fl.id = c.fl_id
  WHERE 
    dp.published IS TRUE 
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
    jsonb_build_object(
      'name', identifier,
      'type', 'layergroup',
      'title', title,
      'layers', child_layers
    ) AS layer_json,
    dp.root_published, 
    (m.id IS NOT NULL) AS print_only
  FROM 
    simi.simiproduct_product_list p
  JOIN
    simi.trafo_wms_dp_pubstate_v dp ON p.id = dp.dp_id
  JOIN
    prodlist_children c ON p.id = c.pl_id    
  LEFT JOIN 
    simi.simiproduct_map m ON dp.dp_id = m.id
  WHERE
    published IS TRUE
),

all_layers AS (
  SELECT layer_json FROM datasetview WHERE root_published IS TRUE 
  UNION ALL 
  SELECT layer_json FROM facadelayer WHERE root_published IS TRUE 
  UNION ALL 
  SELECT layer_json FROM prodlist WHERE root_published IS TRUE 
)

SELECT * FROM all_layers


