SET search_path to simi;
DROP VIEW IF EXISTS trafo_data_service_layer_basic_v;
CREATE VIEW trafo_data_service_layer_basic_v
AS
         SELECT 
            product.id AS product_id,
            postgres_table.id AS postgres_table_id,
            product.identifier AS name,
            product.title,
            product.synonyms,
            product.keywords,
            product.description,
            CASE
                WHEN 
                    (product.id IN ( SELECT 
                                         simidata_data_set_view.id
                                     FROM 
                                         simidata_data_set_view)
                     ) 
                THEN 
                    'datasetview'::text
                WHEN 
                    (product.id IN ( SELECT 
                                         simiproduct_layer_group.id
                                     FROM 
                                         simiproduct_layer_group)
                    ) 
                THEN 
                    'layergroup'::text
                WHEN (product.id IN ( SELECT 
                                          simiproduct_facade_layer.id
                                      FROM 
                                          simiproduct_facade_layer)
                     ) 
                THEN 
                    'facadelayer'::text
                ELSE 
                    NULL::text
            END AS layer_type,
            'postgresql:///?service=sogis_services'::text AS db_url,
            model_schema.schema_name AS schemaname,
            postgres_table.table_name AS tablename,
            postgres_table.id_field_name AS primary_key,
            postgres_table.geo_field_name,
            postgres_table.geo_type,
            postgres_table.geo_epsg_code AS epsg_code,
            raster.rasterds_path AS raster_datasource,
            CASE
                WHEN 
                    (product_data_set_view.id IN (SELECT 
                                                      simidata_raster_view.id
                                                  FROM 
                                                      simidata_raster_view)
                    ) 
                THEN 
                    'raster'::text
                WHEN 
                    (product_data_set_view.id IN (SELECT 
                                                      simidata_table_view.id
                                                  FROM 
                                                      simidata_table_view)
                    ) 
                THEN 
                    'vector'::text
                ELSE 
                    NULL::text
            END AS datatype,
            product_data_set_view.style_server AS qml,
            table_view.search_type as search_type, 
            table_view.search_facet as search_facet, 
            table_view.search_filter_word as search_filter_word,
            product_data_set_view.raw_download as download,
            pub_scope.pub_to_wms
            
         FROM 
             simiproduct_data_product product
         LEFT JOIN 
             simidata_table_view table_view 
             ON 
             table_view.id = product.id
         LEFT JOIN 
             simidata_postgres_table postgres_table 
             ON 
             postgres_table.id = table_view.postgres_table_id
         LEFT JOIN 
             simidata_data_theme model_schema 
             ON 
             model_schema.id = postgres_table.data_theme_id
         LEFT JOIN 
             simidata_postgres_db postgres_db 
             ON 
             postgres_db.id = model_schema.postgres_db_id
         LEFT JOIN 
             (SELECT 
                  raster_view.id AS rasterview_id,
                  raster_ds.path AS rasterds_path
              FROM 
                  simidata_raster_view raster_view,
                  simidata_raster_ds raster_ds
              WHERE 
                  raster_view.raster_ds_id = raster_ds.id
             ) raster 
             ON 
             raster.rasterview_id = product.id
         LEFT JOIN 
             simiproduct_data_product_pub_scope pub_scope 
             ON 
             product.pub_scope_id = pub_scope.id
         LEFT JOIN 
             simidata_data_set_view product_data_set_view 
             ON 
             product.id = product_data_set_view.id
;
         
GRANT SELECT ON TABLE trafo_data_service_layer_basic_v TO simi_write;
