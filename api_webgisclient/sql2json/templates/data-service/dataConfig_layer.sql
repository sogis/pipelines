--Gibt nur die Attribute von Vector-Layer wieder, also Datasets mit dem datatyp vector.
select 
    json_strip_nulls( 
        jsonb_build_object(
            'name',basic.name,
            'db_url',basic.db_url,
            'schema',basic.schemaname,
            'table_name', basic.tablename,
            'primary_key',basic.primary_key,
            'fields', 
            case 
                when fields.fields is not null 
                then fields.fields 
                else '[]'::JSON 
            end, --Muss z.Z. noch so gemacht werden, weil fields (noch) required sind. 
            'geometry',
            case 
                when (basic.geo_field_name is not null
                      AND 
                      basic.geo_type is not null
                      and 
                      basic.epsg_code is not null ) --Im Simi-Betrieb sollte das eh nicht vorkommen. Bei migrierten Daten ist es noch möglich. 
                then json_build_object(
                                       'geometry_column', basic.geo_field_name, 
                                       'geometry_type', basic.geo_type, 
                                       'srid', basic.epsg_code
                                       )
            end
        )::json
    )                                       
from 
    simi.trafo_data_service_layer_basic_v basic
left join 
    simi.trafo_data_service_layer_fields_v fields 
    on 
    fields.id = basic.product_id 
where 
    (basic.layer_type = 'datasetview' 
     and 
     basic."datatype" = 'vector')
