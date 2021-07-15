
WITH 

constant_fields AS (
  SELECT
    jsonb_build_array() AS const_synonyms_arr,
    jsonb_build_array() AS const_keywords_arr,
    CAST('[{"organisation":{"id":-99,"name":"dummy contact org"}}]' AS jsonb) AS const_contacts_arr,
    '$$WMS_SERVICE_URL$$' AS const_wms_service_url,
    'DUMMY - Wird gesetzt, sobald das dataprod image base64 kann. bjsvwjek' AS const_description,
    TRUE AS const_queryable,
    255 AS const_opacity,
    'Fuu bar bjsvwjek' AS const_crs
  FROM
    generate_series(1,1)
),

tv_pgtable_props AS ( 
  SELECT 
    tv.id AS tv_id,
    'vector' AS vectype,
    jsonb_build_object(
      'dbconnection', db_service_url,
      'data_set_name', concat_ws('.', schema_name, table_name),
      'primary_key', id_field_name,
      'geometry_field', geo_field_name,
      'geometry_type', geo_type,
      'srid', geo_epsg_code
    ) AS tbl_json
  FROM 
    simi.simidata_table_view tv
  JOIN 
    simi.simidata_postgres_table tbl ON tv.postgres_table_id = tbl.id
  JOIN 
    simi.simidata_data_theme dt ON tbl.data_theme_id = dt.id 
  JOIN 
    simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL
),

rasterview_ds_props AS (
  SELECT 
    jsonb_build_object(
      'datasource', "path",
      'srid', 2056
    ) AS raster_ds,
    rv.id AS rv_id
  FROM
    simi.simi.simidata_raster_view rv
  JOIN
    simi.simi.simidata_raster_ds rds ON rv.raster_ds_id = rds.id
),

dsv AS (
  SELECT 
    jsonb_strip_nulls(
      jsonb_build_object(
        'identifier', dp.identifier,
        'display', COALESCE(dp.title, dp.identifier),
        'description', const_description, --COALESCE(description, 'dummy description'),
        'qml', 'dummy',--encode(convert_to(COALESCE(style_desktop, style_server), 'UTF8'), 'base64'),
        'opacity', (255 - transparency),
        'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
        'datatype', COALESCE(vectype, 'raster'), -- Falls raster ergibt der LEFT JOIN auf pg_table für vectype null
        'postgis_datasource', tbl_json,
        'raster_datasource', raster_ds,
        'type', 'datasetview',
        'queryable', const_queryable, 
        'synonyms', const_synonyms_arr,
        'keywords', const_keywords_arr,
        'contacts', const_contacts_arr
      )
    ) AS layer_json,  
    root_published,
    dsv.id AS dsv_id
  FROM
    simi.simi.simidata_data_set_view dsv
  JOIN
    simi.simi.simiproduct_single_actor sa ON dsv.id = sa.id
  JOIN
    simi.simi.simiproduct_data_product dp ON dsv.id = dp.id
  JOIN
    simi.trafo_wms_published_dp_v dps ON dsv.id = dps.dp_id 
  LEFT JOIN
    tv_pgtable_props t ON dsv.id = t.tv_id
  LEFT JOIN
    rasterview_ds_props r ON dsv.id = r.rv_id
  CROSS JOIN
    constant_fields
),

facadelayer_children AS ( -- Alle direkt oder indirekt publizierten Kinder eines Facadelayer, sortiert nach pif.sort
  SELECT  
    pif.facade_layer_id,
    jsonb_agg(
      jsonb_build_object(
        'identifier', identifier,
        'visibility', TRUE 
      ) ORDER BY pif.sort
    ) AS sublayer_json
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN 
    simi.trafo_wms_published_dp_v dp ON pif.data_set_view_id = dp.dp_id
  GROUP BY 
    facade_layer_id  
),

facadelayer AS (
  SELECT 
    dp.identifier,
    root_published,
    jsonb_build_object(
      'identifier', dp.identifier,
      'display', title_ident,
      'type', 'facadelayer',
      'synonyms', const_synonyms_arr,
      'keywords', const_keywords_arr,
      'contacts', const_contacts_arr,
      'description', const_description,
      'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
      'opacity', (255 - transparency),
      'queryable', const_queryable,
      'crs', const_crs,
      'sublayers', sublayer_json
    ) AS layer_json
  FROM 
    simi.simiproduct_facade_layer fl
  JOIN
    simi.simiproduct_single_actor sa ON fl.id = sa.id 
  JOIN 
    simi.trafo_wms_published_dp_v pdp ON fl.id = pdp.dp_id
  JOIN
    simi.simiproduct_data_product dp ON fl.id = dp.id
  JOIN
    facadelayer_children dsv ON fl.id = dsv.facade_layer_id
  LEFT JOIN
    simi.simi.simiproduct_properties_in_list pil ON fl.id = pil.single_actor_id --Relation to parent decides 
  CROSS JOIN
    constant_fields
),

productlist_children AS ( -- Alle publizierten Kinder einer Productlist, sortiert nach pil.sort
  SELECT  
    pil.product_list_id, 
    jsonb_agg(
      jsonb_build_object(
        'identifier', identifier,
        'visibility', pil.visible 
      ) ORDER BY pil.sort
    ) AS sublayer_json
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
    jsonb_build_object(
      'identifier', identifier,
      'type', 'layergroup',
      'display', title_ident,
      'synonyms', const_synonyms_arr,
      'keywords', const_keywords_arr,
      'contacts', const_contacts_arr,
      'description', const_description,
      'wms_datasource', jsonb_build_object('name', dp.identifier, 'service_url', const_wms_service_url),
      'opacity', const_opacity,
      'queryable', const_queryable,
      'crs', const_crs,      
      'sublayers', sublayer_json
    ) AS layer_json
  FROM 
    simi.trafo_wms_published_dp_v dp
  JOIN
    productlist_children sa ON dp.dp_id = sa.product_list_id
  CROSS JOIN
    constant_fields
),

root_layer AS (
  SELECT
    jsonb_agg(identifier) AS root_layer_json
  FROM
    simi.trafo_wms_published_dp_v
  WHERE
    root_published IS TRUE   
),

root AS (
  SELECT 
    jsonb_build_object(
      'identifier', 'ch.so.wms',
      'display', 'ch.so.wms',
      'type', 'layergroup',
      'description', 'Auf root nicht zutreffend - bjsvwjek',
      'layers', root_layer_json,
      'synonyms', const_synonyms_arr,
      'keywords', const_keywords_arr,
      'contacts', const_contacts_arr     
    ) AS layer_json
  FROM
    root_layer
  CROSS JOIN
    constant_fields
),

union_all AS (
  SELECT layer_json FROM root
  UNION ALL 
  SELECT layer_json FROM dsv
  UNION ALL 
  SELECT layer_json FROM facadelayer  
  UNION ALL 
  SELECT layer_json FROM productlist  
)

SELECT
  *
FROM
  union_all
  
  