DROP VIEW IF EXISTS simi.trafo_qgs_rootlayers_wms_v;

CREATE VIEW simi.trafo_qgs_rootlayers_wms_v AS 
SELECT 
  identifier
FROM 
  simi.trafo_qgs_rootlayers_v
WHERE 
  print_only IS FALSE
;
