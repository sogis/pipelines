#!/bin/bash

path="$(pwd)/../.gitignored/sql2json.jar -c jdbc:postgresql://localhost/simi -u postgres -p postgres -t $(pwd)/template.json -o $(pwd)/../.gitignored/qgs_wms.json -s https://github.com/simi-so/json2qgs/raw/master/schemas/sogis-wms-qgs-content.json"
#echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path