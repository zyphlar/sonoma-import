# Sonoma County Building/Parcel/Address Import

Based on https://github.com/Nate-Wessel/hamilton-import

original_data from:
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

Ubuntu
- sudo apt install postgis

## Running
