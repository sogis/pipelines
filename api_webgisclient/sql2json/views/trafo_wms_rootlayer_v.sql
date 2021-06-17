DROP VIEW IF EXISTS simi.trafo_wms_rootlayer_v;

CREATE VIEW simi.trafo_wms_rootlayer_v AS 

WITH

layer_groups AS (
	SELECT 
		identifier,
		false AS print_only
	FROM 
		simi.simiproduct_layer_group lg 
	JOIN
		simi.simiproduct_data_product dp ON lg.id = dp.id 
),

singleactors_in_group AS ( 
	SELECT 
		single_actor_id 
	FROM 
		simi.simiproduct_properties_in_list pil 
	GROUP BY
		single_actor_id 
),

root_pub_single_actors AS (
	SELECT 
		identifier,
		CASE 
			WHEN eml.id IS NULL THEN false
			ELSE true
		END AS print_only
	FROM 
		simi.simiproduct_single_actor sa
	JOIN
		simi.simiproduct_data_product dp ON sa.id = dp.id 
	JOIN 
		simi.simiproduct_data_product_pub_scope ps ON dp.pub_scope_id = ps.id 
	LEFT JOIN 
		simi.simiproduct_external_map_layers eml ON sa.id = eml.id 
	LEFT JOIN 
		singleactors_in_group sig ON sa.id = sig.single_actor_id
	WHERE 
			sig.single_actor_id IS NULL -- In einer Gruppe enthaltene Singleactors dürfen nicht "für sich" publiziert sein
		AND 
			ps.pub_to_wms IS true
),

merged AS (
	SELECT identifier, print_only FROM layer_groups
	UNION ALL
	SELECT identifier, print_only FROM root_pub_single_actors
)

SELECT
	*
FROM 
	merged
ORDER BY
	identifier
;
