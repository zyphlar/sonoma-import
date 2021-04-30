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

    #if "gid" in attrs and attrs["gid"] != "":
        #tags["x_son_imp:gid"] = attrs["gid"] #TODO: remove
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
    if "usecode" in attrs and attrs["usecode"] != "":
        #tags["x_son_imp:usecode"] = int(attrs["usecode"]) #TODO: remove

        # SELECT count(*), usecode FROM public.sonoma_county_building_outlines group by usecode order by count desc;
        # SELECT usecode, usecdesc, usectype FROM public.parcels__public_ group by usecode, usecdesc, usectype order by usecode asc;

        # big categories to catch all
        if int(attrs["usecode"]) >= 1 and int(attrs["usecode"]) <= 23:
            tags["building"] = "house" # 1-23 is low density res
        if int(attrs["usecode"]) >= 30 and int(attrs["usecode"]) <= 49:
            tags["building"] = "apartments" # 30-49 is multifamily
        if int(attrs["usecode"]) >= 50 and int(attrs["usecode"]) <= 57:
            tags["building"] = "residential" # 50-57 is misc res (rural)
        if int(attrs["usecode"]) >= 60 and int(attrs["usecode"]) <= 78:
            tags["building"] = "hotel" # 60-78 is hotel/motel/bnb/boarding
        if int(attrs["usecode"]) >= 80 and int(attrs["usecode"]) <= 97:
            tags["building"] = "residential" # 80-97 is misc residential and trailer parks
        if int(attrs["usecode"]) >= 100 and int(attrs["usecode"]) <= 102:
            tags["building"] = "commercial" # 100-102 is misc commercial
        if int(attrs["usecode"]) >= 110 and int(attrs["usecode"]) <= 169:
            tags["building"] = "retail" # 110-169 is shopping/stores
        if int(attrs["usecode"]) >= 170 and int(attrs["usecode"]) <= 203:
            tags["building"] = "office" # 170-203 is generally offices
        if int(attrs["usecode"]) >= 210 and int(attrs["usecode"]) <= 291:
            tags["building"] = "retail" #210-291 is various commercial
        if int(attrs["usecode"]) >= 301 and int(attrs["usecode"]) <= 394:
            tags["building"] = "industrial" # various industrial
        if int(attrs["usecode"]) >= 400 and int(attrs["usecode"]) <= 592:
            tags["building"] = "farm" # various agricultural
        if int(attrs["usecode"]) >= 600 and int(attrs["usecode"]) <= 691:
            tags["building"] = "commercial" # various commercial recreation
        if int(attrs["usecode"]) >= 720 and int(attrs["usecode"]) <= 730:
            tags["building"] = "school" # schools
        if int(attrs["usecode"]) >= 741 and int(attrs["usecode"]) <= 753:
            tags["building"] = "hospital" # medical or care facility
        if int(attrs["usecode"]) >= 770 and int(attrs["usecode"]) <= 892:
            tags["building"] = "commercial" # misc commercial
        if int(attrs["usecode"]) >= 900 and int(attrs["usecode"]) <= 948:
            tags["building"] = "government" # misc govt

        if int(attrs["usecode"]) == 10:
            tags["building"] = "house" # 10 is either single family, duplex, attached, or vacant residential
        if int(attrs["usecode"]) == 51:
            tags["building"] = "house" # 51 is rural residential single or more
        if int(attrs["usecode"]) == 17:
            tags["building"] = "house" # 17 is single family or attached res
        if int(attrs["usecode"]) == 21:
            tags["building"] = "residential" # 21 is generally low density residential/multifamily or care facility
        if int(attrs["usecode"]) == 23:
            tags["building"] = "house" # 23 is sfd or granny or rural res
        if int(attrs["usecode"]) == 52:
            tags["building"] = "house" # 52 is rural res
        if int(attrs["usecode"]) == 22:
            tags["building"] = "residential" # 22 is rural, sfd, or 3 unit multifamily
        if int(attrs["usecode"]) == 50:
            tags["building"] = "farm" # 50 is vacant, rural, or ag mix
        if int(attrs["usecode"]) == 423:
            tags["building"] = "farm" # 423 is vineyard ag with or without house
        if int(attrs["usecode"]) == 15:
            tags["building"] = "semidetached_house" # 15 is attached or condo, probably duplex-ish
        if int(attrs["usecode"]) == 57:
            tags["building"] = "house" # rural res, granny
        if int(attrs["usecode"]) == 34:
            tags["building"] = "house" # sfd or fourplex
        if int(attrs["usecode"]) == 1:
            tags["building"] = "house" # sfd or granny
        if int(attrs["usecode"]) == 320:
            tags["building"] = "warehouse" # warehouse commercial
        if int(attrs["usecode"]) == 170:
            tags["building"] = "office" # one story office comm
        if int(attrs["usecode"]) == 56:
            tags["building"] = "house" # rural manufactured res
        if int(attrs["usecode"]) == 422:
            tags["building"] = "farm" # vineyard
        if int(attrs["usecode"]) == 32:
            tags["building"] = "apartments" # 3 units, 2+ struct res
        if int(attrs["usecode"]) == 541:
            tags["building"] = "farm" # pasture / with res
        if int(attrs["usecode"]) == 94:
            tags["building"] = "house" # manuf. home condo lot
        if int(attrs["usecode"]) == 540:
            tags["building"] = "farm" # pasture / with res
        if int(attrs["usecode"]) == 31:
            tags["building"] = "apartments" # triplex, 1 struct
        if int(attrs["usecode"]) == 171:
            tags["building"] = "office" # 1-2 story office
        if int(attrs["usecode"]) == 54:
            tags["building"] = "house" # rural res
        # if int(attrs["usecode"]) == 0: # vacant commercia/residential
        if int(attrs["usecode"]) == 110:
            tags["building"] = "retail" # single story comm store
        if int(attrs["usecode"]) == 35:
            tags["building"] = "apartments" # 4 unit, 2+ struct res
        if int(attrs["usecode"]) == 310:
            tags["building"] = "industrial" # light manuf indust
        if int(attrs["usecode"]) == 16:
            tags["building"] = "house" # manuf home
        if int(attrs["usecode"]) == 311:
            tags["building"] = "industrial" # light warehouse/manuf
        if int(attrs["usecode"]) == 19:
            tags["building"] = "residential" # rural res / enforceably restricted dwell
        if int(attrs["usecode"]) == 561:
            tags["building"] = "house" # hardwood ag with res
        if int(attrs["usecode"]) == 42:
            tags["building"] = "apartments" # 5-10 res, 2+ struct
        if int(attrs["usecode"]) == 560:
            tags["building"] = "farm" # hardwood ag
        if int(attrs["usecode"]) == 13:
            tags["building"] = "residential" # sfd / nonconform
        #if int(attrs["usecode"]) == 5: # county comm shop or res lot with improv
        if int(attrs["usecode"]) == 710:
            tags["building"] = "church" # religious
        if int(attrs["usecode"]) == 281:
            tags["building"] = "retail" # auto brake shop
        if int(attrs["usecode"]) == 113:
            tags["building"] = "retail" # comm store plus res
        if int(attrs["usecode"]) == 210:
            tags["building"] = "retail" # restaurant
        if int(attrs["usecode"]) == 41:
            tags["building"] = "apartments" # 5-10 res unit, 1 struct
        if int(attrs["usecode"]) == 421:
            tags["building"] = "house" # vineyard with res
        if int(attrs["usecode"]) == 96:
            tags["building"] = "house" # manuf home or condo lot
        if int(attrs["usecode"]) == 190:
            tags["building"] = "office" # medical offices
        if int(attrs["usecode"]) == 280:
            tags["building"] = "retail" # auto repair
        if int(attrs["usecode"]) == 112:
            tags["building"] = "retail" # multiple comm stores
        if int(attrs["usecode"]) == 913:
            tags["building"] = "yes" # state park
        if int(attrs["usecode"]) == 914:
            tags["building"] = "school" # state school
        if int(attrs["usecode"]) == 915:
            tags["building"] = "hospital" # state hospital
        if int(attrs["usecode"]) == 923:
            tags["building"] = "yes" # county park
        if int(attrs["usecode"]) == 924:
            tags["building"] = "hospital" # county hospital
        if int(attrs["usecode"]) == 926:
            tags["building"] = "airport" # county airport
        if int(attrs["usecode"]) == 933:
            tags["building"] = "yes" # city park
        if int(attrs["usecode"]) == 935:
            tags["building"] = "parking" # city parking
        if int(attrs["usecode"]) == 936:
            tags["building"] = "airport" # city airport
        if int(attrs["usecode"]) == 940:
            tags["building"] = "school" # school dist
        if int(attrs["usecode"]) == 941:
            tags["building"] = "fire_station" # fire district

    return tags
