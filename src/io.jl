using XLSX
using DataFrames
using Dates
using CSV
function import_verkehrsordnungswidrigkeiten(year)
    fp = "ressources/verkehrsordnungswidrigkeiten-ruhender-Verkehr-$year.xlsx"
    if year == 2023
        tbl = XLSX.readtable(fp,"Sonderstatistik_ruhender_Verkeh","A:F",first_row=11,header=true,infer_eltypes=true)
        dat = DataFrame(tbl.data,tbl.column_labels)

    else
        tbl_list = []
        @showprogress for quartal = 1:4
            tbl = XLSX.readtable(fp,year == 2021 ? "Q$quartal 2021" : "Q$quartal",
            "A:F",first_row=1,header=true,infer_eltypes=true)
           push!(tbl_list,
              DataFrame(tbl.data,tbl.column_labels)
           )
           

           
        end
        dat = reduce(vcat,tbl_list)
    end
    
    #= 2023, 2022, 2021
    Tatort	Tatbestands Nr	Tattag Datum	Tatzeit	Verstoßart	Betrag Gesamt-Soll im Fall
    Tatort	Tatbestands Nr	Tattag Datum	Tatzeit	Verstoss	Betrag Gesamt-Soll im Fall
    Tatort  TBNR1           Tattag	        Tatzeit			    SummeSoll	Verstoßart
    =#
    if year == 2023
        rename!(dat,"Betrag Gesamt-Soll im Fall"=>"SummeSoll")
    elseif year == 2022
        rename!(dat,"Verstoss"=>"Verstoßart","Betrag Gesamt-Soll im Fall"=>"SummeSoll")
    elseif year == 2021
        rename!(dat,"TBNR1"=>"Tatbestands Nr","Tattag"=>"Tattag Datum")
    end

    dat.id .= -1
    dat = dat[.!ismissing.(dat.Tatort),:]

end




function import_tatbestände(fp)
tatbestaende=[]

open(fp) do file
    for ln in eachline(file)
        splt = split(ln,";")
        splt = split(splt[1],"^")
        push!(tatbestaende,splt[1]=>join(splt[2:end]))
    end
end

tatbestaende =Dict(tatbestaende)
tatbestaende["901400"] = "unbekannt 901400"
tatbestaende["901420"] = "unbekannt 901420"
tatbestaende["900100"] = "unbekannt 90100"
return tatbestaende
end


function save_verkehrsordnungswidrigkeiten(to,dat)
    CSV.write(to,dat)


end

function read_verkehrsordnungswidrigkeiten(fp)

    dat = CSV.read(fp,DataFrame)
    _subset = x->x[9:end-1]
    dat.geolocation  = map(x->Point2f(parse.(Float32,x)),split.(_subset.(dat.geolocation),", "))

    dat.Tatzeit = Hour.(hour.(DateTime.(dat.Tatzeitpunkt))).+ Minute.(minute.(DateTime.(dat.Tatzeitpunkt)))
    return dat
end