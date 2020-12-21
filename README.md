# Sonoma County Building/Parcel/Address Import

Based on https://github.com/Nate-Wessel/hamilton-import

`original_data` from:
- https://gis-sonomacounty.hub.arcgis.com/datasets/2202c1cd6708441f987ca5552f2d9659
- https://gis-sonomacounty.hub.arcgis.com/datasets/0f5982c3582d4de0b811e68d7f0bff8f
- https://overpass-turbo.eu/

Overpass query:

```
area[name="Sonoma County"];
way[building](area);
/*added by auto repair*/
(._;>;);
/*end of auto repair*/
out;
```

## Prerequisites

The postgis package appropriate for the version of postgres server you have installed (in my case, 11)

Ubuntu
- sudo apt install shp2pgsql osm2pgsql
- sudo apt install postgresql-11 postgresql-11-postgis-3
- The postgresql server started/running/configured and databases `gis` and `osm` created

## Running

- Run the following SQL inside the `gis` database to enable the PostGIS and hstore extensions: `CREATE EXTENSION postgis; CREATE EXTENSION hstore;`
- Unzip the `original_data` and open a shell in that folder.
- Then, run from your shell: `shp2pgsql -s 3735:4326 -g geom -I Parcels__Public_.shp | psql -d gis -U postgres -W`
- `shp2pgsql -s 3735:4326 -g geom -I Sonoma_County_Building_Outlines.shp | psql -d gis -U postgres -W`
- `osm2pgsql -d gis -c --prefix son --slim --extra-attributes --hstore --latlong sonoma-orig-buildings-20201219.osm -U postgres -W`

Now all the data is in Postgres. For processing and conflation, read through and execute `conflation.sql` as per your comfort level.
