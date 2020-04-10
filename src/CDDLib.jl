module CDDLib

using LinearAlgebra

if VERSION < v"1.3"
    if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
        include("../deps/deps.jl")
    else
        error("CDDLib not properly installed. Please run Pkg.build(\"CDDLib\")")
    end
else
    import cddlib_jll: libcddgmp
end

using Polyhedra

macro dd_ccall(f, args...)
    quote
        ret = ccall(($"dd_$f", libcddgmp), $(map(esc,args)...))
        ret
    end
end

macro ddf_ccall(f, args...)
    quote
        ret = ccall(($"ddf_$f", libcddgmp), $(map(esc,args)...))
        ret
    end
end


macro cdd_ccall(f, args...)
    quote
        ret = ccall(($"$f", libcddgmp), $(map(esc,args)...))
        ret
    end
end

if VERSION < v"1.3"
    function __init__()
        check_deps()
        @dd_ccall set_global_constants Nothing ()
    end
end

import Base.convert, Base.push!, Base.eltype, Base.copy

include("cddtypes.jl")
include("error.jl")
include("mytype.jl")
include("settype.jl")

include("matrix.jl")
include("polyhedra.jl")
include("operations.jl")
include("lp.jl")

using JuMP
include("MOI_wrapper.jl")
include("polyhedron.jl")

end # module
