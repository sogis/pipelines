--Gibt nur die Attribute von Vector-Layer wieder, also Datasets mit dem datatyp vector.

select 
    json_strip_nulls( jsonb_build_object('name',simi_layer_basic.name,
                       'db_url',simi_layer_basic.db_url,
                       'schema',simi_layer_basic.schemaname,
                       'table_name', simi_layer_basic.tablename,
                       'primary_key',simi_layer_basic.primary_key,
                       'fields', 
                       case when fields.fields is not null 
                            then fields.fields 
                            else '[]'::JSON 
                            end, --Muss z.Z. noch so gemacht werden, weil fields (noch) required sind. 
                       'geometry',
                       case when (simi_layer_basic.geo_field_name is not null
                                  AND 
                                  simi_layer_basic.geo_type is not null
                                  and 
                                  simi_layer_basic.epsg_code is not null ) --Im Simi-Betrieb sollte das eh nicht vorkommen. Bei migrierten Daten ist es noch möglich. 
                            then json_build_object('geometry_column', simi_layer_basic.geo_field_name, 
                                                    'geometry_type', simi_layer_basic.geo_type, 
                                                    'srid', simi_layer_basic.epsg_code)
                                                   end)::json)
                                            
from 
    simi.simi_layer_basic
left join simi.simi_layer_fields fields on fields.id = simi_layer_basic.product_id 
where 
    (simi_layer_basic.layer_type = 'datasetview' and simi_layer_basic."datatype" = 'vector')
    -- downloadbar ODER suchbar 
    --and 
    --(simi_layer_basic.download = true or simi_layer_basic.search_type in ('2_if_loaded','3_always'))
