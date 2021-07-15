SET search_path to simi;
drop view trafo_data_service_layer_fields_v;
CREATE OR REPLACE VIEW trafo_data_service_layer_fields_v
AS 
SELECT 
    data_product.id,
    data_product.identifier,
    json_agg(json_build_object('name', table_field.name, 'alias', table_field.alias, 'data_type', table_field.type_name)) AS fields,
    json_agg(to_json(table_field.name)) AS names
FROM 
    simiproduct_data_product data_product
LEFT JOIN 
    simidata_table_view table_view 
    ON 
    table_view.id = data_product.id
LEFT JOIN 
    simidata_postgres_table postgres_table 
    ON 
    postgres_table.id = table_view.postgres_table_id
LEFT JOIN 
    (select 
         "name", 
         alias, 
         case 
             when type_name = 'varchar' 
             then 'character varying' 
             when type_name = 'int4' 
             then 'integer' 
             when type_name = 'bool' 
             then 'boolean' 
             when type_name = 'float8' 
             then 'double precision' 
             when type_name = 'int2' 
             then 'smallint' 
             when type_name = 'int8' 
             then 'integer'
             when type_name = 'float4' 
             then 'double precision'
             when type_name = 'bpchar' 
             then 'character'
             when type_name = 'Stellvertreter' 
             then 'text' 
             else type_name 
         end as type_name, 
         postgres_table_id, 
         id 
     from 
     simidata_table_field
    ) table_field 
    ON 
    table_field.postgres_table_id = table_view.postgres_table_id
LEFT JOIN 
    simidata_view_field view_field 
    ON 
    view_field.table_field_id = table_field.id
WHERE 
    table_field.name IS NOT NULL
GROUP BY 
    data_product.id, 
    data_product.identifier
;

GRANT SELECT ON TABLE trafo_data_service_layer_fields_v TO simi_write;