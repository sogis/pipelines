with 

ugroup as (
	select
		sg.id as group_id,
		si.identifier as group_identifier 
	from 
		simiiam_group sg 
	inner join 
		simiiam_identity si on sg.id = si.id 
),

group_roles as (
	select 
		group_id,
		jsonb_agg(name) as role_arr
	from 
		simiiam_role_group_link rg
	inner join
		simiiam_role r on rg.role_id = r.id
	group by 
		group_id	
)

select
	json_build_object('name', group_identifier, 'roles', role_arr) as group_json 
from 
	ugroup g
left outer join 
	group_roles r on g.group_id = r.group_id

	
	