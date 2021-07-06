WITH

dsv_attributes AS (
  SELECT
    jsonb_agg(tf.name) AS attr,
    vf.table_view_id 
  FROM
    simi.simidata_view_field vf
  JOIN
    simi.simidata_table_field tf ON vf.table_field_id = tf.id 
  GROUP BY 
    vf.table_view_id
)

SELECT 
  jsonb_build_object(
    'name', identifier,
    'attributes', attr
  ) AS obj
FROM
  simi.simidata_data_set_view dsv
JOIN
  simi.simiproduct_data_product dp ON dsv.id = dp.id
JOIN
  dsv_attributes a ON dsv.id = a.table_view_id
WHERE
  dsv.raw_download IS TRUE
and identifier like 'test.%'
