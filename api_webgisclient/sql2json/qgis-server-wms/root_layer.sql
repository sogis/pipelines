SELECT 
  identifier
FROM 
  simi.trafo_wms_rootlayer_v
WHERE 
  print_or_ext IS FALSE 
and identifier like 'ch.so.arp.nutzungsplanun%'