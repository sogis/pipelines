CREATE OR REPLACE VIEW simi.solr_layer_background_v AS 

SELECT 
    id,
    display,
    dset_children,
    dset_info,
    search_1_stem,
    search_2_stem,
    search_3_stem,
    facet
FROM simi.solr_layer_base_v
WHERE facet = 'background'::text;

GRANT ALL ON TABLE simi.solr_layer_background_v TO admin
;
GRANT SELECT ON TABLE simi.solr_layer_background_v TO simi_write, sogis_service
;

