SELECT 
  jsonb_build_object(
    'name', derived_identifier,
    'attributes', attr_names_json
  ) AS obj
FROM
  simi.simidata_table_view tv
JOIN 
  simi.simidata_data_set_view dsv ON tv.id = dsv.id
JOIN
  simi.simiproduct_data_product dp ON tv.id = dp.id
JOIN
  simi.trafo_wms_geotable_v t ON tv.id = t.tv_id 
JOIN
  simi.trafo_tableview_attr_with_geo_v a ON dsv.id = a.tv_id
WHERE
  dsv.service_download IS TRUE

