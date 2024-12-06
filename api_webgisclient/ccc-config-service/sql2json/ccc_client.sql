

/* 
 * Gibt die konfigurierten CCC-Clients mit den Rücksprung-Ebenen zurück
 * 
 * Das in der Spalte "notify_layers" enthaltene json-objekt wird mittels "||"-Operator
 * ergänzt mit den im Metamodell ausmodellierten Eigenschaften.
 * */
SELECT
  CAST(notify_layers AS jsonb) || jsonb_build_object(
    'id', "name",
    'title', "name",
    'map', dp.derived_identifier,
    'cccServer', '$$CCC_BASE_URL$$/ccc-service'
  ) AS client_json
FROM
  simi.simi.simiextended_dependency d
JOIN
  simi.simi.simiproduct_data_product dp ON d.map_id = dp.id
WHERE
    d.dtype = 'simiExtended_CCCIntegration'
  AND
    dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' 
