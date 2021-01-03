-- add fields for OSM tags and data processing 
ALTER TABLE sonoma_county_building_outlines
	ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN conflated boolean DEFAULT FALSE,
	ADD COLUMN main boolean; -- is it the main building on the parcel?

-- create local geometry fields and validate geometries
UPDATE sonoma_county_building_outlines SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON sonoma_county_building_outlines USING GIST (loc_geom);

-- added fields for the parcels table
ALTER TABLE parcels__public_
    ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN building_count integer,
	ADD COLUMN repeating BOOLEAN DEFAULT FALSE;

-- create local geometry fields and validate geometries
UPDATE parcels__public_ SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON parcels__public_ USING GIST (loc_geom);

-- parse and expand parcel street addresses
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+)$', '\2')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+)'
    AND situsfmt1 NOT LIKE '%NONE' AND situsfmt1 NOT SIMILAR TO '([0-9]+) ([A-Z ]+) (AVE|DR|RD|ST|LN|CT|PL|CIR|TER|BLVD|PKWY|HWY)' AND situsfmt1 NOT SIMILAR TO '% ([^A-Z]+)';
-- select situsfmt1, "addr:housenumber", "addr:street" from parcels__public_ limit 100;
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]+) AVE$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) AVE$', '\2 Avenue')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) AVE';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) DR$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) DR$', '\2 Drive')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) DR';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) RD$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) RD$', '\2 Road')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) RD';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) ST$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) ST$', '\2 Street')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) ST';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) LN$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) LN$', '\2 Lane')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) LN';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) CT$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) CT$', '\2 Court')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) CT';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) PL$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) PL$', '\2 Place')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) PL';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) CIR$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) CIR$', '\2 Circle')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) CIR';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) TER$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) TER$', '\2 Terrace')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) TER';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) BLVD$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) BLVD$', '\2 Boulevard')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) BLVD';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) PKWY$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) PKWY$', '\2 Parkway')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) PKWY';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) HWY$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z ]+) HWY$', '\2 Highway')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z ]+) HWY';
-- select situsfmt1, "addr:housenumber", "addr:street" from parcels__public_ limit 100;
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)$', 'Highway \2')) where situsfmt1 SIMILAR TO '([0-9]+) HWY ([0-9]+)';
-- select situsfmt1, "addr:housenumber", "addr:street" from parcels__public_ where situsfmt1 SIMILAR TO '([0-9]+) HWY ([0-9]+)';


-- identify repeating parcels (indicates multiple addresses associated with buildings)
WITH geom_counts AS (
	SELECT array_agg(gid) AS ids, COUNT(*)
	FROM parcels__public_
	GROUP BY geom
), geom_counts2 AS (
	SELECT * FROM geom_counts WHERE count > 1
)
UPDATE parcels__public_ SET repeating = TRUE
FROM geom_counts2 
WHERE ids @> ARRAY[gid];

-- identify parcels with multiple buildings
UPDATE parcels__public_ SET building_count = NULL WHERE building_count IS NOT NULL;
WITH bcounts AS (
	SELECT 
		p.gid, COUNT(*)
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	GROUP BY p.gid
)
UPDATE parcels__public_ SET building_count = count
FROM bcounts WHERE bcounts.gid = parcels__public_.gid;

-- add addresses to buildings with simple 1:1 matches to parcels
UPDATE sonoma_county_building_outlines SET "addr:housenumber" = NULL, "addr:street" = NULL;
WITH a AS (
	SELECT 
		b.gid, p."addr:housenumber", p."addr:street"
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE p.building_count = 1 AND NOT p.repeating
)
UPDATE sonoma_county_building_outlines SET 
	"addr:housenumber" = a."addr:housenumber",
	"addr:street" = a."addr:street"
FROM a WHERE sonoma_county_building_outlines.gid = a.gid;

--SELECT COUNT(*) FROM sonoma_county_building_outlines WHERE "addr:housenumber" IS NOT NULL OR "addr:street" IS NOT NULL;

-- attempt to identify garages and sheds so they don't get addresses
UPDATE sonoma_county_building_outlines SET main = NULL;
-- sort the buildings on each parcel by size, but only where it's likely a garage/shed situation
WITH sizes AS (
	SELECT 
		p.gid AS pid, 
		b.gid AS bid,
		row_number() OVER ( PARTITION BY p.gid ORDER BY ST_Area(b.loc_geom) DESC) AS size_order
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE 
		NOT p.repeating AND -- single parcels
		p.building_count IN (2,3) -- 2 or 3 buildings on parcel
	ORDER BY p.gid ASC
) UPDATE sonoma_county_building_outlines SET main = CASE 
	WHEN size_order = 1 THEN TRUE
	WHEN size_order > 1 THEN FALSE
	ELSE NULL
END
FROM sizes WHERE sizes.bid = sonoma_county_building_outlines.gid;

-- now assign addresses to main buildings on parcels with outbuildings
WITH a AS (
	SELECT 
		b.gid, p."addr:housenumber", p."addr:street"
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE 
		p.building_count IN (2,3)
		AND NOT p.repeating 
		AND b.main -- is main building
)
UPDATE sonoma_county_building_outlines SET 
	"addr:housenumber" = a."addr:housenumber",
	"addr:street" = a."addr:street"
FROM a WHERE sonoma_county_building_outlines.gid = a.gid;

-- get a count of outbuildings so we know how many addresses are intentionally unassigned
SELECT 
	COUNT(*)
FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
	ST_Intersects(b.loc_geom,p.loc_geom) AND 
	ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
WHERE 
	p.building_count IN (2,3)
	AND NOT p.repeating 
	AND NOT b.main; -- is NOT main building

-- result: 44090

-- try to assign multiple addresses from multiple parcels to single buildings
WITH addresses AS (
	SELECT 
		b.gid,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:housenumber"), ';') AS housenumber,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:street"), ';') AS street
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON 
		ST_Intersects(b.loc_geom,p.loc_geom) AND
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE 
		p.building_count = 1 AND 
		p.repeating AND
		b."addr:housenumber" IS NULL
	GROUP BY b.gid
)
UPDATE sonoma_county_building_outlines AS b SET 
	"addr:housenumber" = housenumber,
	"addr:street" = street
FROM addresses AS a
WHERE a.gid = b.gid;

-------------------------------------------------------TODO

-- try to identify addresses for buildings across multiple parcels
WITH addresses AS (
	SELECT 
		b.gid,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:housenumber"), ';') AS addrno,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:street"), ';') AS street,
		COUNT(*)
	FROM sonoma_county_building_outlines AS b
	JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) < 0.9*ST_Area(b.loc_geom)
	WHERE 
		b."addr:housenumber" IS NULL AND
		NOT p.repeating AND
		p."addr:housenumber" IS NOT NULL AND
		b.shape__are > 1000 -- assuming sqft
	GROUP BY b.gid
)
UPDATE sonoma_county_building_outlines AS b SET 
	"addr:housenumber" = addrno,
	"addr:street" = street
FROM addresses AS a
WHERE 
	count = 1 AND -- only simple cases!
	a.gid = b.gid;

-- identify intersecting/conflated buildings
UPDATE sonoma_county_building_outlines AS b SET conflated = FALSE;
UPDATE sonoma_county_building_outlines AS b SET conflated = TRUE 
FROM son_polygon AS osm
	WHERE ST_Intersects(b.geom,osm.way)
	AND osm.building IS NOT NULL and osm.building != 'no';

-- dump simplified polygon geometries and OSM relavant fields into another table for exporting
-- this code is based on https://trac.osgeo.org/postgis/wiki/UsersWikiSimplifyPreserveTopology
-- it does take a very long time to run on this dataset...

-- first do conflated buildings
with poly as (
	SELECT
		gid,
		"addr:housenumber",
		"addr:street",
		est_h_feet,
		storyabove,
		storybelow,
		cwwuse,
		(st_dump(loc_geom)).* 
        FROM sonoma_county_building_outlines
        WHERE conflated
) 
SELECT 
	poly.gid,
	poly."addr:housenumber",
	poly."addr:street",
	poly.est_h_feet,
	poly.storyabove,
	poly.storybelow,
	poly.cwwuse,
	ST_Transform(baz.geom,4326) AS geom
INTO simplified_conflated_buildings
FROM ( 
        SELECT (ST_Dump(ST_Polygonize(distinct geom))).geom as geom
        FROM (
		-- simplify geometries to a 0.2m tolerance to avoid repeated points
                SELECT (ST_Dump(st_simplifyPreserveTopology(ST_Linemerge(st_union(geom)), 0.2))).geom as geom
                FROM (
                        SELECT ST_ExteriorRing((ST_DumpRings(geom)).geom) as geom
                        FROM poly
                ) AS foo
        ) AS bar
) AS baz, poly
WHERE 
	ST_Intersects(poly.geom, baz.geom)
	AND ST_Area(st_intersection(poly.geom, baz.geom))/ST_Area(baz.geom) > 0.9;
ALTER TABLE simplified_conflated_buildings ADD CONSTRAINT temp1_pkey PRIMARY KEY (gid);

-- next do non-conflated buldings separately
with poly as (
	SELECT
		gid,
		"addr:housenumber",
		"addr:street",
		est_h_feet,
		storyabove,
		storybelow,
		cwwuse,
		(st_dump(loc_geom)).* 
        FROM sonoma_county_building_outlines
        WHERE NOT conflated -- note: NOT
) 
SELECT 
	poly.gid,
	poly."addr:housenumber",
	poly."addr:street",
	poly.est_h_feet,
	poly.storyabove,
	poly.storybelow,
	poly.cwwuse,
	ST_Transform(baz.geom,4326) AS geom
INTO simplified_buildings
FROM ( 
        SELECT (ST_Dump(ST_Polygonize(distinct geom))).geom as geom
        FROM (
		-- simplify geometries to a 0.2m tolerance to avoid repeated points
                SELECT (ST_Dump(st_simplifyPreserveTopology(ST_Linemerge(st_union(geom)), 0.2))).geom as geom
                FROM (
                        SELECT ST_ExteriorRing((ST_DumpRings(geom)).geom) as geom
                        FROM poly
                ) AS foo
        ) AS bar
) AS baz, poly
WHERE 
	ST_Intersects(poly.geom, baz.geom)
	AND ST_Area(st_intersection(poly.geom, baz.geom))/ST_Area(baz.geom) > 0.9;
