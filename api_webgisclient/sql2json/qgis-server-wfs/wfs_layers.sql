with

pgtable_json as (
	select 
		tbl.id as table_id,
		jsonb_build_object(
			'dbconnection', db_service_url,
			'schema', schema_name,
			'table', table_name,
			'unique_key', id_field_name,
			'geometry_field', geo_field_name,
			'geometry_type', geo_type,
			'srid', geo_epsg_code
		) as tbl_json
	from 
		simi.simidata_postgres_table tbl 
	join 
		simi.simidata_data_theme dt on tbl.data_theme_id = dt.id 
	join 
		simi.simidata_postgres_db db on dt.postgres_db_id = db.id 
),

tbl_dsv as (
	select 
		dsv.id as dsv_id,
		identifier,
		coalesce(title, identifier) as title,
		postgres_table_id
	from 
		simi.simiproduct_data_product p
	join
		simi.simidata_data_set_view dsv on p.id = dsv.id 
	join
		simi.simidata_table_view tv on dsv.id = tv.id 
	where 
		dsv.raw_download is true 
),

tbl_dsv_attr as (
	select 
		vf.table_view_id,
		jsonb_build_object(
			'name', "name",
			'alias', coalesce(alias, name)
		) as attr_json
	from 
		simi.simidata_view_field vf
	join
		simi.simidata_table_field tf on vf.table_field_id = tf.id 
),

tbl_dsv_attr_grouped as (
	select 	
		table_view_id,
		jsonb_agg(attr_json) as attr_json
	from 
		tbl_dsv_attr
	group by
		table_view_id
)

select
	jsonb_build_object(
		'name', identifier,
		'title', title,
		'postgis_datasource', tbl_json,
		'attributes', attr_json
	) as json_obj
from 
	tbl_dsv dsv
join
	pgtable_json tbl on dsv.postgres_table_id = tbl.table_id
join 
	tbl_dsv_attr_grouped attr on dsv.dsv_id = attr.table_view_id

