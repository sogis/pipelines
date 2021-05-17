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

user_groups as (
	select 
		user_id,
		jsonb_agg(group_identifier) as group_arr
	from 
		simiiam_group_user_link gu 
	inner join
		ugroup on gu.group_id = ugroup.group_id
	group by 
		user_id	
),

user_roles as (
	select 
		user_id,
		jsonb_agg(name) as role_arr
	from 
		simiiam_role_user_link ru
	inner join
		simiiam_role r on ru.role_id = r.id
	group by 
		user_id	
),

users as (
	select
		u.id as user_id,
		si.identifier as user_identifier 
	from 
		simiiam_user u
	inner join 
		simiiam_identity si on u.id = si.id 
)

select
	json_build_object('name', user_identifier, 'groups', group_arr, 'roles', role_arr) as user_json 
from 
	users u
left outer join 
	user_roles r on u.user_id = r.user_id
left outer join 
	user_groups g on u.user_id = g.user_id
	
	