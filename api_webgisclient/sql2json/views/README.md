# Create views in Simi DB

Replace *dbhost* with the DB hostname and *adminrole* with the name of the admin role used in the AGI

**Trafo Views** 

```
git clone git@github.com:/sogis/pipelines
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_published_dp_v.sql simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_wms_geotable_v.sql simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_wms_tableview_v.sql simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_tableview_attr_with_geo_v.sql simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_wms_layer_v.sql  simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/trafo/trafo_wms_rootlayer_v.sql simi
```

**Solr Views**

```
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/solr/solr_layer_base_v.sql simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/solr/solr_layer_background_v.sql  simi
psql -h dbhost -c 'set role adminrole;' -f sql2json/views/solr/solr_layer_foreground_v.sql  simi
```
