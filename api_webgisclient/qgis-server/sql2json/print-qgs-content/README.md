# Druckvorlage

## Anleitung Nachführung:
* zip-File (A4-quer.zip / A4-hoch.zip / A3-quer.zip / A3-hoch.zip) herunterladen, entzipen und mit QGIS 2.18 bearbeiten
* Inhalt der neuen qpt-Files pro Format in Base64 Format encodieren: https://www.base64encode.org/ 
* Encodiertes Resultat kopieren und im File [template.json](https://github.com/sogis/pipelines/blob/master/api_webgisclient/sql2json/templates/print-qgs-content/template.json) in der Zeile `template_base64` mit dem bestehenden Inhalt ersetzen. Pro Format gibt es eine `template_base64`-Zeile.
* Folgende Pipeline starten: 
  
  Parameter stehen im File https://github.com/sogis/pipelines/blob/master/api_webgisclient/requirements.txt:
  * qgis-server
  * qgis-serve-featureinfo
  * qgis-server-print
* Kontrolle der Änderung im Web GIS Client

**!! ACHTUNG !!**

Eine Änderung der Files wirkt sich imme auf allen 3 Umgebungen aus (Test/Int/Prod) !!
