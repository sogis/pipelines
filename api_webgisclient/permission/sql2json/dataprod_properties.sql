WITH

dsv_dependency_unique AS (
	SELECT
	        data_set_view_id,
		d.dtype AS dependency_type,
		display_template,
		(max(dependency_id::varchar))::uuid AS dependency_id
	      FROM
	        simi.simiextended_relation r
	      JOIN
	        simi.simiextended_dependency d ON r.dependency_id = d.id
	      WHERE
	        r.relation_type = '1_display'
	      AND
	        d.dtype = 'simiExtended_FeatureInfo'
	      GROUP BY
	        data_set_view_id,
		d.dtype,
		display_template
),

raster_layer_with_display_template AS (
	SELECT
	      jsonb_build_object('name', derived_identifier, 'attributes', '[]'::JSON) AS js
	FROM
	      simi.simiproduct_data_product dp
	JOIN
	      dsv_dependency_unique dep ON dp.id = data_set_view_id
	WHERE
	      dp.dtype = 'simiData_RasterView'
	AND
	      display_template IS NOT NULL

),

tab_layer AS ( 
	SELECT 
		jsonb_build_object('name', derived_identifier , 'attributes', attr_names_json) AS js
	FROM 
		simi.simiproduct_data_product dp
	inner JOIN
	  simi.trafo_tableview_attr_with_geo_v a ON dp.id = a.tv_id
),

facade_sublayers AS ( 
	SELECT 
		facade_layer_id,
		jsonb_agg(dsv.derived_identifier) AS sublayer_names
	FROM 
		simi.simiproduct_properties_in_facade pif 
	JOIN 
		simi.simiproduct_data_product dsv ON pif.data_set_view_id = dsv.id 
	GROUP BY 
		facade_layer_id 
),

facade_layer AS ( 
	SELECT 
		jsonb_build_object('name', derived_identifier, 'sublayers', sublayer_names) AS js
	FROM 
		simi.simiproduct_data_product dp
	JOIN
		facade_sublayers s ON dp.id = s.facade_layer_id
),

productlist_sublayers AS ( 
	SELECT 
		product_list_id,
		jsonb_agg(sa.derived_identifier) AS sublayer_names
	FROM 
		simi.simiproduct_properties_in_list pil 
	JOIN 
		simi.simiproduct_data_product sa ON pil.single_actor_id = sa.id 
	GROUP BY 
		product_list_id 
),

layergroup AS ( 
	SELECT 
		jsonb_build_object('name', derived_identifier, 'sublayers', sublayer_names) AS js
	FROM 
		simi.simiproduct_data_product dp
	JOIN
		productlist_sublayers s ON dp.id = s.product_list_id
	JOIN 
		simi.simiproduct_layer_group l ON dp.id = l.id -- only layergroups - no maps
)

SELECT js FROM raster_layer_with_display_template
UNION ALL
SELECT js FROM tab_layer
UNION ALL
SELECT js FROM facade_layer
UNION ALL
SELECT js FROM layergroup
;
