#!/bin/bash

path="\
  $(pwd)/../../../.gitignored/pipe_bin/sql2json/sql2json.jar \
  -c jdbc:postgresql://localhost:5433/simi \
  -u postgres -p postgres \
  -t $(pwd)/template.json \
  -o $(pwd)/../../../.gitignored/pipe_data/legend/legendConfig.json \
  -s https://github.com/qwc-services/qwc-legend-service/raw/master/schemas/qwc-legend-service.json \
  "
#echo $path

java -Dorg.slf4j.simpleLogger.defaultLogLevel=info -jar $path