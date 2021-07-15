DROP VIEW IF EXISTS simi.trafo_wms_rootlayer_v;

CREATE VIEW simi.trafo_wms_rootlayer_v AS 

/*
 * Gibt die Identifier aller Root (= Top-Level) publizierten Ebenen zurück.
 * 
 * Layer mit "print_or_ext = true" sind zusätzliche Ebenen für Druck, Integration
 * von WM(T)S von Drittanbietern, ...
 */
WITH

productlist AS (
	SELECT 
		identifier,
		false AS print_or_ext
	FROM 
		simi.simiproduct_product_list pl
	JOIN
		simi.trafo_wms_published_dp_v dp ON pl.id = dp.dp_id
	WHERE 
	 dp.root_published IS TRUE 
),

single_actor AS ( --$td auf andere VIEW überragen
  SELECT 
  	identifier,
  	(eml.id IS NOT NULL) AS print_or_ext 
  FROM 
  	simi.simiproduct_single_actor sa
  JOIN
  	simi.trafo_wms_published_dp_v dp ON sa.id = dp.dp_id 
  LEFT JOIN 
  	simi.simiproduct_external_map_layers eml ON sa.id = eml.id 
  WHERE
    dp.root_published IS TRUE 
),

merged AS (
  SELECT identifier, print_or_ext FROM productlist
  UNION ALL
	SELECT identifier, print_or_ext FROM single_actor
)

SELECT
	identifier,
	print_or_ext
FROM 
	merged
ORDER BY
	identifier
;

