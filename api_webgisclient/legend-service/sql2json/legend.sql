WITH

sa_base AS ( -- Basis-CTE für Datasetview und Facadelayer
  SELECT 
    identifier,
    CASE
      WHEN fl.id IS NOT NULL THEN TRUE 
      ELSE FALSE 
    END AS is_facade,
    encode(sa.custom_legend, 'base64') AS legend_base64,
    root_published,
    sa.id AS sa_id
  FROM
    simi.simiproduct_single_actor sa
  JOIN
    simi.trafo_published_dp_v dp ON sa.id = dp.dp_id
  LEFT JOIN 
    simi.simiproduct_facade_layer fl ON sa.id = fl.id
),

dsv AS (
  SELECT
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', identifier,
        'type', 'layer',
        'legend_image_base64', legend_base64
      )
    ) AS dp_json,
    root_published,
    sa_id AS dp_id
  FROM
    sa_base
  WHERE
    is_facade IS FALSE 
),

facade_children AS (
  SELECT 
    jsonb_agg(dp_json ORDER BY sort) AS facade_children_arr,
    pif.facade_layer_id AS fl_id
  FROM
    simi.simiproduct_properties_in_facade pif
  JOIN
    dsv ON pif.data_set_view_id = dsv.dp_id
  GROUP BY 
    pif.facade_layer_id 
),

facade AS (
  SELECT
    jsonb_strip_nulls(
      jsonb_build_object(
        'name', identifier,
        'type', 'layergroup',
        'hide_sublayers', TRUE,
        'layers', facade_children_arr,
        'legend_image_base64', legend_base64
      )
    ) AS dp_json,
    root_published,
    sa_id AS dp_id
  FROM
    sa_base sa
  JOIN
    facade_children fc ON sa.sa_id = fc.fl_id
  WHERE
    is_facade IS TRUE  
),

singleactor AS (
  SELECT dp_json, root_published, dp_id FROM dsv
  UNION ALL
  SELECT dp_json, root_published, dp_id FROM facade
),

prodlist_children AS (
  SELECT 
    jsonb_agg(dp_json ORDER BY sort) AS prodlist_children_arr,
    pil.product_list_id AS pl_id
  FROM
    simi.simiproduct_properties_in_list pil
  JOIN
    singleactor sa ON pil.single_actor_id = sa.dp_id
  GROUP BY 
    pil.product_list_id  
),

layergroup AS (
  SELECT 
    jsonb_build_object(
      'name', identifier,
      'type', 'layergroup',
      'layers', prodlist_children_arr
    ) AS dp_json,
    root_published,
    dp_id
  FROM
    simi.simi.simiproduct_layer_group lg
  JOIN
    simi.trafo_published_dp_v dp ON lg.id = dp.dp_id
  JOIN
    prodlist_children pc ON lg.id = pc.pl_id
),

dp_union AS (
  SELECT dp_json, root_published FROM layergroup
  UNION ALL 
  SELECT dp_json, root_published FROM facade
  UNION ALL 
  SELECT dp_json, root_published FROM dsv
)

SELECT
  dp_json
FROM 
  dp_union
WHERE 
  root_published IS TRUE 

