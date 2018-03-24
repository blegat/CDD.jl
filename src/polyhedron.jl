export CDDLibrary, CDDPolyhedron

struct CDDLibrary <: PolyhedraLibrary
  precision::Symbol

  function CDDLibrary(precision::Symbol=:float)
    if !(precision in [:float, :exact])
      error("Invalid precision, it should be :float or :exact")
    end
    new(precision)
  end
end
Polyhedra.similar_library(::CDDLibrary, ::FullDim, ::Type{T}) where T<:Union{Integer,Rational} = CDDLibrary(:exact)
Polyhedra.similar_library(::CDDLibrary, ::FullDim, ::Type{T}) where T<:AbstractFloat = CDDLibrary(:float)

mutable struct CDDPolyhedron{N, T<:PolyType} <: Polyhedron{N, T}
  ine::Nullable{CDDInequalityMatrix{N,T}}
  ext::Nullable{CDDGeneratorMatrix{N,T}}
  poly::Nullable{CDDPolyhedra{N,T}}
  hlinearitydetected::Bool
  vlinearitydetected::Bool
  noredundantinequality::Bool
  noredundantgenerator::Bool

  function CDDPolyhedron{N, T}(ine::CDDInequalityMatrix) where {N, T <: PolyType}
    new{N, T}(ine, nothing, nothing, false, false, false, false)
  end
  function CDDPolyhedron{N, T}(ext::CDDGeneratorMatrix) where {N, T <: PolyType}
    new{N, T}(nothing, ext, nothing, false, false, false, false)
  end
# function CDDPolyhedron(poly::CDDPolyhedra{T})
#   new(nothing, nothing, poly)
# end
end
Polyhedra.library(::CDDPolyhedron{N, T}) where {N, T} = Polyhedra.similar_library(CDDLibrary(), FullDim{N}(), T)
Polyhedra.arraytype(::Union{CDDPolyhedron{N, T}, Type{<:CDDPolyhedron{N, T}}}) where {N, T} = Vector{T}
Polyhedra.similar_type(::Type{<:CDDPolyhedron}, ::FullDim{N}, ::Type{T}) where {N, T} = CDDPolyhedron{N, T}

CDDPolyhedron(matrix::CDDMatrix{N, T}) where {N, T} = CDDPolyhedron{N, T}(matrix)
Base.convert{N, T}(::Type{CDDPolyhedron{N, T}}, rep::Representation{N, T}) = CDDPolyhedron{N, T}(cddmatrix(T, rep))

# Helpers
function getine(p::CDDPolyhedron)
  if isnull(p.ine)
    p.ine = copyinequalities(getpoly(p))
  end
  get(p.ine)
end
function getext(p::CDDPolyhedron)
  if isnull(p.ext)
    p.ext = copygenerators(getpoly(p))
  end
  get(p.ext)
end
function getpoly(p::CDDPolyhedron, inepriority=true)
  if isnull(p.poly)
    if !inepriority && !isnull(p.ext)
      p.poly = CDDPolyhedra(get(p.ext))
    elseif !isnull(p.ine)
      p.poly = CDDPolyhedra(get(p.ine))
    elseif !isnull(p.ext)
      p.poly = CDDPolyhedra(get(p.ext))
    else
      error("Please report this bug")
    end
  end
  get(p.poly)
end

function clearfield!(p::CDDPolyhedron)
  p.ine = nothing
  p.ext = nothing
  p.poly = nothing
  p.hlinearitydetected = false
  p.vlinearitydetected = false
  p.noredundantinequality = false
  p.noredundantgenerator = false
end
function updateine!(p::CDDPolyhedron{N}, ine::CDDInequalityMatrix{N}) where N
  clearfield!(p)
  p.ine = ine
end
function updateext!(p::CDDPolyhedron{N}, ext::CDDGeneratorMatrix{N}) where N
  clearfield!(p)
  p.ext = ext
end
function updatepoly!(p::CDDPolyhedron{N}, poly::CDDPolyhedra{N}) where N
  clearfield!(p)
  p.poly = poly
end

function Base.copy(p::CDDPolyhedron{N, T}) where {N, T}
  pcopy = nothing
  if !isnull(p.ine)
    pcopy = CDDPolyhedron{N, T}(copy(get(p.ine)))
  end
  if !isnull(p.ext)
    if pcopy == nothing
      pcopy = CDDPolyhedron{N, T}(copy(get(p.ext)))
    else
      pcopy.ext = copy(get(p.ext))
    end
  end
  if pcopy == nothing
    # copy of ine and ext may be not necessary here
    # but I do it to be sure
    pcopy = CDDPolyhedron{N, T}(copy(getine(p)))
    pcopy.ext = copy(getext(p))
  end
  pcopy.hlinearitydetected     = p.hlinearitydetected
  pcopy.vlinearitydetected     = p.vlinearitydetected
  pcopy.noredundantinequality = p.noredundantinequality
  pcopy.noredundantgenerator  = p.noredundantgenerator
  pcopy
end

# Implementation of Polyhedron's mandatory interface
function polytypeforprecision(precision::Symbol)
  if !(precision in (:float, :exact))
    error("precision should be :float or :exact, you gave $precision")
  end
  precision == :float ? Cdouble : Rational{BigInt}
end

function Polyhedra.polyhedron(rep::Representation{N}, lib::CDDLibrary) where N
  T = polytypeforprecision(lib.precision)
  CDDPolyhedron{N, T}(rep)
end
function Polyhedra.polyhedron(hyperplanes::Polyhedra.HyperPlaneIt{N}, halfspaces::Polyhedra.HalfSpaceIt{N}, lib::CDDLibrary) where N
  T = polytypeforprecision(lib.precision)
  CDDPolyhedron{N, T}(hyperplanes, halfspaces)
end
function Polyhedra.polyhedron(vits::Polyhedra.SymPointIt{N}, points::Polyhedra.PointIt{N}, lines::Polyhedra.LineIt{N}, rays::Polyhedra.RayIt{N}, lib::CDDLibrary) where N
  T = polytypeforprecision(lib.precision)
  CDDPolyhedron{N, T}(sympoints, points, lines, rays)
end

getlibraryfor{T<:Real}(::CDDPolyhedron, n::Int, ::Type{T}) = CDDLibrary(:exact)
getlibraryfor{T<:AbstractFloat}(::CDDPolyhedron, n::Int, ::Type{T}) = CDDLibrary(:float)

# need to specify to avoid ambiguïty
Base.convert{N, T}(::Type{CDDPolyhedron{N, T}}, rep::HRepresentation{N}) = CDDPolyhedron{N, T}(cddmatrix(T, rep))
Base.convert{N, T}(::Type{CDDPolyhedron{N, T}}, rep::VRepresentation{N}) = CDDPolyhedron{N, T}(cddmatrix(T, rep))

CDDPolyhedron{N, T}(hits::Polyhedra.HIt{N, T}...) where {N, T} = CDDPolyhedron{N, T}(CDDInequalityMatrix{N, T, mytype(T)}(hits...))
CDDPolyhedron{N, T}(vits::Polyhedra.VIt{N, T}...) where {N, T} = CDDPolyhedron{N, T}(CDDGeneratorMatrix{N, T, mytype(T)}(vits...))

function hrepiscomputed(p::CDDPolyhedron)
  !isnull(p.ine)
end
function hrep(p::CDDPolyhedron{N, T}) where {N, T}
  getine(p)
end

function vrepiscomputed(p::CDDPolyhedron)
  !isnull(p.ext)
end
function vrep(p::CDDPolyhedron{N, T}) where {N, T}
  getext(p)
end


implementseliminationmethod(p::CDDPolyhedron, ::Type{Val{:FourierMotzkin}}) = true
function eliminate(p::CDDPolyhedron, delset, ::Type{Val{:FourierMotzkin}})
    eliminate(p, delset, :FourierMotzkin)
end
implementseliminationmethod(p::CDDPolyhedron, ::Type{Val{:BlockElimination}}) = true
function eliminate(p::CDDPolyhedron, delset, ::Type{Val{:BlockElimination}})
    eliminate(p, delset, :BlockElimination)
end

function eliminate(ine::CDDInequalityMatrix, delset, method=:Auto)
  if length(delset) > 0
    if method == :Auto
        fourier = false
        if length(delset) == 1 && fulldim(ine) in delset
            # CDD's implementation of Fourier-Motzkin does not support linearity
            canonicalizelinearity!(ine)
            if neqs(ine) == 0
                fourier = true
            end
        end
    else
        fourier = method == :FourierMotzkin
    end
    if fourier
      ds = collect(delset)
      for i in length(ds):-1:1
          if ds[i] != fulldim(ine)
              error("The CDD implementation of Fourier-Motzkin only support removing the last dimensions")
          end
          ine = fourierelimination(ine)
      end
      ine
    else
      blockelimination(ine, delset)
    end
  end
end

function eliminate(p::CDDPolyhedron{N, T}, delset, method::Symbol=:Auto) where {N, T}
  CDDPolyhedron{N-length(delset), T}(eliminate(getine(p), delset, method))
end

function detecthlinearities!(p::CDDPolyhedron)
  if !p.hlinearitydetected
    canonicalizelinearity!(getine(p))
    p.hlinearitydetected = true
    # getine(p.poly) would return bad inequalities.
    # If someone use the poly then ine will be invalidated
    # and if he asks the inequalities he will be surprised that the
    # linearities are not detected properly
    # However, the generators can be kept
    p.poly = nothing
  end
end
function detectvlinearities!(p::CDDPolyhedron)
  if !p.vlinearitydetected
    canonicalizelinearity!(getext(p))
    p.vlinearitydetected = true
    # getext(p.poly) would return bad inequalities.
    # If someone use the poly then ext will be invalidated
    # and if he asks the generators he will be surprised that the
    # linearities are not detected properly
    # However, the inequalities can be kept
    p.poly = nothing
  end
end


function removehredundancy!(p::CDDPolyhedron)
  if !p.noredundantinequality
    if !p.hlinearitydetected
      canonicalize!(getine(p))
      p.hlinearitydetected = true
    else
      redundancyremove!(getine(p))
    end
    p.noredundantinequality = true
    # See detectlinearities! for a discussion about the following line
    p.poly = nothing
  end
end

function removevredundancy!(p::CDDPolyhedron)
  if !p.noredundantgenerator
    canonicalize!(getext(p))
    p.noredundantgenerator = true
    # See detecthlinearities! for a discussion about the following line
    p.poly = nothing
  end
end

function Base.intersect!(p::CDDPolyhedron{N}, ine::HRepresentation{N}) where N
  updateine!(p, matrixappend(getine(p), ine))
  #push!(getpoly(p, true), ine) # too slow because it computes double description
  #updatepoly!(p, getpoly(p)) # invalidate others
end
function Polyhedra.convexhull!(p::CDDPolyhedron{N}, ext::VRepresentation{N}) where N
  updateext!(p, matrixappend(getext(p), ext))
  #push!(getpoly(p, false), ext) # too slow because it computes double description
  #updatepoly!(p, getpoly(p)) # invalidate others
end

# TODO other solvers
function defaultLPsolverfor(p::CDDPolyhedron{N,T}, solver=nothing) where {N,T}
    if vrepiscomputed(p)
        SimpleVRepSolver()
    else
        CDDSolver(exact=T == Rational{BigInt})
    end
end
_getrepfor(p::CDDPolyhedron, ::Polyhedra.HIndex) = getine(p)
_getrepfor(p::CDDPolyhedron, ::Polyhedra.VIndex) = getext(p)
function Polyhedra.isredundant(p::CDDPolyhedron, idx::Polyhedra.HIndex; strongly=false, cert=false, solver=defaultLPsolverfor(p))
    f = strongly ? sredundant : redundant
    ans = f(_getrepfor(p, idx), idx.value)
    if cert
        ans
    else
        ans[1]
    end
end

# Implementation of Polyhedron's optional interface
function Base.isempty(p::CDDPolyhedron, solver::CDDSolver)
  lp = matrix2feasibility(getine(p))
  lpsolve(lp)
  # It is impossible to be unbounded since there is no objective
  # Note that `status` would also work
  simplestatus(copylpsolution(lp)) != :Optimal
end

function gethredundantindices(p::CDDPolyhedron)
  redundantrows(getine(p))
end
function getvredundantindices(p::CDDPolyhedron)
  redundantrows(getext(p))
end

# type CDDLPPolyhedron{N, T} <: LPPolyhedron{N, T}
#   ine::CDDInequalityMatrix{N}
#   has_objective::Bool
#
#   objval
#   solution
#   status
# end
#
# function LinearQuadraticModel{N, T}(p::CDDPolyhedron{N, T})
#   CDDLPPolyhedron{N, T}(getine(p), false, nothing, nothing, nothing)
# end
# function loadproblem!(lpm::CDDLPPolyhedron, obj, sense)
#   if sum(abs(obj)) != 0
#     setobjective(lpm.ine, obj, sense)
#     lpm.has_objective = true
#   end
# end
# function optimize!(lpm::CDDLPPolyhedron)
#   if lpm.has_objective
#     lp = matrix2lp(lpm.ine)
#   else
#     lp = matrix2feasibility(lpm.ine)
#   end
#   lpsolve(lp)
#   sol = copylpsolution(lp)
#   lpm.status = simplestatus(sol)
#   # We have just called lpsolve so it shouldn't be Undecided
#   # if no error occured
#   lpm.status == :Undecided && (lpm.status = :Error)
#   lpm.objval = getobjval(sol)
#   lpm.solution = getsolution(sol)
# end
#
# function status(lpm::CDDLPPolyhedron)
#   lpm.status
# end
# function getobjval(lpm::CDDLPPolyhedron)
#   lpm.objval
# end
# function getsolution(lpm::CDDLPPolyhedron)
#   copy(lpm.solution)
# end
# function getunboundedray(lpm::CDDLPPolyhedron)
#   copy(lpm.solution)
# end
