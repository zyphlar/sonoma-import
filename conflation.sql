-- add fields for OSM tags and data processing 
ALTER TABLE sonoma_county_building_outlines
	ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN "addr:unit" text,
	ADD COLUMN loc_geom geometry(multipolygon,4326),
	ADD COLUMN conflated boolean DEFAULT FALSE,
	ADD COLUMN main boolean; -- is it the main building on the parcel?

-- create local geometry fields and validate geometries
UPDATE sonoma_county_building_outlines SET loc_geom = ST_MakeValid(geom);
CREATE INDEX ON sonoma_county_building_outlines USING GIST (loc_geom);

-- added fields for the parcels table
ALTER TABLE parcels__public_
    ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN "addr:unit" text,
	ADD COLUMN loc_geom geometry(multipolygon,4326),
	ADD COLUMN building_count integer,
	ADD COLUMN repeating BOOLEAN DEFAULT FALSE;

-- create local geometry fields and validate geometries
UPDATE parcels__public_ SET loc_geom = ST_MakeValid(geom);
CREATE INDEX ON parcels__public_ USING GIST (loc_geom);

-- parse and expand parcel street addresses
-- TODO: find/handle oddballs like 123A Main St and 123 Main St #4
SELECT situsfmt1, "addr:housenumber", "addr:street"
FROM public.parcels__public_
where "addr:housenumber" is null
and situsfmt1 NOT SIMILAR TO '([0-9]+)[A-Z]* [A-Z ]*([0-9]*[A-Z\- ]+)'
and situsfmt1 NOT SIMILAR TO '%NONE'
and situsfmt1 NOT SIMILAR TO '%#%'
and situsfmt1 SIMILAR TO '([0-9]+)% %'
ORDER BY gid ASC;

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

-- basic 123 Main with no common suffixes or numbers
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]+)$', '\1')),
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]+)$', '\2')) where situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]+)'
    AND situsfmt1 NOT LIKE '%NONE';


-- convenient query to check status as you go
select count(*), min(situsfmt1), min("addr:housenumber"), max("addr:housenumber"), "addr:street", min("addr:unit") from parcels__public_
    where "addr:housenumber" is not null
	group by "addr:street"
    order by count desc;


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
-- now 123 Twin Oaks Ln or 123 St Oaks Pl
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\1')), -- 123
    "addr:street" =  initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\2'))) -- St / Los
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', ' \3 ')) -- Pl / Main
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})$', '\4'))) -- Dr / Oak
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{2,99}) ([A-Z]{2,99})';
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
    where situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})';

-- and the even more lovable 123 Main Hill St S
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\1')), -- 123
    "addr:street" =  initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\2'))) -- Main
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', ' \3 ')) -- Hill
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\4'))) -- Street
             || ' ' -- space
             || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})$', '\5'))) -- S (South)
    where situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([0-9A-Z]{2,99}) ([A-Z]{1})';


-- for these apartment numbers we're gonna need to start using some functions
-- no direction but three words in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\2 \3 ')) -- La Main
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\4'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\5'))    -- Unit 4
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{2,99}) ([A-Z]{4,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)';
-- suffix direction
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" =  initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)$', '\3'))) -- Street
             || ' ' -- space
	     || initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)$', '\4'))), -- S (South)
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)$', '\5'))    -- Unit 4 / A
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]{3,99}) ([A-Z]{2,99}) ([A-Z]{1})[ ]+[#]+([0-9A-Z\-]+)';
-- prefix direction
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" =  initcap(expand_direction(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\2'))) -- S (South)
             || initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', ' \3 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\4'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)$', '\5'))    -- Unit 4 / A
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([A-Z]{1}) ([0-9A-Z]{3,99}) ([A-Z]{2,99})[ ]+[#]+([0-9A-Z\-]+)';
-- no direction but two words in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\2 ')) -- Main / 4th
             || initcap(expand_road(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\3'))), -- Street
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\4'))    -- Unit 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+) ([A-Z]+)[ ]+[#]+([0-9A-Z\-]+)';
-- no direction but one word in street name
update parcels__public_ SET "addr:housenumber" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\1')), -- 123
    "addr:street" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\2')), -- Main / 4th
    "addr:unit" = initcap(REGEXP_REPLACE(situsfmt1, '^([0-9]+) ([0-9A-Z]+)[ ]+[#]+([0-9A-Z\-]+)$', '\3'))    -- Unit 4 / A / 1-A-B2
    where "addr:housenumber" IS NULL and situsfmt1 SIMILAR TO '([0-9]+) ([0-9A-Z]+)[ ]+[#]+([0-9A-Z\-]+)';

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

-- TODO: replace Mc([a-z]) with Mc(upper(\1)) when preceded by nothingness or a space
-- capitalize Macarthur, Macfarlane, Mackinnon but not Macaw Mackey Mackl[iy]n or Macmahan
-- investigate Blank Road
-- consider "0" housenumbers
-- remove leading zeroes in housenumbers
-- remove "Ste" from unit
-- 5330 OLD REDWOOD HWY #A B & C
-- 27801 STEWARTS PT SKAGGS SPRGS RD
-- 10000 FRANZ VALLEY SCHOOL RD
-- 1003 HWY 116 N
-- 1382 HWY 116 S  #1
-- 100 SPRING MTN SUMMIT TRL
-- 1055 BROADWAY  #C, D
-- 1055 BROADWAY  #E - H
-- 10826 SUMMER HOME PARK RD
-- 1323 W DRY CREEK RD #2
-- 1340 19TH HOLE DR
-- 14521 CANYON 2 RD
-- 14578 CANYON 1 RD
-- 1460 TOWN & COUNTRY DR
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

--SELECT COUNT(*) FROM sonoma_county_building_outlines WHERE "addr:housenumber" IS NOT NULL OR "addr:street" IS NOT NULL;
-- result: 123793
--SELECT COUNT(*) FROM sonoma_county_building_outlines WHERE "addr:housenumber" IS NULL AND "addr:street" IS NULL;
-- result: 155217

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


-- next do non-conflated buldings separately
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
