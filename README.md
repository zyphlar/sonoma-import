# Sonoma County Building/Parcel/Address Import

Based on https://github.com/Nate-Wessel/hamilton-import

`original_data` from:
- https://gis-sonomacounty.hub.arcgis.com/datasets/2202c1cd6708441f987ca5552f2d9659
- https://gis-sonomacounty.hub.arcgis.com/datasets/0f5982c3582d4de0b811e68d7f0bff8f
- https://overpass-turbo.eu/

Overpass query (you may save as OSM file, shapefile, or postgres sql dump depending on your overpass client)

```
area[name="Sonoma County"];
(
  way[building](area);
  relation[building](area);
);
(._;>;);
out;
```

If using an Overpass -> QGIS -> Postgres dump, save it as `osmquery_buildings_pgdump.sql` for later.
Otherwise osm2pgsql should create tables like `son_polygon` for later.

## Prerequisites

The postgis package appropriate for the version of postgres server you have installed (in my case, 11)

Ubuntu
- sudo apt install postgresql-11 postgresql-11-postgis-3 shp2pgsql osm2pgsql

Debian (shp2pgsql is included in postgis)
- sudo apt install postgresql postgis osm2pgsql

- The postgresql server started/running/configured and database `gis` created

## Running

- Run the following SQL as a superuser (postgres) inside the `gis` database to enable the PostGIS and hstore extensions: `CREATE EXTENSION postgis; CREATE EXTENSION hstore;`
- Unzip the `original_data` and open a shell in that folder.
- Here we are assuming that county data is in WGS84/EPSG4236 format, which was true as of last check and is also what OSM uses.
- Run from your shell: `shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d gis -U postgres -W`
- `shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d gis -U postgres -W`
- `shp2pgsql -s 4326 -I osm-buildings-01-03.shp | psql -d gis -U postgres -W`

Now all the data is in Postgres. For processing and conflation, read through and execute `conflation.sql` as per your comfort level.


### Internal Notes
- http://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf

```
shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 54321
shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 54321
psql -d openstreetmap -U openstreetmap -W -h localhost -p 54321 -f osmquery-pgdump.sql

#unused
osm2pgsql -d gis -c --prefix son --slim --extra-attributes --hstore --latlong sonoma-orig-buildings-20201219.osm -U postgres -W`
osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong norcal-latest-20200103.osm.pbf -U openstreetmap -W -H localhost -P 54321
```