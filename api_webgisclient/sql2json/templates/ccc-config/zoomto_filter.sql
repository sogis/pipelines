/* 
 * Löst alle Json-Arrays in der Spalte "locator_layers" auf und gibt die einzelnen
 * Elemente der Arrays als Json-Objekte zurück.
 * 
 * Der Vollständigkeit halber werden Konfigurationen mit Bezug auf eine als "zu löschen" 
 * markierte Karte herausgefiltert (sind dann inaktiv)
 * */
SELECT
  jsonb_array_elements(CAST(locator_layers AS jsonb)) json_obj
FROM
  simi.simiextended_dependency d
JOIN
  simi.simi.simiproduct_data_product dp ON d.map_id = dp.id
WHERE
    d.dtype = 'simiExtended_CCCIntegration'
  AND
    dp.pub_scope_id != '55bdf0dd-d997-c537-f95b-7e641dc515df' 