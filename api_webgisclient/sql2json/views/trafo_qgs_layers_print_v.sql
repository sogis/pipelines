DROP VIEW IF EXISTS simi.trafo_qgs_layers_print_v;

CREATE VIEW simi.trafo_qgs_layers_print_v AS 
SELECT 
  layer_json
FROM 
  simi.trafo_qgs_layers_v
;
