# Sonoma County Building/Parcel/Address Import

Based on https://github.com/Nate-Wessel/hamilton-import

## Project Status

For current project status see https://wiki.openstreetmap.org/wiki/Sonoma_County_Building_and_Address_Import

### Screenshots

Here is the project status as of Jan 13 2021.

- 106,930 new buildings would be inserted with addresses (green) (non-conflated, with addresses)
- 139,987 new buildings would be inserted without addresses (non-conflated, no address)
- 18,867 buildings already exist with addresses and would not be inserted
- 13,226 buildings already exist without addresses and would not be inserted

![Legend](/img/legend.png "Legend")
![Sonoma County Overview](/img/sonoma_county.png "Sonoma County Overview")
![Santa Rosa](/img/santa_rosa.png "Santa Rosa")
![Sonoma City](/img/sonoma.png "Sonoma City")
![Petaluma](/img/petaluma.png "Petaluma")

## Obtaining Data

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

- The postgresql server started/running/configured and database `openstreetmap` created, generally at localhost port 5432.

- Osmosis, for export

## Running

- First, prepare Postgres for an OSM schema that'll be used for the output data, by running this SQL in your desired database: https://github.com/openstreetmap/osmosis/blob/master/package/script/pgsnapshot_schema_0.6.sql
- Run the following SQL as a superuser (postgres) inside the `openstreetmap` database to enable the PostGIS and hstore extensions: `CREATE EXTENSION postgis; CREATE EXTENSION hstore;`
- Unzip the `original_data` and open a shell in that folder.
- Here we are assuming that the county data uses a WGS84 aka EPSG:4326 geographical projection, which was true as of last check and is also what OSM uses.
- Run from your shell: `shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d openstreetmap -U postgres -W`
- `shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d openstreetmap -U postgres -W`
- `shp2pgsql -s 4326 -I osm-buildings-01-03.shp | psql -d openstreetmap -U postgres -W`

Now all the data is in Postgres. For processing and conflation, read through and execute `conflation.sql` as per your comfort level.

## Exporting and uploading

TODO, Osmium

## Import and validation

Using HOT Tasking Manager:

Please ensure you are logged in under a dedicated import account with a user name ending in `_sonomaimport`. If you haven’t contributed to a building import project before, please choose a task in one of the more sparsely populated parts of the county.

- Open JOSM and enable remote control.
- Click "Start Editor" to load the overall task area in JOSM. (You can use iD to validate a task, but *do not* use it to complete a task. Ask a project coordinator if you need help with JOSM.)
- Click the Tasking Manager link under "Specific Task Information" to load the import task’s data, which contains imported buildings from Sonoma County.
- Enable your aerial imagery of choice in JOSM, and offset it ("Imagery"→"New offset") to match the Sonoma County data.
- Spot-check the added building ways’ geometries:
  - If the actual building has been demolished, delete the way, or replace the building=* tag with a demolished:building=* tag to prevent it from being recreated based on outdated imagery.
  - If the actual building has a new addition, and neither the CAGIS data nor OSM include that addition, extend the way to include the new addition.
  - Do not draw your own buildings from scratch as part of this project. If a building within your task area is visible in aerial imagery but isn’t in either the CAGIS data or OSM, you don’t have to add the building right now, because we plan to conflate with a newer CAGIS dataset in a later phase of the import.
  - If many buildings are missing, such as in a newly built subdivision, add a note so we can revisit it later.
- Spot-check the added ways’ addresses:
  - If the street name in the address doesn’t match the name of a nearby roadway, note the street name in the task comments (not the changeset comments) for further review.
- Run the JOSM validator. Ignore any warnings about landuse areas. Focus on the following warnings and errors that may be related to the buildings you have added:
  - Crossing buildings
  - Self-intersecting ways
  - Building inside building
  - Duplicate housenumber
  - Housenumber without street
- TODO: Merge the imported buildings layer into the OSM Data layer by right-clicking on the layer.
- TODO: Run the JOSM validator again.
- TODO: Resolve duplicate buildings/addresses with utilsplugin2 and the Replace Geometry command, OR the conflate plugin.
  - To use the utilsplugin, select the worse building, hold shift, and select the better building. Then press ctrl+shift+G or More Tools > Replace Geometry.
  - To use the conflate plugin, Configure it, select Reference (imported) geometry by going to Edit > Search and searching for all `building=* type:way new` data. Click Reference: Freeze. Then, select Subject (original) geometry by going to Edit > Search and searching for all `building=* type:way -new` geometry. Click Subject: Freeze. Finally, you probably want to use Simple, Disambiguiating, Standard < 2, Replace Geometry, Merge Tags.
- TODO: Run the JOSM validator again until all the building-related changes seem fine. Don't bother yourself with issues unrelated to the building/address import.
- Upload the data with the following information:
  - Comment: `Imported addresses and building footprints from Sonoma County #sonomaimport`
  - Source: `Sonoma County`
- Mark the task as complete.


### Internal Notes
- http://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf

```
shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432
shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432
psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432 -f osmquery-pgdump.sql

#unused
osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong sonoma-orig-buildings-20201219.osm -U postgres -W`
osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong norcal-latest-20200103.osm.pbf -U openstreetmap -W -H localhost -P 5432
```

```
sonoma_county_building_outlines
"conflated" = FALSE

osmosis --read-pgsql host="127.0.0.1" database="openstreetmap" user="openstreetmap" password="openstreetmap" outPipe.0=pg --dd inPipe.0=pg outPipe.0=dd --write-xml inPipe.0=dd file=output.osm


# Must be port 5432
osmosis --read-pgsql host="127.0.0.1" database="openstreetmap" user="openstreetmap" password="openstreetmap" --dd inPipe.0=pg outPipe.0=dd --write-xml file=output.osm


https://wiki.openstreetmap.org/wiki/Osmosis/Detailed_Usage_0.43#--read-pgsql_.28--rp.29
```


schema_info
