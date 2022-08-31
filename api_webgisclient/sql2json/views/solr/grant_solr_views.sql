-- Not ordered by dependency, as CASCADE is set
GRANT ALL ON TABLE simi.solr_layer_background_v TO admin;
GRANT SELECT ON TABLE simi.solr_layer_background_v TO simi_write, sogis_service;

GRANT ALL ON TABLE simi.solr_layer_base_v TO admin;
GRANT SELECT ON TABLE simi.solr_layer_base_v TO simi_write, sogis_service;

GRANT ALL ON TABLE simi.solr_layer_foreground_v TO admin;
GRANT SELECT ON TABLE simi.solr_layer_foreground_v TO simi_write, sogis_service;
