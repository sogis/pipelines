/*
Query zum Json-Export der als WFS zu publizierenden Klassen der GDI.
*/
WITH

tableview_tblinfo AS ( -- Informationen aus simidata_postgres_table, ...
	SELECT 
		tv.id AS tv_id,
        tbl.title AS tbl_title,
		jsonb_build_object(
			'dbconnection', concat('service=', db.db_service_url),
			'schema', schema_name,
			'table', COALESCE(tv.row_filter_view_name, tbl.table_name),
			'unique_key', id_field_name,
			'geometry_field', geo_field_name,
			'geometry_type', geo_type,
			'srid', geo_epsg_code
		) AS tbl_json
	FROM 
	   simi.simidata_table_view tv
	JOIN  
		simi.simidata_postgres_table tbl ON tv.postgres_table_id = tbl.id
	JOIN 
		simi.simidata_db_schema s ON tbl.db_schema_id  = s.id 
	JOIN 
		simi.simidata_postgres_db db ON s.postgres_db_id = db.id 
  WHERE
      geo_field_name IS NOT NULL
    AND
      geo_type IS NOT NULL
    AND
      geo_epsg_code IS NOT NULL	
),

tableview AS ( -- Tableview-Informationen
	SELECT 
		dsv.id AS tv_id,
		derived_identifier AS identifier,
		coalesce(p.title, tv_tbl.tbl_title, p.derived_identifier) AS title,
		tbl_json
	FROM
	   tableview_tblinfo tv_tbl
	JOIN  
		simi.simiproduct_data_product p ON tv_tbl.tv_id = p.id 
	JOIN
		simi.simidata_data_set_view dsv ON p.id = dsv.id 
	WHERE 
		dsv.service_download is true 
),

tableview_attr AS ( -- Informationen zu den Attributen einer Tableview
	SELECT 
		vf.table_view_id AS tv_id,
		jsonb_build_object(
			'name', "name",
			'alias', coalesce(alias, name)
		) AS attr_json
	FROM 
		simi.simidata_view_field vf
	JOIN
		simi.simidata_table_field tf ON vf.table_field_id = tf.id 
  WHERE 
    vf.wgc_exposed IS TRUE 
),

tableview_attr_grouped AS ( -- Attribut-Array einer Tableview
	SELECT 	
		tv_id,
		jsonb_agg(attr_json) AS attr_json
	FROM 
		tableview_attr
	GROUP BY
		tv_id
)

SELECT
	jsonb_build_object(
		'name', identifier,
		'title', title,
		'postgis_datasource', tbl_json,
		'attributes', attr_json
	) AS json_obj
FROM 
	tableview tv
JOIN 
	tableview_attr_grouped attr ON tv.tv_id = attr.tv_id
;

