def filterLayer(layer):
    if layer is None:
        print("filterLayer: empty")
        return None

    print(layer.GetName())

    #if layer.GetName() in ["buildingfootprint", "Site_Address_Points", "mergedbuildings", "namedparcels"]:
    if layer.GetName() in ["sonoma_county_building_outlines_filtered"]: # simplified_conflated_buildings   # _filtered
        return layer

def filterTags(attrs):
    if attrs is None:
        print("filterTags: empty")
        return None

    tags = { "building": "yes" }

    if "gid" in attrs and attrs["gid"] != "":
        tags["x_son_imp:gid"] = attrs["gid"]
    if "addr:state" in attrs and attrs["addr:state"] != "":
        tags["addr:state"] = attrs["addr:state"]
    if "addr:city" in attrs and attrs["addr:city"] != "":
        tags["addr:city"] = attrs["addr:city"]
    if "addr:street" in attrs and attrs["addr:street"] != "":
        tags["addr:street"] = attrs["addr:street"]
    if "addr:housenumber" in attrs and attrs["addr:housenumber"] != "":
        tags["addr:housenumber"] = attrs["addr:housenumber"]
    if "addr:unit" in attrs and attrs["addr:unit"] != "":
        tags["addr:unit"] = attrs["addr:unit"]
    if "usecode" in attrs and attrs["x_son_imp:usecode"] != "":
        tags["x_son_imp:usecode"] = attrs["x_son_imp:usecode"] #TODO: proper x_son_imp:usecode

    return tags
