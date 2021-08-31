
DROP VIEW IF EXISTS simi.trafo_resource_role_v;

CREATE VIEW simi.trafo_resource_role_v AS


/* Gibt die Permissions pro Rolle für DSV und DSV-Gruppen aus.
 * 
 * Die resultierende Permission für DSV-Gruppen wird aus den DSV abgeleitet.
 * Damit eine Gruppierung für eine Rolle berechtigt ist, müssen alle
 * DSV der entsprechenden privaten Rolle oder der speziellen Rolle "public"
 * zugewiesen sein.
 * 
 * Falls ein oder mehrere DSV einer DSV-Gruppe eine private Rolle zugewiesen
 * haben, wird "public" für die Gruppe unterdrückt (nicht ausgegeben).
 * Dies auch, falls allen DSV die Rolle public zugewiesen ist.
 * Sollte nicht stören, da für die Gruppierungen sowieso nur Leseberechtigungen
 * von public oder "private" gefragt ist.
 * 
 * Debugging aum einfachsten mit der CTE "role_perm". In dieser sind die entscheidenden
 * Count-Spalten extra enthalten, obwohl für die folgenden CTE nicht relevant.
 * 
 * */
WITH

role_base AS (
  SELECT
    id AS role_id,
    "name" AS role_name,
    CASE
      WHEN "name" = 'public' THEN TRUE
      ELSE FALSE
    END AS is_public_role
  FROM
    simi.simi.simiiam_role 
),

dsv_dsv AS ( -- Damit alles gleich gemacht werden kann: Dsv bildet einer Gruppe mit sich selbst
  SELECT 
    id AS res_id,
    id AS dsv_id
  FROM 
    simi.simidata_data_set_view 
),

fl_dsv AS (
  SELECT 
    facade_layer_id AS res_id,
    data_set_view_id AS dsv_id
  FROM 
    simi.simiproduct_properties_in_facade pif
),

sa_dsv AS (
  SELECT res_id, dsv_id FROM dsv_dsv
  UNION ALL
  SELECT res_id, dsv_id FROM fl_dsv
),

 
pl_dsv AS ( -- Layergruppen und Hintergrundkarten
  SELECT 
    pil.product_list_id AS res_id,
    dsv_id
  FROM 
    simi.simiproduct_properties_in_list pil
  JOIN
    sa_dsv sa ON pil.single_actor_id = sa.res_id
  LEFT JOIN 
    simi.simi.simiproduct_map m ON pil.product_list_id = m.id 
  WHERE
      m.id IS NULL 
    OR 
      m.background IS TRUE 
),

rep_dsv AS ( -- Reports mit Datenbeziehung auf DSV
  SELECT
    r.dependency_id AS res_id,
    r.data_set_view_id AS dsv_id
  FROM 
    simi.simi.simiextended_relation r
  JOIN
    simi.simi.simiextended_dependency d ON r.dependency_id = d.id
  WHERE
      d.dtype = 'simiExtended_Report'
    AND
      r.relation_type = '2_data'
),

resgroups_union AS (
  SELECT res_id, dsv_id FROM dsv_dsv
  UNION ALL 
  SELECT res_id, dsv_id FROM fl_dsv
  UNION ALL 
  SELECT res_id, dsv_id FROM pl_dsv
  UNION ALL 
  SELECT res_id, dsv_id FROM rep_dsv--dep_dsv
),

res_dsv_total_count AS (
  SELECT 
    res_id,
    count(*) AS dsv_count_per_res
  FROM
    resgroups_union    
  GROUP BY 
    res_id
),

res_role_perm AS (
  SELECT 
    res_id,
    min(level_) AS perm_level,
    count(*) AS dsv_count_per_res_role,
    role_id
  FROM
    resgroups_union r
  JOIN
    simi.simiiam_permission p ON r.dsv_id = p.data_set_view_id 
  GROUP BY 
    res_id, 
    role_id
),

res_role_perm_counts AS (
  SELECT 
    rp.res_id,
    perm_level,
    dsv_count_per_res_role,
    dsv_count_per_res,
    role_name,
    is_public_role
  FROM
    res_role_perm rp
  JOIN
    role_base r ON rp.role_id = r.role_id
  JOIN
    res_dsv_total_count t ON rp.res_id = t.res_id
),

res_public_perm_counts AS (
  SELECT
    *
  FROM
    res_role_perm_counts rc
  WHERE
    is_public_role IS TRUE 
),

res_other_perm_counts AS (
  SELECT
    *
  FROM
    res_role_perm_counts rc
  WHERE
    is_public_role IS FALSE 
),

/*
 * Vereinigt die Eigenschaften der Gruppe bezüglich der entsprechenden 
 * privaten Rolle und der Rolle "public".
 * Aus den beiden Informationen wird berechnet,
 * welche Berechtigung für die Rolle und DSV-Gruppe resultiert.
 * 
 * Mit der Where-Bedingung in der folgenden CTE wird sichergestellt, 
 * dass Gruppen mit teilweiser Berechtigung für private Rollen nicht berechtigt werden.
 * Beispiele mit den privaten Rollen A und B, Public (P) und DatasetView 1-3:
 * 
 * 1 A
 * 2 B
 * 3 P
 * --> Gruppe wird nicht berechtigt.
 * 
 * 1 A,B
 * 2 B
 * 3 P
 * --> Gruppe wird für B berechtigt.
 * 
 * 1 A
 * 2 B,P (read-write für B, read für P)
 * 3 P
 * --> Gruppe wird für A berechtigt. 
 */
role_perm_dsv_group_raw AS (
  SELECT
    COALESCE(o.res_id, p.res_id) AS resource_id,
    COALESCE(o.role_name, p.role_name) AS role_name,
    COALESCE(p.perm_level, o.perm_level) AS perm_level, -- Falls eine public-berechtigung vorliegt, hat diese vorrang
    COALESCE(o.dsv_count_per_res, p.dsv_count_per_res) AS dsv_count_per_res,
    COALESCE(o.dsv_count_per_res_role, 0) AS count_other_role,
    COALESCE(p.dsv_count_per_res_role, 0) AS count_public_role
  FROM
    res_other_perm_counts o
  FULL OUTER JOIN    
    res_public_perm_counts p ON o.res_id = p.res_id
),

role_perm_dsv_group AS (
  SELECT 
    * 
  FROM
    role_perm_dsv_group_raw
  WHERE
    (count_other_role + count_public_role) >= dsv_count_per_res
),

role_perm_ext AS (
  SELECT 
    id AS resource_id,
    'public' AS role_name,
    '1_read' AS perm_level
  FROM
    simi.simiproduct_external_map_layers
)

SELECT resource_id, role_name, perm_level FROM role_perm_dsv_group
UNION ALL 
SELECT resource_id, role_name, perm_level FROM role_perm_ext
;

GRANT SELECT ON TABLE simi.trafo_resource_role_v TO simi_write;