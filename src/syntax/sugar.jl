import Base: ==

# Basic julia sugar

function desugar(ex)
  MacroTools.prewalk(ex) do ex
    @capture(ex, (xs__,)) ? :(tuple($(xs...))) :
    @capture(ex, xs_[i__]) ? :(getindex($xs, $(i...))) :
    ex
  end
end

# Constants

immutable Constant{T}
  value::T
end

tocall(c::Constant) = c.value

isconstant(v::Vertex) = isa(value(v), Constant)

mapconst(f, g) = map(x -> isa(x, Constant) ? Constant(f(x.value)) : f(x), g)

a::Constant == b::Constant = a.value == b.value

Base.hash(c::Constant, h::UInt = UInt(0)) = hash((Constant, c.value), h)

for (c, v) in [(:constant, :vertex), (:dconstant, :dvertex)]
  @eval $c(x) = $v(Constant(x))
  @eval $c(v::Vertex) = $v(v)
end

type Do end

tocall(::Do, a...) = :($(a...);)

# Line Numbers

immutable Line
  file::String
  line::Int
end

const noline = Line("", -1)

function Line(ex::Expr)
  @assert ex.head == :line
  Line(string(ex.args[2]), ex.args[1])
end

function normlines(ex)
  line = noline
  ex′ = :(;)
  for ex in ex.args
    isline(ex) && (line = Line(ex); continue)
    line == noline && (push!(ex′.args, ex); continue)
    @assert @capture(ex, var_ = val_)
    push!(ex′.args, :($var = $line($val)))
  end
  return ex′
end

function applylines(ex)
  ex′ = :(;)
  for ex in ex.args
    @capture(ex, (var_ = val_) | val_)
    val = MacroTools.postwalk(val) do ex
      @capture(ex, l_Frame(x_)) && return x # Ignore frames for now
      @capture(ex, l_Line(x_)) || return ex
      push!(ex′.args, Expr(:line, l.line, Symbol(l.file)))
      @gensym edge
      push!(ex′.args, :($edge = $x))
      return edge
    end
    isexpr(val, Symbol) ? (ex′.args[end].args[1] = val) :
      push!(ex′.args, var == nothing ? :($var = $val) : val)
  end
  return ex′
end

immutable Frame{T}
  f::T
end

immutable SkipFrame end

function striplines(v)
  postwalk(v) do v
    isa(value(v), Line) || isa(value(v), Frame) ? v[1] : v
  end
end

# Static tuples

# TODO: just use `getindex` and `tuple` to represent these?
immutable Split
  n::Int
end

# TODO: printing
function normsplits(ex)
  MacroTools.prewalk(ex) do ex
    @capture(ex, (xs__,) = y_) || return ex
    @gensym edge
    quote
      $edge = $y
      $((:($(xs[i]) = $(Split(i))($edge)) for i = 1:length(xs))...)
    end
  end |> MacroTools.flatten |> block
end

tocall(::typeof(tuple), args...) = :($(args...),)

tocall(s::Split, x) = :($x[$(s.n)])

group(xs...) = vertex(tuple, xs...)

function detuple(v::IVertex)
  postwalk(v) do v
    if isa(value(v), Split) && value(v[1]) == tuple
      v[1][value(v).n]
    else
      v
    end
  end
end

# Bindings

immutable Bind
  name::Symbol
end

# TODO: printing
function insertbinds(ex)
  ls = map(ex.args) do l
    @capture(l, x_ = y_) || return l
    :($x = $(Bind(x))($y))
  end
  :($(ls...);)
end

# Inputs

immutable Input end

splitnode(v, n) = vertex(Split(n), v)

inputnode(n) = splitnode(constant(Input()), n)

isinput(v::IVertex) = isa(value(v), Split) && value(v[1]) == Constant(Input())

function bumpinputs(v::IVertex)
  prewalk(v) do v
    isinput(v) ?
      inputnode(value(v).n + 1) :
      v
  end
end

function spliceinput(v::IVertex, input::IVertex)
  postwalk(v) do v
    value(v) == Constant(Input()) ? input : v
  end
end

spliceinputs(v::IVertex, inputs::Vertex...) =
  spliceinput(v, group(inputs...))

function graphinputs(v::IVertex)
  n = 0
  prewalk(v) do v
    isinput(v) && (n = max(n, value(v).n))
    v
  end
  return n
end

# Closures

immutable Flosure end
immutable LooseEnd end

# TODO: scope
function normclosures(ex)
  bs = bindings(ex)
  MacroTools.prewalk(shortdef(ex)) do ex
    @capture(ex, (args__,) -> body_) || return ex
    @assert all(arg -> isa(arg, Symbol), args)
    closed = filter(x -> inexpr(body, x), bs)
    vars = vcat(closed, args)
    body = MacroTools.prewalk(body) do ex
      ex in vars ?
        Expr(:call, Split(findfirst(x->x==ex, vars)), LooseEnd()) :
        ex
    end
    :($(Flosure())($body, $(closed...)))
  end |> MacroTools.flatten |> block
end

flopen(v::IVertex) = mapconst(x->x==LooseEnd()?Input():x,v)
