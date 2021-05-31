with

layer_groups as (
	select 
		identifier,
		false as print_only
	from 
		simi.simiproduct_layer_group lg 
	join
		simi.simiproduct_data_product dp on lg.id = dp.id 
),

singleactors_in_group as ( 
	select 
		single_actor_id 
	from 
		simi.simiproduct_properties_in_list pil 
	group by
		single_actor_id 
),

root_pub_single_actors as (
	select 
		identifier,
		case 
			when eml.id is null then false
			else true
		end as print_only
	from 
		simi.simiproduct_single_actor sa
	join
		simi.simiproduct_data_product dp on sa.id = dp.id 
	join 
		simi.simiproduct_data_product_pub_scope ps on dp.pub_scope_id = ps.id 
	left join 
		simiproduct_external_map_layers eml on sa.id = eml.id 
	left join 
		singleactors_in_group sig on sa.id = sig.single_actor_id
	where 
			sig.single_actor_id is null -- In einer Gruppe enthaltene Singleactors dürfen nicht "für sich" publiziert sein
		and 
			ps.pub_to_wms is true
),

merged as (
	select identifier, print_only from layer_groups
	union all
	select identifier, print_only from root_pub_single_actors
)

select
	*
from 
	merged
order by
	identifier
;
