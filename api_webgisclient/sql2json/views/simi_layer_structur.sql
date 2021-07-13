--drop view simi.simi_layer_structur;
create view simi.simi_layer_structur
as 
with first_sublevel as (
SELECT 
    product_id, 
    properties_in_list.single_actor_id as group_sublayer_single_actor_id, 
    single_actor_group.transparency as group_sublayer_transparency, 
    properties_in_list.visible as group_sublayer_visible,
    properties_in_list.sort as group_sublyer_sort,
    properties_in_facade.data_set_view_id as facade_dataset_view_id, 
    properties_in_facade.sort as facade_sort, 
    single_actor_facade.transparency as facade_transparency
FROM 
    simi.simi_layer_basic basic
left join simi.simiproduct_properties_in_list properties_in_list on properties_in_list.product_list_id = basic.product_id 
left join simi.simiproduct_properties_in_facade properties_in_facade on properties_in_facade.facade_layer_id = basic.product_id
left join simi.simiproduct_single_actor single_actor_group on single_actor_group.id = properties_in_list.product_list_id
left join simi.simiproduct_single_actor single_actor_facade on single_actor_facade.id = properties_in_facade.facade_layer_id 
) 

SELECT 
    product_id, 
    group_sublayer_single_actor_id, 
    group_sublayer_transparency,
    group_sublayer_visible,
    group_sublyer_sort,
    properties_in_facade.data_set_view_id as group_sublayer_facade_dataset_view_id,
    properties_in_facade.sort as group_sublayer_facade_sort,
    single_actor.transparency as group_sublayer_facade_transparency,
    facade_dataset_view_id, 
    facade_sort,
    facade_transparency 
from 
    first_sublevel
left join simi.simiproduct_properties_in_facade properties_in_facade on properties_in_facade.facade_layer_id = first_sublevel.group_sublayer_single_actor_id
left join simi.simiproduct_single_actor single_actor on single_actor.id = properties_in_facade.facade_layer_id
    