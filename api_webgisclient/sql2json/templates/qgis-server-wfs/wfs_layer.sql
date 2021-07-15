/*
Query zum Json-Export der als WFS zu publizierenden Klassen der GDI.
*/
WITH

pgtable_json AS ( -- Informationen aus simidata_postgres_table, ...
	SELECT 
		tbl.id AS table_id,
		jsonb_build_object(
			'dbconnection', db_service_url,
			'schema', schema_name,
			'table', table_name,
			'unique_key', id_field_name,
			'geometry_field', geo_field_name,
			'geometry_type', geo_type,
			'srid', geo_epsg_code
		) AS tbl_json
	FROM 
		simi.simidata_postgres_table tbl 
	JOIN 
		simi.simidata_data_theme dt ON tbl.data_theme_id = dt.id 
	JOIN 
		simi.simidata_postgres_db db ON dt.postgres_db_id = db.id 
	WHERE
		geo_field_name IS NOT NULL
),

tbl_dsv AS ( -- Tableview-Informationen der 1-n Tableviews pro Postgres-Table
	SELECT 
		dsv.id AS dsv_id,
		identifier,
		coalesce(title, identifier) AS title,
		postgres_table_id
	FROM 
		simi.simiproduct_data_product p
	JOIN
		simi.simidata_data_set_view dsv ON p.id = dsv.id 
	JOIN
		simi.simidata_table_view tv ON dsv.id = tv.id 
	WHERE 
		dsv.raw_download is true 
	--AND identifier not like 'test.%'
),

tbl_dsv_attr AS ( -- Informationen zu den Attributen einer Tableview
	SELECT 
		vf.table_view_id,
		jsonb_build_object(
			'name', "name",
			'alias', coalesce(alias, name)
		) AS attr_json
	FROM 
		simi.simidata_view_field vf
	JOIN
		simi.simidata_table_field tf ON vf.table_field_id = tf.id 
),

tbl_dsv_attr_grouped AS ( -- Attribut-Array einer Tableview
	SELECT 	
		table_view_id,
		jsonb_agg(attr_json) AS attr_json
	FROM 
		tbl_dsv_attr
	GROUP BY
		table_view_id
)

SELECT
	jsonb_build_object(
		'name', identifier,
		'title', title,
		'postgis_datasource', tbl_json,
		'attributes', attr_json
	) AS json_obj
FROM 
	tbl_dsv dsv
JOIN
	pgtable_json tbl ON dsv.postgres_table_id = tbl.table_id
JOIN 
	tbl_dsv_attr_grouped attr ON dsv.dsv_id = attr.table_view_id

