
DROP VIEW IF EXISTS simi.trafo_wms_rootlayer_v;

CREATE VIEW simi.trafo_wms_rootlayer_v AS 


WITH

productlist AS (
	SELECT 
		identifier,
		false AS print_only
	FROM 
		simi.simiproduct_product_list pl
	JOIN
		simi.trafo_wms_dp_pubstate_v dp ON pl.id = dp.dp_id
	WHERE 
	 dp.root_published IS TRUE 
),

single_actor AS ( --$td auf andere VIEW überragen
  SELECT 
  	identifier,
  	(eml.id IS NOT NULL) AS print_only 
  FROM 
  	simi.simiproduct_single_actor sa
  JOIN
  	simi.trafo_wms_dp_pubstate_v dp ON sa.id = dp.dp_id 
  LEFT JOIN 
  	simi.simiproduct_external_map_layers eml ON sa.id = eml.id 
  WHERE
    dp.root_published IS TRUE 
),

merged AS (
  SELECT identifier, print_only FROM productlist
  UNION ALL
	SELECT identifier, print_only FROM single_actor
)

SELECT
	*
FROM 
	merged
ORDER BY
	identifier
;

