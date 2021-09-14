SELECT
  jsonb_build_object(
    'template', split_part("name", '.', 1),
    'report_filename', concat(split_part("name", '.', 1), '/master')
  ) AS obj
FROM
  simi.simiextended_dependency 
WHERE
  dtype = 'simiExtended_Report'