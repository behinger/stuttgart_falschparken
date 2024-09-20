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


#-- time_smooth

Base.@kwdef struct SmoothAnalysis_time
    npoints::Int=200
    span::Float64=0.75
    degree::Int=2
end

function (l::SmoothAnalysis_time)(input::AlgebraOfGraphics.ProcessedLayer)
    output = map(input) do p, _
        x_raw, y = p
        x = map(z->z.instant.value/10^9,x_raw)
        model = AlgebraOfGraphics.Loess.loess(x, y; l.span, l.degree)
        x̂ = range(extrema(x)..., length=l.npoints)
        ŷ = AlgebraOfGraphics.Loess.predict(model, x̂)
        return (Time.(Nanosecond.(10^9 .*(round.(x̂)))), ŷ), (;)
    end
    plottype = Makie.plottype(output.plottype, Lines)
    return AlgebraOfGraphics.ProcessedLayer(output; plottype)
end

"""
    smooth(; span=0.75, degree=2, npoints=200)

Fit a loess model. `span` is the degree of smoothing, typically in `[0,1]`.
Smaller values result in smaller local context in fitting.
`degree` is the polynomial degree used in the loess model.
`npoints` is the number of points used by Makie to draw the line
"""
smooth_time(; options...) = AlgebraOfGraphics.transformation(SmoothAnalysis_time(; options...))

