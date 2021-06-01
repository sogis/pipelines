WITH

sl_perm AS ( -- Permissions of a role on a single layer
	SELECT 
		role_id,
		data_set_view_id AS dp_id,
		level_ AS perm_level
	FROM 
		simi.simiiam_permission sp 		
),

fl_perm AS ( -- Aggregated permissions for a facadelayer. Derived FROM the contained singleactor permissions
	SELECT 
		role_id,
		facade_layer_id AS dp_id,
		min(level_) AS perm_level
	FROM 
		simi.simiproduct_properties_in_facade pif 
	JOIN 
		simi.simiiam_permission sp ON pif.data_set_view_id = sp.data_set_view_id
	GROUP BY 
		role_id, facade_layer_id 
),

sa_perm AS ( -- permissions for single actors
	SELECT role_id, dp_id, perm_level FROM sl_perm
	UNION ALL 
	SELECT role_id, dp_id, perm_level FROM fl_perm
),

lg_perm AS ( -- permissions for layer groups
	SELECT
		role_id,
		lg.id AS dp_id,
		min(perm_level) AS perm_level
	FROM 
		simi.simiproduct_properties_in_list pil 
	JOIN
		simi.simiproduct_layer_group lg ON pil.product_list_id = lg.id -- choose only productlists of type layergroup
	JOIN 
		sa_perm sa ON pil.single_actor_id = sa.dp_id
	GROUP BY 
		role_id, lg.id
),

dp_perm AS ( -- permissions for the dataproducts datasetview, facadelayer and layergroup
	SELECT role_id, dp_id, perm_level FROM sa_perm
	UNION ALL 
	SELECT role_id, dp_id, perm_level FROM lg_perm
),

dp_perm_raw AS ( -- lists all permissions for dataproducts in "human readable" form
	SELECT 
		role_id,
		identifier AS res_ident,
		CASE perm_level
			WHEN '2' -- $td change to 2_read_write
				THEN true
			ELSE false
		END AS writeable
	FROM 
		dp_perm p
	JOIN 
		simi.simiproduct_data_product dp ON p.dp_id = dp.id
),

report AS (
  SELECT 
    id,
    name AS rep_filename
  FROM 
    simi.simiextended_dependency 
  WHERE 
    dtype = 'simiExtended_Report'
),

rep_data_relations AS (
  SELECT 
    dependency_id,
    data_set_view_id 
  FROM 
    simi.simiextended_relation 
  WHERE 
    relation_type = '2_data'
),

rep_perm_raw AS (
  SELECT 
    role_id,
    rep_filename AS res_ident,
    FALSE AS writeable
  FROM 
    report rep
  JOIN 
    rep_data_relations rel ON rep.id = rel.dependency_id 
  JOIN 
    simi.simiiam_permission perm ON rel.data_set_view_id = perm.data_set_view_id 
  GROUP BY 
    role_id,
    rep_filename
),

allperm_raw AS (
  SELECT role_id, res_ident, writeable FROM dp_perm_raw
  UNION ALL 
  SELECT role_id, res_ident, writeable FROM rep_perm_raw
),

perm_json AS (
	SELECT 
		role_id,
		jsonb_agg(
			jsonb_build_object('name', res_ident, 'writable', writeable)
		) AS perm_json
	FROM 
		allperm_raw
	GROUP BY
		role_id	
)

SELECT 
	jsonb_set( -- Inner jsonb_set(...) sets the perm_json array. Outer jsonb_set(...) sets the role name
		jsonb_set('{"role": null, "permissions": { "all_services": null }}', '{permissions, all_services}', perm_json),
		'{role}',
		to_jsonb(name))
	AS js
FROM 
	perm_json p
JOIN 
	simi.simiiam_role r ON p.role_id = r.id 
;

	
