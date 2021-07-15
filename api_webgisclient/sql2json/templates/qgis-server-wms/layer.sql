SELECT 
  layer_json
FROM 
  simi.trafo_wms_layer_v
WHERE 
  print_or_ext IS FALSE 
AND
  (
  identifier like 'ch.so.arp.nutzungsplanun%'  )
  