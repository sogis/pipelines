# Create views in Simi DB

Replace *dbhost* with the DB hostname and *adminrole* with the name of the admin role used in the AGI

## Update all views with one command

The automatic migration scripts from SIMI drop the views if source tables (entities) where changed.

Use the following command to drop and recreate all views from source (After git repo pull):

```bash
psql -d simi -h host -U user \
  --single-transaction \
  -c 'set role adminrole;' \
\
  -f trafo/drop_trafo_views.sql \
  -f solr/drop_solr_views.sql \
\
  -f trafo/trafo_published_dp_v.sql \
  -f trafo/trafo_wms_geotable_v.sql \
  -f trafo/trafo_wms_tableview_v.sql \
  -f trafo/trafo_tableview_attr_with_geo_v.sql \
  -f trafo/trafo_wms_layer_v.sql \
  -f trafo/trafo_wms_rootlayer_v.sql \
\
  -f solr/solr_layer_base_v.sql \
  -f solr/solr_layer_background_v.sql \
  -f solr/solr_layer_foreground_v.sql \
\
  -f trafo/grant_trafo_views.sql \
  -f solr/grant_solr_views.sql
```



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
