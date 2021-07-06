#!/bin/bash

path="$(pwd)/../.gitignored/sql2json.jar -c jdbc:postgresql://localhost:5433/simi -u postgres -p postgres -t $(pwd)/template.json -o $(pwd)/../.gitignored/ogc_service.json -s https://github.com/qwc-services/qwc-ogc-service/raw/master/schemas/qwc-ogc-service.json"
#echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path