DROP VIEW IF EXISTS simi.trafo_qgs_layers_wms_v;

CREATE VIEW simi.trafo_qgs_layers_wms_v AS 
SELECT 
  layer_json
FROM 
  simi.trafo_qgs_layers_v
WHERE 
  print_only IS FALSE
;
