function to_web_mercator(p)
    return Point2f(MapTiles.project(p, MapTiles.wgs84, MapTiles.web_mercator))
end


function plot_map(;axis=nothing)
    provider = Tyler.TileProviders.OpenStreetMap(:DE)
    stuttgart = Rect2f(9.15153, 48.7509, 0.05, 0.05)
    if isnothing(axis)
        return Tyler.Map(stuttgart; provider=provider)
    else
        return Tyler.Map(stuttgart; axis = axis,provider=provider)
    end
end


function colorbar_aggmean(fig,plot;kwargs...)
    color_raw = map(x -> x.aggbuffer, plot.canvas)
color = @lift(Makie.Aggregation.value.(Ref($(plot.agg)),$color_raw))
cmap = Makie.ColorMapping(
   color[], color, plot.colormap, plot.raw_colorrange,
    plot.colorscale,
    plot.alpha,
    plot.highclip,
    plot.lowclip,
    plot.nan_color)

    Colorbar(
        fig;
        colormap=cmap,
        kwargs...
    )
end