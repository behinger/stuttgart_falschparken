# Visualization of Stuttgarts Traffic tickets
This repository contains code to analyse all ~1.5 Million traffic tickets in Stuttgart in the years 2021, 2022 and 2023 as published on [www.stuttgart.de](https://www.stuttgart.de/organigramm/leistungen/verfahrensinformationen-und-begriffserklaerungen-zum-thema-ordnungswidrigkeiten-und-bussgeldverfahren.php)

I'm using Julia for parsing, and the excellent Makie.jl and Tyler.jl package, especially the datashader library therein to visualize them.


![grafik](https://github.com/user-attachments/assets/f26b172c-9234-470d-99c0-4b20f683b5ec)

Example visualization of all 1.5 million traffic tickets. Bright spot mean more tickets.
## Quick start

For more details see https://github.com/behinger/stuttgart_falschparken/blob/main/2024-09-06_strafzettelFalschparker.jl
```julia
using Pkg
Pkg.activate(".")
using Revise
includet("src/io.jl")
includet("src/osm.jl")
includet("src/various.jl")
includet("src/plotting.jl")
# load the year
years = [2021,2022,2023]
dat = [read_verkehrsordnungswidrigkeiten("2024-09-17_Strafzettel-$year.csv") for year in years] 
dat = reduce(vcat,dat)

# Plotting time

using Makie
using Tyler
using Tyler.TileProviders
using Tyler.MapTiles
using GLMakie

ma = plot_map()

h2 = datashader!(to_web_mercator.(dat.geolocation),alpha=0.8,binsize=5,interpolate=false)
translate!.([h2],0,0,1) # bug in Makie?
Colorbar(current_figure()[1,2], h2)

ma # output figure


```


## Code base
The codebase is a bit adhoc I admit. I "successfully" parse 95.5% of the data. That means, I'm able to geolocate the "Tatort" to an OSM building/adress or an intersection with a Levensthein Distance of at least 0.6.

Parsing one year takes around 30-40minutes on my computer; but if you'd add a Threads.@thread around the for-loop in osm.jl you'd be much 4-8x faster likely. I didnt think of it before the one-time parsing ;-)

The plotting code is still evolving.

## Preprocessed data
Data are ~150mb right now and available not on GH but here:
[2021](https://cloud.wirdreibei.de/s/rCZ8bpPLkP9ZK4n)
[2022](https://cloud.wirdreibei.de/s/NX7WjcwB6gFLCez)
[2023](https://cloud.wirdreibei.de/s/grrYGpTRpEFstoP)
