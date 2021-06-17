#!/bin/bash

path="$(pwd)/../.gitignored/sql2json.jar -c jdbc:postgresql://localhost/simi -u postgres -p postgres -t $(pwd)/template.json -o $(pwd)/../.gitignored/permission.json -s https://github.com/qwc-services/qwc-services-core/raw/master/schemas/qwc-services-unified-permissions.json"
#echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path
