with

tab_layer_attributes as (	
	select 
		table_view_id as dsv_id,
		jsonb_agg(tf."name") as attr_names
	from 
		simidata_view_field vf 
	inner join
		simidata_table_field tf on vf.table_field_id = tf.id 
	group by 
		table_view_id 
),

tab_layer as ( 
	select 
		jsonb_build_object('name', identifier, 'attributes', attr_names) as js
	from 
		simiproduct_data_product dp
	inner join
		tab_layer_attributes a on dp.id = a.dsv_id
),

facade_sublayers as ( 
	select 
		facade_layer_id,
		jsonb_agg(dsv.identifier) as sublayer_names
	from 
		simiproduct_properties_in_facade pif 
	inner join 
		simiproduct_data_product dsv on pif.data_set_view_id = dsv.id 
	group by 
		facade_layer_id 
),

facade_layer as ( 
	select 
		jsonb_build_object('name', identifier, 'sublayers', sublayer_names) as js
	from 
		simiproduct_data_product dp
	inner join
		facade_sublayers s on dp.id = s.facade_layer_id
),

productlist_sublayers as ( 
	select 
		product_list_id,
		jsonb_agg(sa.identifier) as sublayer_names
	from 
		simiproduct_properties_in_list pil 
	inner join 
		simiproduct_data_product sa on pil.single_actor_id = sa.id 
	group by 
		product_list_id 
),

layergroup as ( 
	select 
		jsonb_build_object('name', identifier, 'sublayers', sublayer_names) as js
	from 
		simiproduct_data_product dp
	inner join
		productlist_sublayers s on dp.id = s.product_list_id
	inner join 
		simiproduct_layer_group l on dp.id = l.id -- only layergroups - no maps
)

select js from tab_layer
union all
select js from facade_layer
union all
select js from layergroup
;