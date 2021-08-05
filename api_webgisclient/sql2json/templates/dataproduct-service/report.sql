SELECT
  jsonb_build_object(
    'template', "name",
    'report_filename', concat("name", '/master')
  ) AS obj
FROM
  simi.simiextended_dependency 
WHERE
  dtype = 'simiExtended_Report'