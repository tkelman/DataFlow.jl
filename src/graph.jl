# Construction

immutable Needle{T}
  vertex::T
  output::Int
end

type Vertex{T}
  value::T
  inputs::Vector{Needle{Vertex{T}}}
  outputs::Set{Vertex{T}}

  Vertex(x, args...) = thread!(new(x, [], Set{Vertex{T}}()), args...)
end

Vertex(x, args...) = Vertex{typeof(x)}(x, args...)

value(v::Vertex) = v.value
inputs(v::Vertex) = v.inputs
outputs(v::Vertex) = v.outputs
Base.eltype{T}(::Vertex{T}) = T

function thread!(to::Vertex, from::Needle)
  push!(inputs(to), from)
  push!(outputs(from.vertex), to)
  return to
end

thread!(to::Vertex, from::Vertex) = thread!(to, Needle(from, 1))

thread!(v::Vertex, xs...) = reduce(thread!, v, xs)

# Processing

function neighbours(v::Vertex)
  vs = Set{typeof(v)}()
  for v′ in outputs(v) push!(vs, v′) end
  for v′ in inputs(v) push!(vs, v′.vertex) end
  return vs
end

function walk(f, v::Vertex, children, seen = Set{typeof(v)}())
  v in seen && return
  f(v)
  push!(seen, v)
  for v in children(v)
    walk(f, v, children, seen)
  end
  return
end

foreach(f, v::Vertex) = walk(f, v, neighbours)

function Base.length(v::Vertex)
  n = 0
  foreach(_ -> n += 1, v)
  return n
end

reaching(f, v::Vertex, seen = Set{typeof(v)}()) =
  map(v->walk(f, v, outputs, seen), outputs(v))

function reaching(v::Vertex)
  result = Set{typeof(v)}()
  reaching(v) do v
    push!(result, v)
  end
  return result
end

function iscyclic(v::Vertex)
  cyclic = false
  foreach(v) do v
    v in reaching(v) && (cyclic = true)
  end
  return cyclic
end

function Base.map(f, v::Vertex; cache = d())
  haskey(cache, v) && return cache[v]
  node = Vertex(f(value(v)))
  cache[v] = node
  for out in outputs(v)
    push!(node.outputs, map(f, out, cache = cache))
  end
  for in in inputs(v)
    push!(node.inputs, Needle(map(f, in.graph, cache = cache), in.index))
  end
  return node
end

Base.copy(v::Vertex) = map(identity, v)
