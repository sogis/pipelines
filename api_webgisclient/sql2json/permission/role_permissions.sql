
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
    min(perm_level) AS level_public,
    count(*) AS count_public
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
    min(perm_level) AS perm_level,
    count(*) AS count_private
  FROM 
    simi.simiproduct_properties_in_facade pif
  JOIN
    dsv_private_perm p ON pif.data_set_view_id = p.dsv_id
  GROUP BY 
    facade_layer_id, role_id 
),

fl_all_children_count AS (
  SELECT 
    facade_layer_id,
    count(*) AS count_all
  FROM 
    simi.simiproduct_properties_in_facade pif
  GROUP BY 
    facade_layer_id
),

/* Aus den Kindern abgeleitete Berechtigung einer Rolle für einen Facadelayer. 
 * 
 * Fl mit gemischten Berechtigungen public und 2-n private werden noch als berechtigt 
 * ausgegeben (was falsch ist). Dies wird in folgenden CTEs adressiert.
 */
fl_perm_raw AS (
  SELECT 
    COALESCE(priv.facade_layer_id, pub.facade_layer_id) AS fl_id,
    COALESCE(priv.role_id, pub.role_id) AS role_id,
    CASE 
      WHEN COALESCE(perm_level, '999_max_level') < COALESCE(level_public, '999_max_level') THEN COALESCE(perm_level, '999_max_level')
      ELSE COALESCE(level_public, '999_max_level')
    END AS perm_level, -- Falls sowohl private wie public vorhanden, "erbt" der fl den tiefsten level
    count_private,
    count_public  
  FROM
    fl_public_perm pub
  FULL OUTER JOIN
    fl_private_perm priv ON pub.facade_layer_id = priv.facade_layer_id
),

/* Aus den Kindern abgeleitete Berechtigung einer Rolle für einen Facadelayer. 
 * 
 * Mit der Where-Bedingung wird sichergestellt, dass Facadelayer mit teilweiser
 * Berechtigung für mehrere private Rollen nicht berechtigt werden.
 * Beispiel mit den privaten Rollen A und B, Public (P) und DatasetView 1-3:
 * 1 A
 * 2 B
 * 3 P
 * 
 * Der Facadelayer darf für keine der Rollen berechtigt werden. Im folgenen 
 * Beispiel darf der Facadelayer nur für B berechtigt sein:
 * 1 A,B
 * 2 B
 * 3 P
 */
fl_perm AS ( 
  SELECT
    fl_id,
    r.role_id,
    perm_level
  FROM
    fl_perm_raw r
  JOIN
    fl_all_children_count c ON r.fl_id = c.facade_layer_id
  WHERE
    count_all = COALESCE(count_public, 0) + COALESCE(count_private, 0) 
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
    min(sa.perm_level) AS level_public,
    count(*) AS count_public
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
    min(sa.perm_level) AS level_private,
    count(*) AS count_private
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

pl_all_children_count AS (
  SELECT 
    product_list_id AS pl_id,
    count(*) AS count_all
  FROM
    simi.simiproduct_properties_in_list
  GROUP BY 
    product_list_id
),

lg_perm_raw AS ( -- Gleiche Logik wie bei fl_perm_raw
  SELECT 
    COALESCE(priv.lg_id, pub.lg_id) AS lg_id,
    COALESCE(priv.role_id, pub.role_id) AS role_id,
    CASE 
      WHEN COALESCE(level_private, '999_max_level') < COALESCE(level_public, '999_max_level') THEN COALESCE(level_private, '999_max_level')
      ELSE COALESCE(level_public, '999_max_level')
    END AS perm_level, -- Falls sowohl private wie public vorhanden, "erbt" die lg den tiefsten level
    count_public,
    count_private
  FROM
    layergroup_with_public_sa pub
  FULL OUTER JOIN
    layergroup_with_private_sa priv ON pub.lg_id = priv.lg_id
),

lg_perm AS ( 
  SELECT
    r.lg_id,
    r.role_id,
    perm_level,
    count_all,
    count_public,
    count_private
  FROM
    lg_perm_raw r
  JOIN
    pl_all_children_count c ON r.lg_id = c.pl_id
  WHERE
    count_all = COALESCE(count_public, 0) + COALESCE(count_private, 0) 
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
/*	WHERE --$td remove
	 dp.identifier LIKE 'test.perm.%'*/
),

dep_dsv_count_total AS (
  SELECT 
    dependency_id AS dep_id,
    count(*) AS dsv_count_total
  FROM 
    simi.simiextended_relation 
  WHERE 
    relation_type = '2_data'
  GROUP BY
    dependency_id
),

dep_permission_base AS (
  SELECT 
    dependency_id AS dep_id,
    p.role_id, 
    count(*) AS dsv_count_for_role,
    min(level_) AS perm_level
  FROM 
    simi.simiextended_relation r
  JOIN
    simi.simiiam_permission p ON r.data_set_view_id = p.data_set_view_id 
  WHERE 
    r.relation_type = '2_data'
  GROUP BY
    dependency_id, role_id
),

/* Aus den DSV abgeleitete Berechtigung einer Rolle für eine Dependency (Report, ...). 
 * 
 * Mit der Where-Bedingung wird sichergestellt, dass Dependencies mit teilweiser
 * Berechtigung für mehrere private Rollen nicht berechtigt werden.
 * Beispiel mit den privaten Rollen A und B, Public (P) und DatasetView 1-3:
 * 
 * Im Gegensatz zu den Dataproducts ist public nicht als Spezialrolle berücksichtigt.
 * Darum muss auch für von einem Report referenzierte "public dsv" 
 * die Rolle des Report-Aufrufers konfiguriert werden, damit der Report für die 
 * Rolle berechtigt ist. 
 */
dep_perm AS (
  SELECT 
    role_id,
    d.name AS res_ident,
    FALSE AS writeable,
    perm_level,
    d.dtype AS dep_type
  FROM 
    simi.simiextended_dependency d
  JOIN
    dep_permission_base p ON d.id = p.dep_id
  JOIN
    dep_dsv_count_total c ON d.id = c.dep_id
  WHERE 
      d.dtype IN ('simiExtended_Report', 'simiExtended_FeatureInfo')
    AND 
      dsv_count_total = dsv_count_for_role
),

allperm_raw AS (
  SELECT role_id, res_ident, writeable FROM dp_perm
  UNION ALL 
  SELECT role_id, res_ident, writeable FROM dep_perm
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


/* DEBUG *************************************************************************************************************
 * 
 * Es folgen CTEs, mit denen die Informationen zu den "Schlüssel-CTEs" dsv_perm, fl_perm, lg_perm, rep_perm 
 * ausgegeben werden.

,

debug_dp_union AS (
  SELECT 'dsv_perm' AS cte, role_id, dsv_id AS res_id, perm_level FROM dsv_perm
  UNION ALL 
  SELECT 'fl_perm' AS cte, role_id, fl_id AS res_id, perm_level FROM fl_perm
  UNION ALL 
  SELECT 'lg_perm' AS cte, role_id, lg_id AS res_id, perm_level FROM lg_perm
),

debug_dp AS ( 
  SELECT
    u.*,
    identifier AS res_ident
  FROM
    debug_dp_union u
  JOIN
    simi.simiproduct_data_product p ON u.res_id = p.id
  WHERE 
    identifier LIKE 'test.perm.%'
),

debug_union AS (
  SELECT res_ident, role_id, cte, perm_level FROM debug_dp
  UNION ALL 
  SELECT res_ident, role_id, 'dep_perm' AS cte, perm_level FROM dep_perm
),

debug AS (
  SELECT
    res_ident,
    r.name AS role_name,
    cte,
    perm_level
  FROM
    debug_union d
  JOIN
    simi.simiiam_role r ON d.role_id = r.id
  ORDER BY 
    res_ident,
    role_name,
    cte
)

SELECT * FROM debug
*/






	
