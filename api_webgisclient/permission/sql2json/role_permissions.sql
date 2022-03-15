WITH 

res_ident AS (
  SELECT identifier AS res_ident, id FROM simi.simiproduct_data_product 
  UNION ALL
  SELECT split_part("name", '.', 1) AS res_ident, id FROM simi.simi.simiextended_dependency -- split_part(..) zur entfernung des format-suffix im namen (.xlsx in av_gb_uebersicht.xlsx)
),

role_perm AS (
  SELECT
    res_ident,
    role_name,
    perm_level,
    CASE
      WHEN perm_level = '2_read_write' THEN jsonb_build_object('writable', TRUE)
      ELSE jsonb_build_object()
    END AS writable_json
  FROM
    simi.trafo_resource_role_v rp
  JOIN
    res_ident res ON rp.resource_id = res.id
),

role__res_obj AS (
  SELECT
    role_name,
    jsonb_object_agg(res_ident, writable_json) AS res_obj
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