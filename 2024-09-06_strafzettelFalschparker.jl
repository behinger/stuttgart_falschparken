using Revise
includet("src/io.jl")
includet("src/osm.jl")
includet("src/various.jl")
includet("src/plotting.jl")

#----
# for some reason the loading doesnt really work, so I think it downloads it everytime agai if you run it - oh well, next life.
osm_driveways = get_osm(;type="drive")
osm_building = get_osm(;type="buildings")


#---
tatbestände = import_tatbestände("ressources/tatbestaende.txt")
for year = [2021, 2022, 2023]
    dat = import_verkehrsordnungswidrigkeiten(year)
    

    geolocate!(dat,osm_driveways,osm_building) # adds the columns to `dat` - takes quite some time, be warned!
    add_tatbestände!(dat,tatbestände) # adds inplace the translation of the tatbestände
    add_has_parkschein!(dat)
    add_time!(dat)
    save_verkehrsordnungswidrigkeiten("$(string(now())[1:10])_Strafzettel-$year.csv",dat)
end

#----
years = [2021,2022,2023]
dat = [read_verkehrsordnungswidrigkeiten("2024-09-17_Strafzettel-$year.csv") for year in years] 
# Plotting time
dat = reduce(vcat,dat)

#----

using Makie
using Tyler
using Tyler.TileProviders
using Tyler.MapTiles
using GLMakie

#---
ma = plot_map()

h2 = datashader!(to_web_mercator.(dat.geolocation),alpha=0.8,binsize=5,interpolate=false)
translate!.([h2],0,0,1)
Colorbar(current_figure()[1,2], h2)

ma

#---
ma = plot_map()

h2 = datashader!(to_web_mercator.(dat.geolocation[dat.SummeSoll .== 0]),alpha=0.8,binsize=5,interpolate=false)
translate!.([h2],0,0,1)
Colorbar(current_figure()[1,2], h2)

ma
#---
ma = plot_map()
pnts = [Point3f(p[1],p[2],t) for (p,t) in zip(to_web_mercator.(dat.geolocation),dat.SummeSoll.==0)]
h2 = datashader!(pnts,agg=Makie.AggMean(),operation=identity,binsize=15,interpolate=false,colorrange=[0,1],alpha=0.9)
translate!.([h2],0,0,1)

colorbar_aggmean(current_figure()[1,2],h2;label="mean amount payed")
ma

#---
# mean amount payed
ma = plot_map()
pnts = [Point3f(p[1],p[2],t) for (p,t) in zip(to_web_mercator.(dat.geolocation),dat.SummeSoll)]
h2 = datashader!(pnts,agg=Makie.AggMean(),operation=identity,binsize=15,interpolate=false,colorrange=[0,50])
translate!.([h2],0,0,1)

colorbar_aggmean(current_figure()[1,2],h2;label="mean amount payed")
ma
#---
f = Figure()
ax = f[1,1] = Axis(f)
ax2 = f[1,2] = Axis(f)
ma = Tyler.Map(stuttgart;axis=ax, provider=provider)
ma = Tyler.Map(stuttgart;axis=ax2, provider=provider)

jitter_amount = 0.00005
#jitter_amount = 0
locs_jittered = [Point2f(p[1]+randn(Float32)*jitter_amount,p[2]+rand(Float32)*jitter_amount) for p in dat.geolocation[dat.parkschein .&& dat.geolocation .!=Point2f(0,0)]]
locs_jittered_no = [Point2f(p[1]+randn(Float32)*jitter_amount,p[2]+rand(Float32)*jitter_amount) for p in dat.geolocation[.!dat.parkschein .&& dat.geolocation .!=Point2f(0,0)]]

h1 = scatter!(ax,to_web_mercator.(locs_jittered),markersize=15,alpha=1,color=:black)
h2 = scatter!(ax,to_web_mercator.(locs_jittered),markersize=10,alpha=0.1,color=:red)
translate!.([h1,h2],0,0,1)
h1 = scatter!(ax2,to_web_mercator.(locs_jittered_no),markersize=15,alpha=1,color=:black)
h2 = scatter!(ax2,to_web_mercator.(locs_jittered_no),markersize=10,alpha=0.1,color=:green)
translate!.([h1,h2],0,0,1)

linkyaxes!(ax,ax2)
f
#----
# Color according to time of day
f = Figure()
ax = f[1,1] = Axis(f)
ma = Tyler.Map(stuttgart; axis = ax,provider=provider,plot_config=Tyler.PlotConfig(;alpha=0.2))


#jitter_amount = 0.00005
#jitter_amount = 0
#locs_jittered = [Point2f(p[1]+randn(Float32)*jitter_amount,p[2]+rand(Float32)*jitter_amount) for p in dat.geolocation[dat.geolocation .!=Point2f(0,0) .&& .!ismissing.(dat.Tatzeit)]]


#h1 = scatter!(to_web_mercator.(locs_jittered),markersize=15,alpha=1,color=:black)

compoundtime_to_minutes(ct) = isempty(ct.periods) ? Minute(0) : sum(Minute,ct.periods)
#compoundtime_clip_hours(ct) = isempty(ct.periods) ? Hour(0) : ct.periods[1]
tatzeit_minuten = compoundtime_to_minutes.(dat.Tatzeit[.!ismissing.(dat.Tatzeit)])
#tatzeit_stunde= compoundtime_clip_hours.(dat.Tatzeit[.!ismissing.(dat.Tatzeit)])[1:1_000]
#h2 = scatter(ax,to_web_mercator.(locs_jittered)[1:100_000],markersize=10,alpha=1,color=map(x->x.value,tatzeit_minuten))
pnts = [Point3f(p[1],p[2],t.value) for (p,t) in zip(to_web_mercator.(dat.geolocation),tatzeit_minuten)]

struct AggMin{T} <: Makie.Aggregation.AggOp end
AggMin() = AggMin{Float64}()
Makie.Aggregation.null(::AggMin{T}) where {T} = zero(T)
Makie.Aggregation.embed(::AggMin{T}, x) where {T} =  convert(T, x)
Makie.Aggregation.merge(::AggMin{T}, x::T, y::T) where {T} = x==0. ? y : min(x,y)
Makie.Aggregation.value(::AggMin{T}, x::T) where {T} = x


#h2 = datashader!(ax,pnts,agg=AggMin(),operation=identity,binsize=15,interpolate=false)
h2 = datashader!(ax,pnts,agg=Makie.AggMean(),operation=identity,binsize=15,interpolate=false)

translate!.([h2],0,0,1)

#h3 = scatter!(ax,to_web_mercator.(dat.geolocation),markersize=10)
#translate!.([h3],0,0,0.5)
#Colorbar(f[1,2],h2)
f

#----
## what occurs the most?
occurances_pairs = StatsBase.countmap(dat.Tatort)
m = findmax(collect(values(occurances_pairs)))
@info m
collect(keys(occurances_pairs))[m[2]]
