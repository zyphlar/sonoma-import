# Sonoma County Building/Parcel/Address Import

Based on https://github.com/Nate-Wessel/hamilton-import

## Project Status

For current project status see https://wiki.openstreetmap.org/wiki/Sonoma_County_Building_and_Address_Import

### Screenshots

Here is the project status as of April 27 2021.

- 80,341 new buildings would be inserted with addresses (green) (non-conflated, with addresses)
  - This generally excludes the city of Santa Rosa as those addresses were previously imported as POIs with better accuracy and can be conflated at a later date
- 166,088 new buildings would be inserted without addresses (non-conflated, no address)
  - Some of these we "have" addresses for, but have nulled so as not to conflict with Santa Rosa address POIs
- 32,581 buildings already exist and would not be inserted

Here are sample screenshots of Santa Rosa, the City of Sonoma, Petaluma, Sebastopol, and Healdsburg. Note the relative lack of conflated addresses in Santa Rosa due to the aforementioned POI import.

<img src="/img/legend.png" title="Legend"/>
<img src="/img/santa_rosa.png" title="Santa Rosa" width="15%" style="border:1px solid #ccc; margin: 1em;" align="left" />
<img src="/img/sonoma.png" title="City of Sonoma" width="15%" style="border:1px solid #ccc; margin: 1em;" align="left" />
<img src="/img/petaluma.png" title="Petaluma" width="15%" style="border:1px solid #ccc; margin: 1em;" align="left" />
<img src="/img/sebastopol.png" title="Sebastopol" width="15%" style="border:1px solid #ccc; margin: 1em;" align="left" />
<img src="/img/healdsburg.png" title="Healdsburg" width="15%" style="border:1px solid #ccc; margin: 1em;" align="left" />

<br clear="left"/>

## Obtaining Data

`original_data` from:
- https://gis-sonomacounty.hub.arcgis.com/datasets/2202c1cd6708441f987ca5552f2d9659
- https://gis-sonomacounty.hub.arcgis.com/datasets/0f5982c3582d4de0b811e68d7f0bff8f
- http://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf
- VTATaz (included in git, original_data): https://drive.google.com/file/d/0B098fXDVjQOhVHBFS0kwcDNGRlU/view

Script:
```
cd original_data
wget https://opendata.arcgis.com/datasets/2202c1cd6708441f987ca5552f2d9659_0.zip
unzip 2202c1cd6708441f987ca5552f2d9659_0.zip
rm 2202c1cd6708441f987ca5552f2d9659_0.zip

wget https://opendata.arcgis.com/datasets/0f5982c3582d4de0b811e68d7f0bff8f_0.zip
unzip 0f5982c3582d4de0b811e68d7f0bff8f_0.zip
rm 0f5982c3582d4de0b811e68d7f0bff8f_0.zip

wget http://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf
```

## Prerequisites

The postgis package appropriate for the version of postgres server you have installed (in my case, 11)

Ubuntu
- sudo apt install postgresql-11 postgresql-11-postgis-3 shp2pgsql osm2pgsql

Debian (shp2pgsql is included in postgis)
- sudo apt install postgresql postgis osm2pgsql

- The postgresql server started/running/configured and database `openstreetmap` created, generally at localhost port 5432.

- For export: sudo apt-get install -y gdal-bin python-lxml python3-gdal
  - ogr2osm https://github.com/pnorman/ogr2osm
    - `cd ~`
    - `git clone --recursive https://github.com/pnorman/ogr2osm`
  - Do NOT install the osgeo package from pip, it's empty and will cause ogr import errors.

## Running

- We are assuming that the county data uses a WGS84 aka EPSG:4326 geographical projection, which was true as of last check and is also what OSM uses.
- Run from your shell: `shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d openstreetmap -U openstreetmap -W`
- `shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d openstreetmap -U openstreetmap -W`
- `osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong norcal-latest.osm.pbf -U openstreetmap -W -H localhost -P 5432`

osm2pgsql should create tables like `son_polygon` for later.

Now all the data is in Postgres. For processing and conflation, read through and execute `conflation.sql` as per your comfort level.

## Exporting and uploading

Run `./trial.sh` which should handle conflation and tasking, with output in the `raw/main/out` folder.

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

- TODO:
  - Spot check buildings without addresses
  - Double check if geometry is adequately simplified or not
  - Figure out how to handle the newly-imported Santa Rosa address POIs

- http://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf

```
shp2pgsql -s 4326 -I Parcels__Public_.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432
shp2pgsql -s 4326 -I Sonoma_County_Building_Outlines.shp | psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432
psql -d openstreetmap -U openstreetmap -W -h localhost -p 5432 -f osmquery-pgdump.sql

#unused
shp2pgsql -s 4326 -I osm-buildings-01-03.shp | psql -d openstreetmap -U openstreetmap -W
osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong sonoma-orig-buildings-20201219.osm -U postgres -W`
osm2pgsql -d openstreetmap -c --prefix son --slim --extra-attributes --hstore --latlong norcal-latest.osm.pbf -U openstreetmap -W -H localhost -P 5432
```

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

```
sonoma_county_building_outlines
"conflated" = FALSE

osmosis --read-pgsql host="127.0.0.1" database="openstreetmap" user="openstreetmap" password="openstreetmap" outPipe.0=pg --dd inPipe.0=pg outPipe.0=dd --write-xml inPipe.0=dd file=output.osm


# Must be port 5432
osmosis --read-pgsql host="127.0.0.1" database="openstreetmap" user="openstreetmap" password="openstreetmap" --dd inPipe.0=pg outPipe.0=dd --write-xml file=output.osm


https://wiki.openstreetmap.org/wiki/Osmosis/Detailed_Usage_0.43#--read-pgsql_.28--rp.29
```


schema_info
