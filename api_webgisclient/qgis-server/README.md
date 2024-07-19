Beispiel: Auswertung somap.json
* https://jenkins-agi-apps-production.apps.ocp.so.ch/job/gdi/job/qgis-server/ öffnen
* `Build` öffnen
* `Build Artifacts` öffnen
* `config` öffnen
* `default` öffnen
* `somap.json` öffnen
* somap.json wird geöffnet. Auf Reiter `Rohdaten` wechseln
* ganzer Text auswählen und in https://jsonbeautifier.org/ einfügen
* `Beautify` auswählen. Json-Text wird Lesbar (schön) dargestellt.
  ```
  {"$schema":"https://github.com/simi-so/json2qgs/raw/master/schemas/sogis-wms-qgs-content.json","wms_top_layers":["ch.so.ada.archaeologie.fundstellen","ch.so.ada.archaeologie.fundstellen_geschuetzt","ch.so.ada.denkmalschutz","ch.so.ada.denkmalschutz.edit.denkmal","ch.so.ada.denkmalschutz_geschuetzt","ch.so.afu.abbaustellen","ch.so.afu.abwasser","ch.so.afu.abwasser_lw","ch.so.afu.altlasten.standorte","ch.so.afu.altlasten.standorte.data_v2","ch.so.afu.altlasten.standorte_geschuetzt","ch.so.afu.baugk.geschaefte","ch.so.afu.baugrundklassen","ch.so.afu.bodeninformation.bodentypen_geschuetzt","ch.so.afu.bodeninformationen.bodenprofilstandorte","ch.so.afu.bodeninformationen.bodentypen","ch.so.afu.bodeninformation_landwirtschaft","ch.so.afu.bodeninformation_wald","ch.so.afu.bodeninformation.wasserhaushalt_geschuetzt","ch.so.afu.ekat2005","ch.so.afu.ekat2010","ch.so.afu.ekat2015","ch.so.afu.emme.hochwasserschutz","ch.so.afu.erdwaerme.erdsonden_private_quellen","ch.so.afu.erdwaerme.sonde","ch.so.afu.erdwaerme.uplus.anlage_v2","ch.so.afu.erdwaerme.uplus.bohrung_v2","ch.so.afu.erdwaerme.uplus.laufende_Bohrarbeiten","ch.so.afu.erdwaerme.uplus.nadelstich_tiefenlayer","ch.so.afu.erdwaerme.uplus.nadelstich_tiefenlayer
  ```
```
  {
  "$schema": "https://github.com/simi-so/json2qgs/raw/master/schemas/sogis-wms-qgs-content.json",
  "wms_top_layers": [
    "ch.so.ada.archaeologie.fundstellen",
    "ch.so.ada.archaeologie.fundstellen_geschuetzt",
    "ch.so.ada.denkmalschutz",
    "ch.so.ada.denkmalschutz.edit.denkmal",
    ...

    {
      "name": "ch.so.arp.nutzungsplanung",
      "type": "productset",
      "title": "Nutzungsplanung",
      "sublayers": [
        "ch.so.arp.nutzungsplanung.erschliessungsplanung.baulinien.2",
        "ch.astra.baulinien-nationalstrassen_v2_0.oereb.2",
        "ch.so.arp.nutzungsplanung.erschliessungsplanung",
        "ch.so.arp.nutzungsplanung.sondernutzungsplaene",
        "ch.so.arp.nutzungsplanung.ortsbildschutz",
        "ch.so.arp.nutzungsplanung.natur_landschaft_gruppe",
        "ch.so.arp.nutzungsplanung.weitere",
        "ch.so.arp.nutzungsplanung.gewaesser",
        "ch.so.arp.nutzungsplanung.grundwasserschutz",
        "ch.so.arp.nutzungsplanung.wald",
        "ch.so.arp.nutzungsplanung.grundnutzung"
      ]
    },
```
