using Dates

function add_tatbestände!(dat,tatbestände)
    dat.Tatbestand = map(x->tatbestände[string(x)] ,dat[:,"Tatbestands Nr"])
end

function add_has_parkschein!(dat)
    dat.parkschein =  occursin.("Parkschein",dat.Tatbestand)
end

function add_time!(dat)
    extract_time(hhmm) = hhmm=="Rest - nicht zutreffend" ? missing : +(map((x,y)->x(y),[Hour,Minute],split(hhmm,":")[1:2])...)
    extract_time(hhmm::Time) = Hour(hhmm) + Minute(hhmm)
    extract_time(hhmm::Missing) = missing
date_plus_time(d,t::Missing) = d
function date_plus_time(d,t) 
    return DateTime(d) .+ t
end

dat.Tatzeit .= extract_time.(dat.Tatzeit)
dat.Tatzeitpunkt .= date_plus_time.(dat[:,"Tattag Datum"] ,dat.Tatzeit)


end