DROP VIEW IF EXISTS simi.trafo_wms_outtypes_v;

CREATE VIEW simi.trafo_wms_outtypes_v AS

/*
 * Definiert die gegenwärtig für QGIS Server WMS aktiven Ebenen 
 */
SELECT 
  otype 
FROM (
  VALUES 
    ('tableview.DB Pub'), 
    ('facadelayer'), 
    ('layergroup')
) 
AS t (otype)
;