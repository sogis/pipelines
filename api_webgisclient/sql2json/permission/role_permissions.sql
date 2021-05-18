with

sl_perm as ( -- Permissions of a role on a single layer
	select 
		role_id,
		data_set_view_id as dp_id,
		level_ as perm_level
	from 
		simi.simiiam_permission sp 		
),

fl_perm as ( -- Aggregated permissions for a facadelayer. Derived from the contained singleactor permissions
	select 
		role_id,
		facade_layer_id as dp_id,
		min(level_) as perm_level
	from 
		simi.simiproduct_properties_in_facade pif 
	inner join 
		simi.simiiam_permission sp on pif.data_set_view_id = sp.data_set_view_id
	group by 
		role_id, facade_layer_id 
),

sa_perm as ( -- permissions for single actors
	select role_id, dp_id, perm_level from sl_perm
	union all 
	select role_id, dp_id, perm_level from fl_perm
),

lg_perm as ( -- permissions for layer groups
	select
		role_id,
		lg.id as dp_id,
		min(perm_level) as perm_level
	from 
		simi.simiproduct_properties_in_list pil 
	inner join
		simi.simiproduct_layer_group lg on pil.product_list_id = lg.id -- choose only productlists of type layergroup
	inner join 
		sa_perm sa on pil.single_actor_id = sa.dp_id
	group by 
		role_id, lg.id
),

dp_perm as ( -- permissions for the dataproducts datasetview, facadelayer and layergroup
	select role_id, dp_id, perm_level from sa_perm
	union all 
	select role_id, dp_id, perm_level from lg_perm
),

perm_raw as ( -- lists all permissions for dataproducts in "human readable" form
	select 
		role_id,
		identifier as dp_ident,
		case perm_level
			when '2' -- $td change to 2_read_write
				then true
			else false
		end as writeable
	from 
		dp_perm p
	inner join 
		simi.simiproduct_data_product dp on p.dp_id = dp.id
),

perm_json as (
	select 
		role_id,
		jsonb_agg(
			jsonb_build_object('name', dp_ident, 'writable', writeable)
		) as perm_json
	from 
		perm_raw
	group by
		role_id	
)

select 
	jsonb_set( -- Inner jsonb_set(...) sets the perm_json array. Outer jsonb_set(...) sets the role name
		jsonb_set('{"role": null, "permissions": { "all_services": null }}', '{permissions, all_services}', perm_json),
		'{role}',
		to_jsonb(name))
	as js
from 
	perm_json p
inner join 
	simi.simiiam_role r on p.role_id = r.id 
;
	
