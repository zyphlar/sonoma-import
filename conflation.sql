-- TODO: 
-- - parse `usecode` or `usecdesc` for parcel type (residential / school / biz / etc)
-- - parse city and state as well for mailing

-- add fields for OSM tags and data processing 
ALTER TABLE sonoma_county_building_outlines
	ADD COLUMN IF NOT EXISTS "addr:housenumber" text,
	ADD COLUMN IF NOT EXISTS "addr:street" text,
	ADD COLUMN IF NOT EXISTS "addr:unit" text,
	ADD COLUMN IF NOT EXISTS "addr:city" text,
	ADD COLUMN IF NOT EXISTS "addr:state" text,
	ADD COLUMN IF NOT EXISTS usecode integer,
	ADD COLUMN IF NOT EXISTS loc_geom geometry(multipolygon,4326),
	ADD COLUMN IF NOT EXISTS conflated boolean DEFAULT FALSE,
	ADD COLUMN IF NOT EXISTS main boolean; -- is it the main building on the parcel?

update sonoma_county_building_outlines set "addr:housenumber" = NULL, "addr:street" = NULL, "addr:unit" = NULL, "addr:city" = NULL, "addr:state" = NULL;

-- create local geometry fields and validate geometries
--UPDATE sonoma_county_building_outlines SET loc_geom = ST_MakeValid(geom);
--CREATE INDEX ON sonoma_county_building_outlines USING GIST (loc_geom);

-- added fields for the parcels table
ALTER TABLE parcels__public_
    ADD COLUMN IF NOT EXISTS "addr:housenumber" text,
	ADD COLUMN IF NOT EXISTS "addr:street" text,
	ADD COLUMN IF NOT EXISTS "addr:unit" text,
	ADD COLUMN IF NOT EXISTS "addr:city" text,
	ADD COLUMN IF NOT EXISTS "addr:state" text,
	ADD COLUMN IF NOT EXISTS loc_geom geometry(multipolygon,4326),
	ADD COLUMN IF NOT EXISTS building_count integer,
	ADD COLUMN IF NOT EXISTS repeating BOOLEAN DEFAULT FALSE;

update parcels__public_ set "addr:housenumber" = NULL, "addr:street" = NULL, "addr:unit" = NULL, "addr:city" = NULL, "addr:state" = NULL;

-- create local geometry fields and validate geometries
--UPDATE parcels__public_ SET loc_geom = ST_MakeValid(geom);
--CREATE INDEX ON parcels__public_ USING GIST (loc_geom);

-- parse and expand parcel street addresses
-- TODO: find/handle oddballs like 123A Main St and 123 Main St #4
-- SELECT situsfmt1, "addr:housenumber", "addr:street"
-- FROM public.parcels__public_
-- where "addr:housenumber" is null
-- and situsfmt1 NOT SIMILAR TO '([0-9]+)[A-Z]* [A-Z ]*([0-9]*[A-Z\- ]+)'
-- and situsfmt1 NOT SIMILAR TO '%NONE'
-- and situsfmt1 NOT SIMILAR TO '%#%'
-- and situsfmt1 SIMILAR TO '([0-9]+)% %'
-- ORDER BY gid ASC;

--
-- functions for address parsing
--

create or replace function expand_road(n varchar) RETURNS varchar as $$
DECLARE
  r varchar;
BEGIN
    SELECT INTO r
	CASE upper(n)
		WHEN	'ACRD' THEN 'Access Road'
		WHEN	'AL' THEN 'Alley'
		WHEN    'ALY' THEN 'Alley'
		WHEN    'ARC' THEN 'Arcade'
		WHEN	'AV' THEN 'Avenue'
		WHEN    'AVE' THEN 'Avenue'
		WHEN    'BLF' THEN 'Bluff'
		WHEN    'BLV' THEN 'Boulevard'
		WHEN    'BLVD' THEN 'Boulevard'
		WHEN    'BR' THEN 'Bridge'
		WHEN    'BRG' THEN 'Bridge'
		WHEN    'BYP' THEN 'Bypass'
		WHEN	'CDS' THEN 'Cul-de-sac'
		WHEN    'CIR' THEN 'Circle'
		WHEN	'CMNS' THEN 'Commons'
        WHEN    'CNTR' THEN 'Center'
		WHEN	'CONC' THEN 'Concession'
		WHEN    'CRES' THEN 'Crescent'
		WHEN	'CRST' THEN 'Crest'
		WHEN    'CSWY' THEN 'Crossway'
		WHEN    'CT' THEN 'Court'
		WHEN    'CTR' THEN 'Center'
		WHEN    'CV' THEN 'Cove'
		WHEN    'DR' THEN 'Drive'
		WHEN	'ET' THEN 'ET'
		WHEN    'EXPWY' THEN 'Expressway'
		WHEN    'EXPY' THEN 'Expressway'
		WHEN	'EXT' THEN 'Extension'
		WHEN    'FMRD' THEN 'Farm to Market Road'
		WHEN    'FWY' THEN 'Freeway'
		WHEN    'GRD' THEN 'Grade'
		WHEN    'HBR' THEN 'Harbor'
		WHEN    'HOLW' THEN 'Hollow'
		WHEN    'HWY' THEN 'Highway'
		WHEN    'HTS' THEN 'Hights'
		WHEN	'KY' THEN 'Key'
		WHEN    'LNDG' THEN 'Landing'
		WHEN    'LN' THEN 'Lane'
		WHEN    'LOOP' THEN 'Loop'
		WHEN    'MALL' THEN 'Mall'
		WHEN    'MAL' THEN 'Mall'
        WHEN    'MTN' THEN 'Mountain'
        WHEN    'MTWY' THEN 'Motorway'
		WHEN    'OVAL' THEN 'Oval'
		WHEN    'OPAS' THEN 'Overpass'
		WHEN    'OVPS' THEN 'Overpass'
		WHEN	'PARK' THEN 'Park'
		WHEN    'PASS' THEN 'Pass'
		WHEN    'PATH' THEN 'Path'
		WHEN    'PIKE' THEN 'Pike'
		WHEN    'PKWY' THEN 'Parkway'
		WHEN    'PKY' THEN 'Parkway'
		WHEN    'PL' THEN 'Place'
		WHEN    'PLZ' THEN 'Plaza'
		WHEN	'PSGE' THEN 'Passage'
		WHEN	'PT' THEN 'Point'
		WHEN    'RAMP' THEN 'Ramp'
		WHEN    'RDG' THEN 'Ridge'
		WHEN    'RD' THEN 'Road'
		WHEN    'RMRD' THEN 'Ranch to Market Road'
		WHEN	'RNCH' THEN 'Ranch'
		WHEN    'ROW' THEN 'Row'
		WHEN    'RTE' THEN 'Route'
		WHEN    'RUE' THEN 'Rue'
		WHEN    'RUN' THEN 'Run'
		WHEN    'SKWY' THEN 'Skyway'
        WHEN    'SPGS' THEN 'Springs'
        WHEN    'SPRGS' THEN 'Springs'
        WHEN    'SPUR' THEN 'Spur'
		WHEN    'SQ' THEN 'Square'
		WHEN	'SR' THEN 'State Route'
		WHEN	'STCT' THEN 'Street Court'
		WHEN    'ST' THEN 'Street'
		WHEN    'STR' THEN 'Stravenue'
		WHEN    'TER' THEN 'Terrace'
		WHEN    'TFWY' THEN 'Trafficway'
		WHEN    'THFR' THEN 'Thoroughfare'
		WHEN    'THWY' THEN 'Thruway'
		WHEN    'TPKE' THEN 'Turnpike'
		WHEN    'TRCE' THEN 'Trace'
		WHEN    'TRL'  THEN 'Trail'
		WHEN	'TRL' THEN 'Trail'
		WHEN    'TUNL' THEN 'Tunnel'
		WHEN    'UNP' THEN 'Underpass'
		WHEN	'VIA' THEN 'Viaduct'
		WHEN	'VIS' THEN 'Vista'
		WHEN    'WALK' THEN 'Walk'
		WHEN    'WAY' THEN 'Way'
		WHEN    'WKWY' THEN 'Walkway'
		WHEN    'XING' THEN 'Crossing'
		ELSE n
		
		END;
	RETURN r;
END;
$$ LANGUAGE plpgsql;

create or replace function expand_direction (n varchar) RETURNS varchar AS $$
DECLARE
  dir varchar;
BEGIN
	IF n IS NULL THEN
		RETURN '';
	END IF;
	SELECT INTO dir
		CASE n
			WHEN 'N' THEN 'North'
			WHEN 'NE' THEN 'Northeast'
			WHEN 'NW' THEN 'Northwest'
			WHEN 'E' THEN 'East'
			WHEN 'W' THEN 'West'
			WHEN 'S' THEN 'South'
			WHEN 'SE' THEN 'Southeast'
			WHEN 'SW'THEN 'Southwest'
			ELSE n
	END;
	RETURN dir;
END;
$$ LANGUAGE plpgsql;


--
-- start parsing addresses
--

-- reset our fields
update parcels__public_ SET "addr:housenumber" = NULL,
    "addr:street" = NULL,
    "addr:unit" = NULL
    where "addr:housenumber" IS NOT NULL;

-- parse city sratr
update parcels__public_ SET "addr:city" = initcap(REGEXP_REPLACE(situsfmt2,'^([A-Za-z]+)\*? ([A-Za-z]+)$', '\1')),
    "addr:state" = initcap(REGEXP_REPLACE(situsfmt2,'^([A-Za-z]+)\*? ([A-Za-z]+)$', '\2'))
    where situsfmt2 SIMILAR TO '([A-Za-z]+)\*? ([A-Za-z]+)' IS NOT NULL;

-- basic 123 Main with no common suffixes or numbers
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]+)$', '\2')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]+)'
    AND situsfmt1 NOT LIKE '%NONE';


-- convenient query to check status as you go
-- select count(*), min(situsfmt1), min("addr:housenumber"), max("addr:housenumber"), "addr:street", min("addr:unit") from parcels__public_
--     where "addr:housenumber" is not null
-- 	group by "addr:street"
--     order by count desc;


update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)$', 'Highway \2')) where situsfmt1 SIMILAR TO '([0-9]+) HWY ([0-9]+)';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HIGHWAY ([0-9]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HIGHWAY ([0-9]+)$', 'Highway \2')) where situsfmt1 SIMILAR TO '([0-9]+) HIGHWAY ([0-9]+)';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ARROWHEAD MTN TRL$', '\1')),
    "addr:street" = 'Arrowhead Mountain Trail' where situsfmt1 SIMILAR TO '([0-9]+) ARROWHEAD MTN TRL';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) S FITCH MTN RD$', '\1')),
    "addr:street" = 'South Fitch Mountain Road' where situsfmt1 SIMILAR TO '([0-9]+) S FITCH MTN RD';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) S MCDOWELL EXT BLVD$', '\1')),
    "addr:street" = 'South McDowell Boulevard Extension' where situsfmt1 SIMILAR TO '([0-9]+) S MCDOWELL EXT BLVD';

-- basic 123 Main St
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\2 ')) -- Main / 4th / A / Saint
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\3'))) -- Street / Johns
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{1,99}) ([A-Z]{2,99})';
-- now 123 Twin Oaks Ln or 123 St Oaks Pl or 12690 Redwood Hwy So or 1300 19th Hole Dr
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\2'))) -- St / Los / 19th
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\3'))) -- Pl / Main
             || ' ' -- space
             || initcap(expand_road(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\4')))) -- Dr / Oak / So
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})';
-- now 123 E Cherry Creek Rd
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})$', '\2'))) -- South
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})$', ' \3 ')) -- Cherry
	     || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})$', '\4 ')) -- Creek
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})$', '\5'))) -- Street
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{1}) ([0-9A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{2,99})';

-- basic directional 123 S Main St
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\2'))) -- South
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', ' \3 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{1,99}) ([A-Z]{2,99})$', '\4'))) -- Street
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{1}) ([0-9A-Z]{1,99}) ([A-Z]{2,99})';

-- and the ever lovable 123 Main St S
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})$', '\3'))) -- Street
             || ' ' -- space
	         || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})$', '\4'))) -- S (South)
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})';

-- and 14521 CANYON 2 RD
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\2')) -- Canyon
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\3'))) -- 2
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\4'))) -- Rd
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})';

-- and 15560 UPPER CANYON 3 RD
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\2')) -- Upper
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\3'))) -- Canyon
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\4'))) -- 2
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})$', '\5'))) -- Rd
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([0-9]{1}) ([A-Z]{2})';

-- and the even more lovable 123 Main Hill St S
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\1')), -- 123
    "addr:street" =  initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\2'))) -- Main
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', ' \3 ')) -- Hill
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\4'))) -- Street
             || ' ' -- space
             || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\5'))) -- S (South)
    where situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})';

-- now 10000 FRANZ VALLEY SCHOOL RD / 6401 MTN VIEW RANCH RD / 3762 MANOR LN WEST BRANCH / 222 RAGLE RD SOUTH RD/ 300 ROHNERT PARK EXPWY WEST
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\1')), -- 10000
    "addr:street" =  initcap(expand_road(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\2')))) -- Franz
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\3'))) -- Valley
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\4'))) -- School
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\5'))) -- Road
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})';

-- now 27801 STEWARTS PT SKAGGS SPRGS RD
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\1')), -- 27801
    "addr:street" =  initcap(expand_road(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\2')))) -- Stewarts
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\3'))) -- Point
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\4'))) -- Skaggs
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\5'))) -- Springs
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\6'))) -- Road
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})';

-- 131 LYNCH CREEK A WAY

-- 935 W SPAIN UNIT B ST

-- now 1706 B W COLLEGE AVE

-- now 2347 MARIA LUZ E CT
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\2')) -- Town & Country
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\3'))) -- Drive
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})';


-- 622 ELY S BLVD

-- 292 ELY BLVD S BLVD

-- now 1460 TOWN & COUNTRY DR
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\2')) -- Town & Country
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})$', '\3'))) -- Drive
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z &]{4,99}) ([A-Z]{2,99})';

-- for these apartment numbers we're gonna need to start using some functions
-- no direction but three words in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\2 \3 ')) -- La Main
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\5'))    -- Unit 4
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)';
-- suffix direction and two words
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)$', '\3'))) -- Street
             || ' ' -- space
	     || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))), -- S (South)
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)$', '\5'))    -- Unit 4 / A
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([ 0-9A-Z\-]+)';
-- prefix direction and two words
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" =  initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\2'))) -- S (South)
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', ' \3 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\5'))    -- Unit 4 / A
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)';
-- prefix direction and three words like 1323 W DRY CREEK RD #2
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" =  initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\2'))) -- S (South)
    || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\3'))) -- Dry
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))) -- Creek/Ext
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\5'))), -- Road
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\6'))    -- Unit 4 / A
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)';
-- no direction and two words in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\3'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))    -- Unit 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)';
-- no direction and one word in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\2')), -- Main / 4th
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)$', '\3'))    -- Unit 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+)[ ]+[#]+([ 0-9A-Z\-]+)';
-- no direction and five words in street name like 31510 STEWARTS PT SKAGGS SPRGS RD #B
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\1')), -- 31510
    "addr:street" = initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\2'))) -- Stewarts
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\3'))) -- Point
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\4'))) -- Skaggs
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\5'))) -- Springs
             || ' ' -- space
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\6'))), -- Road
    "addr:unit" = initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)$', '\7')))    -- Unit B
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})[ ]+[#]+([ 0-9A-Z\-]+)';

-- no direction, two words in street name, and "STE XXX" or "Ste XXX" in the unit
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+STE ([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+STE ([0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+STE ([0-9A-Z\-]+)$', '\3'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+STE ([0-9A-Z\-]+)$', '\4'))    -- STE 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+STE ([0-9A-Z\-]+)';
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+Ste ([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+Ste ([0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+Ste ([0-9A-Z\-]+)$', '\3'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+Ste ([0-9A-Z\-]+)$', '\4'))    -- Ste 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+Ste ([0-9A-Z\-]+)';

-- 123 D EXT ST is a unique case that actually needs to be 123 D Street Extension
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) EXT ST$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) EXT ST$', '\2 Street Extension')) where situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+) EXT ST';

-- 123 B MEADOWBROOK CT is a unique case that actually needs to be 123 Meadowbrook Court, Unit B
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]) MEADOWBROOK CT$', '\1')),
    "addr:street" = 'Meadowbrook Court',
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]) MEADOWBROOK CT$', '\2')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]) MEADOWBROOK CT';

-- 123 HWY 116  #C1 is a unique case that needs to be 123 Highway 116, Unit C1
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)[ ]+#([0-9A-Z]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)[ ]+#([0-9A-Z]+)$', 'Highway \2')),
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+)[ ]+#([0-9A-Z]+)$', '\3'))
    where "addr:housenumber" is null and situsfmt1 SIMILAR TO '([0-9]+) HWY ([0-9]+)[ ]+#([0-9A-Z]+)';

-- 123 HWY 116 N #C1 is a unique case that needs to be 123 Highway 116 North, Unit C1
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+) ([A-Z]+)[ ]+#([0-9A-Z]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+) ([A-Z]+)[ ]+#([0-9A-Z]+)$', 'Highway \2')) -- Highway 116
        || ' ' -- space
        || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+) ([A-Z]+)[ ]+#([0-9A-Z]+)$', '\3'))), -- North
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) HWY ([0-9]+) ([A-Z]+)[ ]+#([0-9A-Z]+)$', '\4')) -- Unit C1
    where "addr:housenumber" is null and situsfmt1 SIMILAR TO '([0-9]+) HWY ([0-9]+) ([A-Z]+)[ ]+#([0-9A-Z]+)';

-- 3333 STEWART PT SKAGGS SPRING RD is a unique case that needs to be Stewarts Point-Skaggs Springs Road
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) STEWART PT SKAGGS SPRING RD$', '\1')),
    "addr:street" = 'Stewarts Point-Skaggs Springs Road'
    where "addr:housenumber" is null and situsfmt1 SIMILAR TO '([0-9]+) STEWART PT SKAGGS SPRING RD';

-- remove "Ste", "Kandace", "Starr" from unit
update parcels__public_ SET "addr:unit" = REGEXP_REPLACE("addr:unit", 'Ste', '') where "addr:unit" LIKE '%Ste%';
update parcels__public_ SET "addr:unit" = REGEXP_REPLACE("addr:unit", 'Kandace', '') where "addr:unit" LIKE '%Kandace%';
update parcels__public_ SET "addr:unit" = REGEXP_REPLACE("addr:unit", 'Starr', '') where "addr:unit" LIKE '%Starr%';
-- remove "Ln" from unit and move it to the street
update parcels__public_ SET "addr:unit" = REGEXP_REPLACE("addr:unit", 'Ln', ''),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+#LN$', '\2 Lane'))
    where situsfmt1 LIKE '%#LN%';

-- properly categorize certain Scottish last names (we're drawing the line at Mackey and non-Scottish Mc* / Mac*)
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Mcarthur', 'McArthur') where "addr:street" LIKE '%Mcarthur%';
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Mcdowell', 'McDowell') where "addr:street" LIKE '%Mcdowell%';
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Macarthur', 'MacArthur') where "addr:street" LIKE '%Macarthur%';
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Macfarlane', 'MacFarlane') where "addr:street" LIKE '%Macfarlane%';
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Mackinnon', 'MacKinnon') where "addr:street" LIKE '%Mackinnon%';
update parcels__public_ SET "addr:street" = REGEXP_REPLACE("addr:street", 'Macmahan', 'MacMahan') where "addr:street" LIKE '%Macmahan%';

-- Stewarts Point-Skaggs Springs Road is the OpenStreetMap name for this street, override
update parcels__public_ SET "addr:street" = 'Stewarts Point-Skaggs Springs Road' where situsfmt1 LIKE '%STEWART%SKAGG%';

-- FYI this dataset has "Blank Road" but that is an actual real road
-- TODO: consider "0" housenumbers

-- 900 TRANSPORT WAY #A&B
-- 21075 RIVER BLVD #1 & 2
-- 34 A&B RANDALL LN
-- 34 A & B RANDALL LN
-- 99 e SHILOH RD

--
-- Match buildings to parcels
--	
	
	
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
		b.gid,
		p."addr:housenumber",
		p."addr:street",
		p."addr:unit",
		p."addr:city",
		p."addr:state",
		p.usecode
	FROM sonoma_county_building_outlines AS b JOIN parcels__public_ AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE p.building_count = 1 AND NOT p.repeating
)
UPDATE sonoma_county_building_outlines SET 
	"addr:housenumber" = a."addr:housenumber",
	"addr:street" = a."addr:street",
	"addr:unit" = a."addr:unit",
	"addr:city" = a."addr:city",
	"addr:state" = a."addr:state",
	"usecode" = a.usecode
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
		b.gid, p."addr:housenumber", p."addr:street", p.usecode
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
	"addr:street" = a."addr:street",
	"usecode" = a.usecode
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

--SELECT COUNT(*) FROM sonoma_county_building_outlines WHERE "addr:housenumber" IS NOT NULL OR "addr:street" IS NOT NULL;
-- result: 123793
--SELECT COUNT(*) FROM sonoma_county_building_outlines WHERE "addr:housenumber" IS NULL AND "addr:street" IS NULL;
-- result: 155217

-- try to assign multiple addresses from multiple parcels to single buildings
WITH addresses AS (
	SELECT 
		b.gid,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:housenumber"), ';') AS housenumber,
		array_to_string( ARRAY_AGG(DISTINCT p."addr:street"), ';') AS street,
		p.usecode
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
	"addr:street" = street,
	"usecode" = a.usecode
FROM addresses AS a
WHERE a.gid = b.gid;

--select * from sonoma_county_building_outlines where "addr:housenumber" LIKE '%;%' OR "addr:street" LIKE '%;%';
-- result: 0, may not be working TODO

-- try to identify addresses for buildings across multiple parcels
-- todo: this may not have done anything
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

--select * from sonoma_county_building_outlines where "addr:housenumber" LIKE '%;%' OR "addr:street" LIKE '%;%';
-- result: 0, may not be working TODO


-- identify intersecting/conflated buildings

--
-- RUN ONLY ONE
--

-- IF USING Overpass -> QGIS -> Postgres Dump:
UPDATE sonoma_county_building_outlines AS b SET conflated = FALSE;
UPDATE sonoma_county_building_outlines AS b SET conflated = TRUE
FROM osmquery_buildings_pgdump AS osm
    WHERE ST_Intersects(b.geom,osm.wkb_geometry)
    AND osm.building IS NOT NULL and osm.building != 'no';

-- IF USING a direct OSM2PGSQL import:
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
        "addr:unit",
        (st_dump(loc_geom)).*
        FROM sonoma_county_building_outlines
        WHERE conflated
) 
SELECT 
	poly.gid,
	poly."addr:housenumber",
    poly."addr:street",
    poly."addr:unit",
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


-- 233966 duplicated, deleted smaller
-- 248900 duplicated, deleted smaller
-- 246427 duplicated, deleted smaller
-- 240471 duplicated, deleted smaller
-- 277549 duplicated, deleted smaller
-- 269953


-- next do non-conflated buildings separately
with poly as (
	SELECT
        gid,
        "addr:housenumber",
        "addr:street",
        "addr:unit",
        (st_dump(loc_geom)).*
        FROM sonoma_county_building_outlines
        WHERE NOT conflated --note: NOT
) 
SELECT 
    poly.gid,
    poly."addr:housenumber",
    poly."addr:street",
    poly."addr:unit",
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



------- TODO

alter table sonoma_building_outlines add column cid integer;

-- Drop TAZs that aren't near SJ
with hull as (
	select ST_ConvexHull(ST_Collect(geom)) as geom from (
		union select geom
		from "sonoma_building_outlines"
	) as geom)
	delete from VTATaz
	using hull
	where not ST_Intersects(VTATaz.geom, hull.geom);

-- Assign cluster to each data point
update sonoma_building_outlines as t
	set cid = taggedThing.key
	from (
		select (row_number() over (partition by sonoma_building_outlines.gid order by ST_Distance(sonoma_building_outlines.geom, VTATaz.geom))) as rn,
		VTATaz.key, sonoma_building_outlines.gid
		from sonoma_building_outlines
		join VTATaz
		on ST_Intersects(sonoma_building_outlines.geom, VTATaz.geom)
	) as taggedThing
	where t.gid = taggedThing.gid and rn = 1;
-- More specifically drop TAZs that don't have any SJ data in them
delete from VTATaz
	where key not in (
		select distinct cid from sonoma_building_outlines
	);
