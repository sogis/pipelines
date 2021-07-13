#!/bin/bash

path="$(pwd)/../sql2json.jar -c jdbc:postgresql://localhost:54324/simi -u postgres -p postgres -t $(pwd)/dataConfig_template.json -o $(pwd)/../outputs/dataConfig.json -s https://raw.githubusercontent.com/qwc-services/qwc-data-service/master/schemas/qwc-data-service.json"
echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path
