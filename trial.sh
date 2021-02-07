# Before running, download VTA TAZ data from Google Drive here:
# https://drive.google.com/file/d/0B098fXDVjQOhVHBFS0kwcDNGRlU/view
# and place into a folder named "data"
# (might need to rename VTATaz.dbf)

export DBNAME=openstreetmap
export OGR2OSM=../ogr2osm/ogr2osm.py
export PGUSER=openstreetmap
export PGPASSWORD=openstreetmap
export PGHOST=localhost
export PGPORT=5432

# DB setup
psql --echo-all --command="create extension if not exists hstore;" "${DBNAME}" -h $PGHOST -U $PGUSER
psql --echo-all --command="create extension if not exists postgis;" "${DBNAME}" -h $PGHOST -U $PGUSER

# Add ESRI:103240 to PostGIS for TAZ
# from https://github.com/Esri/projection-engine-db-doc/
psql --echo-all --file="103240.sql" "${DBNAME}" -h $PGHOST -U $PGUSER

echo "Importing TAZ"
shp2pgsql -d -D -s 103240 -I "original_data/VTATaz/VTATaz" | psql -d "${DBNAME}" -h $PGHOST -U $PGUSER >/dev/null

# Conflate addresses to buildings
psql -v "ON_ERROR_STOP=true" --echo-queries --file="conflation.sql" "${DBNAME}" -h $PGHOST -U $PGUSER



# Split into tasks
mkdir "out"
mkdir "out/intersecting"
mkdir "out/clean"

for intersects in false true; do
    if ${intersects}; then
        outdir="intersecting"
        intersectsQuery="conflated"
    else
        outdir="clean"
        intersectsQuery="not conflated"
    fi

    # The purpose of the out/*/buildings*.osm files is to publicly host, split, ready for tasking
    # https://codeforsanjose.github.io/OSM-SouthBay/SJ_Buildings/out/clean/buildings_1323.osm

    ogr2ogr -sql "select 'https://github.com/zyphlar/sonoma-import/raw/main/out/${outdir}/buildings_' || key || '.osm' as import_url, ST_SimplifyPreserveTopology(geom, 4) from VTATaz" \
        -t_srs EPSG:4326 \
        "out/grouped_${outdir}_buildings_zones.geojson" \
        "PG:dbname=${DBNAME} host=${PGHOST} user=${PGUSER} password=${PGPASSWORD}"
    sed -i 's/ //g' "out/grouped_${outdir}_buildings_zones.geojson"

    # TAZ IDs from 965 to 1050 are Sonoma County broken up unto convenient polygons
    for cid in {965..1050}; do
        # Skip empty TAZs
        if [ $(psql --command="copy (select count(*) from VTATaz where key=${cid}) to stdout csv" ${DBNAME} -h $PGHOST -U $PGUSER) = 0 ]; then
            continue
        fi

        output="out/${outdir}/buildings_${cid}.osm"


        # Filter export data to each CID
        for layer in "sonoma_county_building_outlines"; do
            psql -h $PGHOST -U $PGUSER -v "ON_ERROR_STOP=true" --echo-queries --command="create or replace view \"${layer}_filtered\" as select * from \"${layer}\" where ${intersectsQuery};" "${DBNAME}"
        done

        # Export to OSM
        python3 "${OGR2OSM}" "PG:dbname=${DBNAME} host=${PGHOST} user=${PGUSER} password=${PGPASSWORD}" -f -t trial.py --no-memory-copy -o "${output}"

        # Add sample region outline
        #sed -i '3i<bounds minlat="37.2440898883458" minlon="-121.875007225253" maxlat="37.25775329679" maxlon="-121.855829662555" />' "${output}"
    done
done
