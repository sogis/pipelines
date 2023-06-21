WITH 

res_ident AS (
  SELECT derived_identifier AS res_ident, id FROM simi.simiproduct_data_product 
  UNION ALL
  SELECT split_part("name", '.', 1) AS res_ident, id FROM simi.simi.simiextended_dependency -- split_part(..) zur entfernung des format-suffix im namen (.xlsx in av_gb_uebersicht.xlsx)
),

dsv_dependency_unique AS (
SELECT 
    data_set_view_id,
    d.dtype AS dependency_type,
    (max(dependency_id::varchar))::uuid AS dependency_id
  FROM
    simi.simiextended_relation r
  JOIN
    simi.simiextended_dependency d ON r.dependency_id = d.id
  WHERE
    r.relation_type = '1_display'
  AND 
	d.dtype = 'simiExtended_FeatureInfo'
  GROUP BY
    data_set_view_id,
    d.dtype
	order by data_set_view_id
),

role_perm AS (
  SELECT
    res_ident,
    role_name,
    perm_level,
    CASE
      WHEN perm_level = '2_read_write' THEN jsonb_build_object('writable', TRUE)
      ELSE jsonb_build_object()
    END AS writable_json,
    CASE
      WHEN dependency_type = 'simiExtended_FeatureInfo' THEN jsonb_build_object('info_template', TRUE)
      ELSE jsonb_build_object()
    END AS info_template_json
  FROM
    simi.trafo_resource_role_v rp
  JOIN
    res_ident res ON rp.resource_id = res.id
),

role__res_obj AS (
  SELECT
    role_name,
    jsonb_object_agg(res_ident, writable_json || info_template_json) AS res_obj
  FROM
    role_perm
  GROUP BY
    role_name
)

SELECT
  jsonb_build_object(
    'role', role_name, 
    'permissions', jsonb_build_object('all_services', res_obj)
  ) AS role_obj
FROM 
  role__res_obj
