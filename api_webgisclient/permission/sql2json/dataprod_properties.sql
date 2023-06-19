WITH

tab_layer AS ( 
	SELECT 
		jsonb_build_object('name', derived_identifier , 'attributes', COALESCE(attr_names_json,'["band 1"]')) AS js
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

SELECT js FROM tab_layer
UNION ALL
SELECT js FROM facade_layer
UNION ALL
SELECT js FROM layergroup
;
