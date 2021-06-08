DROP VIEW IF EXISTS simi.trafo_qgs_rootlayers_print_v;

CREATE VIEW simi.trafo_qgs_rootlayers_print_v AS 

SELECT 
  identifier
FROM 
  simi.trafo_qgs_rootlayers_v
;
