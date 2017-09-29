# Inline all stencil function calls
function inlinef(v::IVertex)
  prewalk(v) do v
    isa(v.value, Func) ? DataFlow.spliceinputs(inlinef(v.value.graph), v.inputs...) :
    isa(v.value, Lambda) ? vertex(Lambda(v.value.args, inlinef(v.value.body)), v.inputs...) :
      v
  end |> DataFlow.detuple
end

function λopen(v::IVertex)
  prewalk(v) do v
    isa(value(v), Lambda) ? DataFlow.λopen(v) : v
  end |> DataFlow.detuple
end

function λclose(v::IVertex)
  postwalk(v) do v
    isa(value(v), OLambda) ? DataFlow.λclose(v) : v
  end |> DataFlow.detuple
end

function dependents(v::IVertex)
  deps = ObjectIdDict()
  deps[v] = []
  DataFlow.prefor(v) do v
    foreach(w -> push!(get!(deps, w, []), v), v.inputs)
  end
  return deps
end

# Inline all indexed arrays (if the array is only used once).
function inlinea(v::IVertex)
  v = λopen(v)
  deps = dependents(v)
  v = prewalk(v) do v
    (value(v) == getindex && value(v[1]) isa OLambda && length(deps[v[1]]) == 1) || return v
    λ = λclose(v[1])
    DataFlow.spliceinputs(λ.value.body, λ.inputs..., v.inputs[2:end]...) |> DataFlow.detuple
  end
  λclose(v)
end

inline(v::IVertex) = inlinea(inlinef(v))
