@inline function component_mass_fluxes!(q, face, state, model::SimulationModel{<:Any, <:CompositionalSystem, <:Any, <:Any}, flux_type, kgrad, upw)
    sys = model.system
    aqua = Val(has_other_phase(sys))
    ph_ix = phase_indices(sys)

    X = state.LiquidMassFractions
    Y = state.VaporMassFractions
    kdisc = flux_primitives(face, state, model, flux_type, kgrad, upw)
    q = compositional_fluxes!(q, face, state, X, Y, model, flux_type, kgrad, kdisc, upw, aqua, ph_ix)
    return q
end

@inline function compositional_fluxes!(q, face, state, X, Y, model, flux_type, kgrad, kdisc, upw, aqua::Val{false}, phase_ix)
    nc = size(X, 1)
    l, v = phase_ix
    q_l = darcy_phase_mass_flux(face, l, state, model, flux_type, kgrad, upw, kdisc)
    q_v = darcy_phase_mass_flux(face, v, state, model, flux_type, kgrad, upw, kdisc)

    q = inner_compositional!(q, X, Y, q_l, q_v, upw, nc)
    return q
end

@inline function compositional_fluxes!(q, face, state, X, Y, model, flux_type, kgrad, kdisc, upw, aqua::Val{true}, phase_ix)
    nc = size(X, 1)
    a, l, v = phase_ix
    q_a = darcy_phase_mass_flux(face, a, state, model, flux_type, kgrad, upw, kdisc)
    q_l = darcy_phase_mass_flux(face, l, state, model, flux_type, kgrad, upw, kdisc)
    q_v = darcy_phase_mass_flux(face, v, state, model, flux_type, kgrad, upw, kdisc)

    q = inner_compositional!(q, X, Y, q_l, q_v, upw, nc)
    q = setindex(q, q_a, nc+1)
    return q
end

@inline function inner_compositional!(q, X, Y, q_l, q_v, upw, nc)
    for i in 1:nc
        X_f = upwind(upw, cell -> @inbounds(X[i, cell]), q_l)
        Y_f = upwind(upw, cell -> @inbounds(Y[i, cell]), q_v)

        q_i = q_l*X_f + q_v*Y_f
        q = setindex(q, q_i, i)
    end
    return q
end

function face_average_density(model::CompositionalModel, state, tpfa, phase)
    ρ = state.PhaseMassDensities
    s = state.Saturations
    l = tpfa.left
    r = tpfa.right
    @inbounds s_l = s[phase, l]
    @inbounds s_r = s[phase, r]
    @inbounds ρ_l = ρ[phase, l]
    @inbounds ρ_r = ρ[phase, r]
    return (s_l*ρ_r + s_r*ρ_l)/max(s_l + s_r, 1e-8)
end
