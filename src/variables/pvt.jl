"""
Mass density of each phase
"""
abstract type PhaseMassDensities <: PhaseVariables end

struct ConstantCompressibilityDensities{T} <: PhaseMassDensities
    reference_pressure::T
    reference_densities::T
    compressibility::T
    function ConstantCompressibilityDensities(sys_or_nph::Union{MultiPhaseSystem, Integer}, reference_pressure = 101325.0, reference_density = 1000.0, compressibility = 1e-10)
        if isa(sys_or_nph, Integer)
            nph = sys_or_nph
        else
            nph = number_of_phases(sys_or_nph)
        end

        pref = expand_to_phases(reference_pressure, nph)
        rhoref = expand_to_phases(reference_density, nph)
        c = expand_to_phases(compressibility, nph)
        T = typeof(c)
        new{T}(pref, rhoref, c)
    end
end

function Base.show(io::IO, t::MIME"text/plain", d::ConstantCompressibilityDensities)
    p_r = d.reference_pressure./1e5
    ρ_r = d.reference_densities
    print(io, "ConstantCompressibilityDensities (ref_dens=$ρ_r kg/m^3, ref_p=$p_r bar)")
end

function ConstantCompressibilityDensities(; p_ref = DEFAULT_MINIMUM_PRESSURE, density_ref = 1000.0, compressibility = 1e-10)
    n = max(length(p_ref), length(density_ref), length(compressibility))
    return ConstantCompressibilityDensities(n, p_ref, density_ref, compressibility)
end

@jutul_secondary function update_density!(rho, density::ConstantCompressibilityDensities, model, Pressure, ix)
    p_ref, c, rho_ref = density.reference_pressure, density.compressibility, density.reference_densities
    for i in ix
        for ph in axes(rho, 1)
            @inbounds rho[ph, i] = constant_expansion(Pressure[i], p_ref[ph], c[ph], rho_ref[ph])
        end
    end
end

@inline function constant_expansion(p::Real, p_ref::Real, c::Real, f_ref::Real)
    Δ = p - p_ref
    return f_ref * exp(Δ * c)
end

# Total masses
@jutul_secondary function update_total_masses!(totmass, tv::TotalMasses, model::SimulationModel{G, S}, PhaseMassDensities, FluidVolume, ix) where {G, S<:SinglePhaseSystem}
    @inbounds for i in ix
        V = FluidVolume[i]
        @inbounds for ph in axes(totmass, 1)
            totmass[ph, i] = PhaseMassDensities[ph, i]*V
        end
    end
end

@jutul_secondary function update_total_masses!(totmass, tv::TotalMasses, model::SimulationModel{G, S}, PhaseMassDensities, Saturations, FluidVolume, ix) where {G, S<:ImmiscibleSystem}
    rho = PhaseMassDensities
    s = Saturations
    @inbounds for i in ix
        V = FluidVolume[i]
        @inbounds for ph in axes(totmass, 1)
            totmass[ph, i] = rho[ph, i]*V*s[ph, i]
        end
    end
end

# Total mass
@jutul_secondary function update_total_mass!(totmass, tv::TotalMass, model::SimulationModel{G, S}, TotalMasses, ix) where {G, S<:MultiPhaseSystem}
    @inbounds for c in ix
        tmp = zero(eltype(totmass))
        @inbounds for ph in axes(TotalMasses, 1)
            tmp += TotalMasses[ph, i]
        end
        totmass[c] = tmp
    end
end

@jutul_secondary function update_phase_mass_mob!(ρλ, var::PhaseMassMobilities, model, PhaseMassDensities, PhaseMobilities, ix)
    for i in ix
        @inbounds for ph in axes(ρλ, 1)
            ρλ[ph, i] = PhaseMassDensities[ph, i]*PhaseMobilities[ph, i]
        end
    end
end


@jutul_secondary function update_phase_mass_mob!(λ, var::PhaseMobilities, model, RelativePermeabilities, PhaseViscosities, ix)
    for i in ix
        @inbounds for ph in axes(λ, 1)
            λ[ph, i] = RelativePermeabilities[ph, i]/PhaseViscosities[ph, i]
        end
    end
end

struct FluidVolume <: ScalarVariable end
Jutul.minimum_value(::FluidVolume) = eps()

function Jutul.default_parameter_values(data_domain, model, param::FluidVolume, symb)
    vol = missing
    if haskey(data_domain, :fluid_volume, Cells())
        vol = data_domain[:fluid_volume]
    elseif haskey(data_domain, :pore_volume, Cells())
        vol = data_domain[:pore_volume]
    elseif haskey(data_domain, :volumes, Cells())
        vol = data_domain[:volumes]
        if haskey(data_domain, :porosity, Cells())
            vol = vol.*data_domain[:porosity]
        end
        if haskey(data_domain, :net_to_gross, Cells())
            vol = vol.*data_domain[:net_to_gross]
        end
    else
        g = physical_representation(data_domain)
        vol = domain_fluid_volume(g)
    end
    if ismissing(vol)
        error(":volumes or :pore_volume symbol must be present in DataDomain to initialize parameter $symb, had keys: $(keys(data_domain))")
    end
    return copy(vol)
end

Base.@kwdef struct Temperature{T} <: ScalarVariable
    min::T = 0.0
    max::T = Inf
    max_rel::Union{T, Nothing} = nothing
    max_abs::Union{T, Nothing} = nothing
end

Jutul.default_value(model, T::Temperature) = 303.15 # 30.15 C°
Jutul.minimum_value(T::Temperature) = T.min
Jutul.maximum_value(T::Temperature) = T.max
Jutul.absolute_increment_limit(T::Temperature) = T.max_abs
Jutul.relative_increment_limit(T::Temperature) = T.max_rel
