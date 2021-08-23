SELECT 
  identifier
FROM 
  simi.trafo_wms_layer_v
WHERE 
    print_or_ext IS TRUE 
  OR 
    identifier IN ('ch.so.agi.hintergrundkarte_sw', 'ch.so.agi.hintergrundkarte_farbig', 'ch.so.agi.hintergrundkarte_ortho')