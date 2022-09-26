
WITH

foreground AS (
  SELECT 
    jsonb_build_object(
      'name', 'foreground',
      'filter_word', 'Karte',
      'default', TRUE 
    ) AS facet_json
  FROM
    generate_series(1,1)
),

background AS (
  SELECT 
    jsonb_build_object(
      'name', 'background',
      'filter_word', 'Hintergrundkarte',
      'default', FALSE  
    ) AS facet_json
  FROM
    generate_series(1,1)
),

dsv_raw AS (
  SELECT
    COALESCE(search_facet, derived_identifier) AS facet_ident,
    CASE 
      WHEN search_type = '2_if_loaded' THEN FALSE
      ELSE TRUE 
    END AS always_active,
    search_filter_word
  FROM 
    simi.simidata_table_view tv
  JOIN
    simi.simiproduct_data_product dp ON tv.id = dp.id
  WHERE
      dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' -- zum Löschen markierte
    AND 
      search_type IN ('2_if_loaded','3_always')
),

dsv AS (
  SELECT 
    jsonb_build_object(
      'name', facet_ident,
      'filter_word', search_filter_word,
      'default', always_active  
    ) AS facet_json
  FROM
    dsv_raw
)

SELECT facet_json FROM foreground
UNION ALL 
SELECT facet_json FROM background
UNION ALL 
SELECT facet_json FROM dsv
;