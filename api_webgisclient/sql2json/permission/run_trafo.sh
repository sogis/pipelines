#!/bin/bash

path="$(pwd)/../sql2json.jar -c jdbc:postgresql://localhost/simi -u postgres -p postgres -t $(pwd)/template.json -o $(pwd)/../permission.json -s https://github.com/qwc-services/qwc-services-core/raw/master/schemas/qwc-services-unified-permissions.json"
#echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path
