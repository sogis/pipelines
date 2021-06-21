
DROP VIEW IF EXISTS simi.trafo_wms_rootlayer_v;

CREATE VIEW simi.trafo_wms_rootlayer_v AS 


WITH

lg_with_children AS (
  SELECT
    p.product_list_id AS lg_id
  FROM
    simi.simiproduct_properties_in_list p
  JOIN
    simi.trafo_wms_dp_common_v c ON p.single_actor_id = c.dp_id
  GROUP BY 
    p.product_list_id
  HAVING count(*) > 0
),

layer_group AS (
	SELECT 
		identifier,
		false AS print_only
	FROM 
		simi.simiproduct_layer_group lg 
	JOIN
		simi.trafo_wms_dp_common_v dp ON lg.id = dp.dp_id
	JOIN
	  lg_with_children c ON lg.id = c.lg_id
  WHERE 
    dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- = status zu löschen
),

singleactor_in_group AS ( 
	SELECT 
		single_actor_id 
	FROM 
		simi.simiproduct_properties_in_list pil 
	GROUP BY
		single_actor_id 
),

root_pub_single_actor AS (
	SELECT 
		identifier,
		CASE 
			WHEN eml.id IS NULL THEN false
			ELSE true
		END AS print_only,
		sa.id AS sa_id
	FROM 
		simi.simiproduct_single_actor sa
	JOIN
		simi.trafo_wms_dp_common_v dp ON sa.id = dp.dp_id 
	LEFT JOIN 
		simi.simiproduct_external_map_layers eml ON sa.id = eml.id 
	LEFT JOIN 
		singleactor_in_group sig ON sa.id = sig.single_actor_id
	WHERE 
	    dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- = status zu löschen
	  AND 
			sig.single_actor_id IS NULL -- In einer Gruppe enthaltene Singleactors dürfen nicht "für sich" publiziert sein
		AND 
			dp.pub_to_wms IS true
),

fl_with_children AS (
  SELECT
    p.facade_layer_id AS fl_id
  FROM
    simi.simiproduct_properties_in_facade p
  JOIN
    simi.trafo_wms_dp_common_v c ON p.data_set_view_id = c.dp_id
  GROUP BY 
    p.facade_layer_id
  HAVING count(*) > 0
),

facade_layer AS (
  SELECT
    identifier,
    print_only
  FROM
    root_pub_single_actor sa
  JOIN
    fl_with_children flc ON sa.sa_id = flc.fl_id
),

dataset_view AS (
  SELECT
    identifier,
    print_only
  FROM
    root_pub_single_actor sa
  JOIN
    simi.simidata_data_set_view dsv ON sa.sa_id = dsv.id
),

merged AS (
  SELECT identifier, print_only FROM layer_group
  UNION ALL
	SELECT identifier, print_only FROM facade_layer
	UNION ALL
  SELECT identifier, print_only FROM dataset_view
)

SELECT
	*
FROM 
	merged
ORDER BY
	identifier
;

