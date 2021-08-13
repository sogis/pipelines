WITH 



dp AS (
  SELECT
    identifier,
    title,
    CASE
      WHEN dtype = 'simiProduct_FacadeLayer' THEN 'Fassade'
      WHEN dtype = 'simiProduct_LayerGroup' THEN 'Gruppe'
      WHEN dtype = 'simiData_RasterView' THEN 'View (R)'
      WHEN dtype = 'simiData_TableView' THEN 'View (T)'
      WHEN dtype = 'simiProduct_FacadeLayer' THEN 'Fassade'
      ELSE 'ERROR - UNMAPPED TYPE'
    END AS res_type,
    id
  FROM
    simi.simi.simiproduct_data_product 
  WHERE
    dtype != 'simiProduct_Map'
),

report AS (
  SELECT
    "name" AS identifier,
    "name" AS title,
    'Report' AS res_type,
    id
  FROM
    simi.simi.simiextended_dependency 
  WHERE
    dtype = 'simiExtended_Report'  
),

resource AS (
  SELECT identifier, title, res_type, id, TRUE AS is_dp FROM dp
  UNION ALL 
  SELECT identifier, title, res_type, id, FALSE AS is_dp FROM report
),

roles_per_resource AS (
  SELECT
    array_agg(role_name ORDER BY role_name) AS roles,
    resource_id
  FROM 
    simi.trafo_resource_role_v
  GROUP BY
    resource_id
)

SELECT 
  res.identifier, 
  CASE 
    WHEN (is_dp AND pub.dp_id IS NULL) THEN 'nein'
    WHEN (is_dp AND pub.dp_id IS NOT NULL) THEN 'ja'
    WHEN (NOT is_dp) THEN 'kein dp'
    ELSE 'ERROR - UNHANDLED STATE'
  END AS published,
  roles,
  res_type,
  res.title 
FROM 
  resource res
LEFT JOIN 
  roles_per_resource ro ON res.id = ro.resource_id
LEFT JOIN
  simi.trafo_published_dp_v pub ON res.id = pub.dp_id
ORDER BY 
  res.identifier

