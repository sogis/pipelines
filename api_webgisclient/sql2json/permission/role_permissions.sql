
/* Gibt die Permissions pro Rolle für Dataproducts und Reports aus.
 * 
 * Die resultierende Permission für ein Facadelayer / eine Layergroup
 * wird aus den Kindern abgeleitet.
 * Damit eine Gruppierung für eine Rolle berechtigt ist, müssen alle
 * Kinder der entsprechenden Rolle oder der speziellen Rolle "public"
 * zugewiesen sein.
 * 
 * In den CTEs mit "full outer join" werden jeweils die Eigenschaften
 * der Gruppe bezüglich der entsprechenden privaten Rolle und der Rolle
 * "public" vereinigt. Aus den beiden Informationen wird berechnet,
 * welche Berechtigung für die Rolle und Ebenen-Gruppe resultiert.
 * 
 * Lösungsweg für fl_private_perm, fl_public_perm beschreiben
 * Fall mit layergruppe = '5877dcac-052a-4356-859c-2e3a4f28abb5' untersuchen
 * */
WITH

dsv_perm_base AS (
  SELECT 
    level_ AS perm_level,
    p.data_set_view_id AS dsv_id,
    role_id,
    (r."name" = 'public') AS is_public_role
  FROM 
    simi.simidata_data_set_view d
  JOIN
    simi.simiiam_permission p ON d.id = p.data_set_view_id 
  JOIN
    simi.simiiam_role r ON p.role_id = r.id  
),

dsv_public_perm AS (
  SELECT 
    *
  FROM 
    dsv_perm_base
  WHERE
    is_public_role IS TRUE 
),

dsv_private_perm AS (
  SELECT 
    *
  FROM 
    dsv_perm_base
  WHERE
    is_public_role IS FALSE  
),

dsv_perm AS ( -- Permissions einer Rolle für ein datasetview. Falls eine public PERMISSION besteht und diese höher ist, wird diese verwendet (übersteuerung)
	SELECT 
		sp.role_id,
		data_set_view_id AS dsv_id,
		CASE 
		  WHEN COALESCE(perm_level, '0_non_public') > level_ THEN perm_level -- --> public permission level wins 
		  ELSE level_
		END AS perm_level
	FROM 
		simi.simiiam_permission sp 		
	LEFT JOIN
	 dsv_public_perm p ON sp.data_set_view_id = p.dsv_id 
),

fl_public_perm AS (
  SELECT 
    role_id,
    facade_layer_id,
    min(perm_level) AS level_public
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN
    dsv_public_perm p ON pif.data_set_view_id = p.dsv_id
  GROUP BY 
    facade_layer_id, role_id 
),

fl_private_perm AS (
  SELECT 
    role_id,
    facade_layer_id,
    min(perm_level) AS perm_level
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN
    dsv_private_perm p ON pif.data_set_view_id = p.dsv_id
  GROUP BY 
    facade_layer_id, role_id 
),

fl_perm AS ( -- Aus den Kindern abgeleietete Berechtigung für einen Facadelayer.
  SELECT 
    COALESCE(priv.facade_layer_id, pub.facade_layer_id) AS fl_id,
    COALESCE(priv.role_id, pub.role_id) AS role_id,
    CASE 
      WHEN COALESCE(perm_level, '999_max_level') < COALESCE(level_public, '999_max_level') THEN COALESCE(perm_level, '999_max_level')
      ELSE COALESCE(level_public, '999_max_level')
    END AS perm_level -- Falls sowohl private wie public vorhanden, "erbt" der fl den tiefsten level  
  FROM
    fl_public_perm pub
  FULL OUTER JOIN
    fl_private_perm priv ON pub.facade_layer_id = priv.facade_layer_id
),

sa_perm_union AS ( -- permissions for single actors
	SELECT role_id, dsv_id AS sa_id, perm_level FROM dsv_perm
	UNION ALL 
	SELECT role_id, fl_id AS sa_id, perm_level FROM fl_perm
),

sa_perm AS (
  SELECT
    sa_id,  
    role_id,
    perm_level,
    (r."name" = 'public') AS is_public_role
  FROM 
    sa_perm_union sa
  JOIN
    simi.simiiam_role r ON sa.role_id = r.id  
),

layergroup_with_public_sa AS ( -- Alle Produktlisten mit 1-n "public" Kindern
  SELECT 
    lg.id AS lg_id,
    sa.role_id,
    min(sa.perm_level) AS level_public
  FROM
    simi.simiproduct_properties_in_list p
  JOIN
    sa_perm sa ON p.single_actor_id = sa.sa_id
  JOIN
    simi.simiproduct_layer_group lg ON p.product_list_id = lg.id
  WHERE
    sa.is_public_role IS TRUE 
  GROUP BY 
    lg.id, sa.role_id 
),

layergroup_with_private_sa AS ( -- Alle Layergruppen mit 1-n "private" Kindern
  SELECT 
    lg.id AS lg_id,
    sa.role_id,
    min(sa.perm_level) AS level_private
  FROM
    simi.simiproduct_properties_in_list p
  JOIN
    sa_perm sa ON p.single_actor_id = sa.sa_id
  JOIN
    simi.simiproduct_layer_group lg ON p.product_list_id = lg.id
  WHERE
    sa.is_public_role IS FALSE  
  GROUP BY 
    lg.id, sa.role_id 
),

lg_perm AS (
  SELECT 
    COALESCE(priv.lg_id, pub.lg_id) AS lg_id,
    COALESCE(priv.role_id, pub.role_id) AS role_id,
    CASE 
      WHEN COALESCE(level_private, '999_max_level') < COALESCE(level_public, '999_max_level') THEN COALESCE(level_private, '999_max_level')
      ELSE COALESCE(level_public, '999_max_level')
    END AS perm_level -- Falls sowohl private wie public vorhanden, "erbt" die lg den tiefsten level  
  FROM
    layergroup_with_public_sa pub
  FULL OUTER JOIN
    layergroup_with_private_sa priv ON pub.lg_id = priv.lg_id
),

dp_perm_union AS ( -- permissions for the dataproducts datasetview, facadelayer and layergroup
	SELECT role_id, sa_id AS dp_id, perm_level FROM sa_perm
	UNION ALL 
	SELECT role_id, lg_id AS dp_id, perm_level FROM lg_perm
),

dp_perm AS ( -- lists all permissions for dataproducts in "human readable" form
	SELECT 
		role_id,
		dp_id,
		identifier AS res_ident,
		CASE perm_level
			WHEN '2_read_write'
				THEN true
			ELSE false
		END AS writeable
	FROM 
		dp_perm_union p
	JOIN 
		simi.simiproduct_data_product dp ON p.dp_id = dp.id
/*		
	WHERE --$td remove
	 dp.identifier LIKE 'test.perm.%'
	 */
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

rep_perm AS (
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
  SELECT role_id, res_ident, writeable FROM dp_perm
  UNION ALL 
  SELECT role_id, res_ident, writeable FROM rep_perm
),

perm_json AS (
  SELECT 
    role_id,
    jsonb_object_agg(
      res_ident,
      jsonb_build_object('writable', writeable)
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



	
