using ProgressMeter
using StringDistances
import StatsBase
using LightOSM
using Makie

REPLACELIST = ["ecke","neben","museum","wendefläche","auf dem","spielplatz"," lidl","vor lichtmast","bäckerei","fußgängerzone","wagenhalle","naturfreundehaus","parkhaus","über","metzgerei","neben"]

function get_names(osm_building;type="streetnames")
    if type == "streetnames"
        return [d[1]=> d[2].tags["addr:street"] for d in osm_building if "addr:housenumber" ∈ keys(d[2].tags) && "addr:street" ∈ keys(d[2].tags)]
    elseif type == "housenumbers"
        return [d[1]=> string(d[2].tags["addr:housenumber"]) for d in osm_building if "addr:housenumber" ∈ keys(d[2].tags) && "addr:street" ∈ keys(d[2].tags)]
    elseif type == "buildingnames"
        streetnames = get_names(osm_building;type="streetnames")
        housenumbers = get_names(osm_building;type="housenumbers")
        buildingnames = [d[1] => d[2] * " HNR " * e[2] for (d,e) in zip(streetnames,housenumbers)]
        
    end
    
    
end
function geolocate!(dat,osm_driveways,osm_building)
    
buildingnames = get_names(osm_building;type="buildingnames")
buildingnames_lowercase = lowercase.(last.(buildingnames))
# first lookup only streetname without any distracting things
tatort_street = [strip.(lowercase.(r[1])) for r in split.(dat.Tatort,r"\W(HNR|GEGENÜBER|NEBEN|Museum|WENDEFLÄCHE|AUF DEM|Spielplatz| Lidl|VOR LICHTMAST|Bäckerei|FUßGÄNGERZONE|WAGENHALLE|Naturfreundehaus|PARKHAUS|über|Metzgerei|Neben|[ 	])")]


# sort the streetnames haystack for faster search
streetnames = get_names(osm_building;type="streetnames")
streetnames_mod = (lowercase.(last.(streetnames)))
sort_ix = sortperm(streetnames_mod)
streetnames_mod = streetnames_mod[sort_ix]

drive_ways = [o[1]=>o[2].tags["name"] for o in osm_driveways.ways if "name" in keys(o[2].tags)]

drive_ways_mod = lowercase.(last.(drive_ways))
function find_drive_way_nodes(a)
    a_way_id = first.(drive_ways)[findall(drive_ways_mod .== a)]
    if isempty(a_way_id)
        return nothing
    end
    return  reduce(vcat,[osm_driveways.ways[i].nodes for i in a_way_id])
    
    end

#--- 
# slow identification step, 20k samples take ~1min => 20min for all?!
@showprogress for k = 1:length(tatort_street)
    if dat.id[k] != -1
        continue
    end
	if tatort_street[k] == "moskauer straße"
		# search streets - not buildings. #TODO
		continue
	end
    # TODO
    if contains(tatort_street[k],"ecke")
        #   # find intersection
        splt = split(tatort_street[k],"ecke")
        a = strip(splt[1])
        b = strip(splt[2])

     
        nodes_a = find_drive_way_nodes(a)
        nodes_b = find_drive_way_nodes(b)
        if isnothing(nodes_a) || isnothing(nodes_b)
            id = nothing
        else
            id_intersect = intersect(nodes_a,nodes_b)
            if isempty(id_intersect)
               # @show a,b
            end
            id = isempty(id_intersect) ? nothing : id_intersect[1]
        end
    else
        ix= searchsorted(streetnames_mod,tatort_street[k])
        id = nothing
        if length(ix) == 0
            id = return_nearest_id(dat.Tatort[k],buildingnames_lowercase,buildingnames)
            
        else
            id = return_nearest_id(dat.Tatort[k],buildingnames_lowercase,buildingnames;ix=@view(sort_ix[ix]))
            
        end
    end 
	dat.id[k] = isnothing(id) ? -1 : id
end

# check, how many id'ed?
println("identified $(sum(dat.id.>0)) tatorte")

#---- 
# add the location of the identified buildingnames
# TODO: we should rather use the closest street or something -> nearest_point_on_way

ix = dat.id .!= -1
function get_building(id) 
    try
        return osm_building[id]
    catch
        return nothing
    end
end

locs = get_centroid.(get_building.(dat.id[ix]))

# intersections are not buildings
intersection_ix = findall(isnothing.(locs))
ecke_id = dat.id[ix][intersection_ix]
get_ecke(ecke) = osm_driveways.nodes[ecke]
locs[intersection_ix] = [[node.location.lon,node.location.lat] for node in get_ecke.(ecke_id)]

dat.geolocation .= Ref(Point2f(0,0))
dat.geolocation[ix] .= locs
return dat
end

"""
returns `findnearest` from buildingnames_lowercase based on the Levenshtein distance (minimum 0.6)
"""
function return_nearest_id(needle,buildingnames_lowercase,buildingnames;ix=1:length(buildingnames_lowercase))
	
	needle_processed = replace(lowercase(needle),[Regex("$(r).*")=>"" for r in REPLACELIST]...,"gegenüber"=>"")
	id_pair = findnearest(needle_processed, @view(buildingnames_lowercase[ix]), Levenshtein(); min_score=0.6)
	if isnothing(id_pair[2])
		return nothing
	else
        id = ix[id_pair[2]]
	return first(buildingnames[id])
	end
end

"""
    get_centroid(Vector{Node})
returns the node.location.lon/lat as a Point2f
"""
function get_centroid(b)
    if isnothing(b)
        return nothing
    end
	locations = [[node.location.lon,node.location.lat] for node in b.polygons[1].nodes]
	return Point2f((sum(reduce(hcat,locations),dims=2) / length(locations))[:,1])
end



function get_osm(;type="drive")
    if type == "drive"
        try 
            return graph_from_file("ressources/stuttgart.json";)
        catch
        return download_osm_network(:place_name,
                            place_name="stuttgart, germany",
                            network_type=:drive,
                            download_format = :json,
                            save_to_file_location="stuttgart.json");
        end
    elseif type == "buildings"
       
            return LightOSM.buildings_from_download(:place_name,place_name="stuttgart,germany",save_to_file_location="stuttgart_building.osm")
        
    end
        
end