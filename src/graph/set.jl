typealias ASet{T} Base.AbstractSet{T}

typealias ODict ObjectIdDict

immutable ObjectIdSet{T} <: ASet{T}
  dict::ObjectIdDict
  ObjectIdSet() = new(ObjectIdDict())
end

Base.eltype{T}(::ObjectIdSet{T}) = T

ObjectIdSet() = ObjectIdSet{Any}()

Base.push!{T}(s::ObjectIdSet{T}, x::T) = (s.dict[x] = nothing; s)
Base.delete!{T}(s::ObjectIdSet{T}, x::T) = (delete!(s.dict, x); s)
Base.in(x, s::ObjectIdSet) = haskey(s.dict, x)

(::Type{ObjectIdSet{T}}){T}(xs) = push!(ObjectIdSet{T}(), xs...)

ObjectIdSet(xs) = ObjectIdSet{eltype(xs)}(xs)

Base.collect(s::ObjectIdSet) = collect(keys(s.dict))
Base.similar(s::ObjectIdSet, T::Type) = ObjectIdSet{T}()

@forward ObjectIdSet.dict Base.length

@iter xs::ObjectIdSet -> keys(xs.dict)

typealias OSet ObjectIdSet

immutable ObjectArraySet{T} <: ASet{T}
  xs::Vector{T}
  ObjectArraySet() = new(T[])
end

Base.in{T}(x::T, s::ObjectArraySet{T}) = any(y -> x ≡ y, s.xs)
Base.push!(s::ObjectArraySet, x) = (x ∉ s && push!(s.xs, x); s)

(::Type{ObjectArraySet{T}}){T}(xs) = push!(ObjectArraySet{T}(), xs...)

ObjectArraySet(xs) = ObjectArraySet{eltype(xs)}(xs)

Base.collect(xs::ObjectArraySet) = xs.xs
Base.similar(s::ObjectArraySet, T::Type) = ObjectArraySet{T}()

@forward ObjectArraySet.xs Base.length

@iter xs::ObjectArraySet -> xs.xs

typealias OASet{T} ObjectArraySet{T}
