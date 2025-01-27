abstract type CompositionalFractions <: FractionVariables end

function values_per_entity(model, v::CompositionalFractions)
    sys = model.system
    nc = number_of_components(sys)
    if has_other_phase(sys)
        nval = nc - 1
    else
        nval = nc
    end
    return nval
end

function update_primary_variable!(state, p::CompositionalFractions, state_symbol, model, dx, w)
    s = state[state_symbol]
    Jutul.unit_sum_update!(s, p, model, dx, w)
end

export OverallMoleFractions
struct OverallMoleFractions <: CompositionalFractions
    dz_max::Float64
end

"""
    OverallMoleFractions(;dz_max = 0.2)

Overall mole fractions definition for compositional. `dz_max` is the maximum
allowable change in any composition during a single Newton iteration.
"""
function OverallMoleFractions(;dz_max = 0.2)
    OverallMoleFractions(dz_max)
end
minimum_value(::OverallMoleFractions) = MultiComponentFlash.MINIMUM_COMPOSITION
absolute_increment_limit(z::OverallMoleFractions) = z.dz_max


function Jutul.increment_norm(dX, state, model, X, pvar::OverallMoleFractions)
    if haskey(state, :ImmiscibleSaturation)
        sw = state.ImmiscibleSaturation
    else
        sw = missing
    end
    M = global_map(model.domain)
    active = active_entities(model.domain, M, Cells())
    get_scaling(::Missing, i) = 1.0
    get_scaling(s, i) = 1.0 - value(s[i])
    T = eltype(dX)
    scale = @something Jutul.variable_scale(pvar) one(T)
    max_v = sum_v = max_v_scaled = sum_v_scaled = zero(T)
    N = degrees_of_freedom_per_entity(model, pvar)
    for i in axes(dX, 1)
        for j in axes(dX, 2)
            cell = active[i]
            dx = dX[i, j]
            s = get_scaling(sw, cell)

            dx_abs = abs(dx)
            # Scale by 1-water saturation
            dx_abs_scaled = dx_abs*s
            max_v = max(max_v, dx_abs)
            max_v_scaled = max(max_v_scaled, dx_abs_scaled)

            sum_v += dx_abs
            sum_v_scaled += dx_abs_scaled
        end
    end
    return (sum = scale*sum_v, sum_scaled = sum_v_scaled, max = scale*max_v, max_scaled = max_v_scaled)
end

"""
A single saturation that represents the "other" phase in a
three phase compositional system where two phases are predicted by an EoS
"""
Base.@kwdef struct ImmiscibleSaturation <: ScalarVariable
    ds_max::Float64 = 0.2
end

maximum_value(::ImmiscibleSaturation) = 1.0# - MINIMUM_COMPOSITIONAL_SATURATION
minimum_value(::ImmiscibleSaturation) = 0.0
absolute_increment_limit(s::ImmiscibleSaturation) = s.ds_max
