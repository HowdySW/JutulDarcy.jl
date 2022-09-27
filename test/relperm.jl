using Test, JutulDarcy, Jutul

function test_kr_bounds(relperm, n)
    for ph in 1:n
        S = zeros(n, 1)
        S[ph] = 1.0

        kr = similar(S)
        JutulDarcy.update_as_secondary!(kr, relperm, nothing, S)
        for i in 1:n
            if i == ph
                @test kr[i] > 0
            else
                @test kr[i] == 0
            end
        end
    end
end

function kr_test_sat(n)
    if n == 2
        S = zeros(2, 3)
        S[1, 1] = 1.0
        S[1, 2] = 0.5
        S[1, 3] = 0.1
        for i = 1:3
            S[2, i] = 1 - S[1, i]
        end
    end
    return S
end

function test_brooks_corey_kr()
    bc = BrooksCoreyRelPerm(2, [2.0, 3.0], [0.2, 0.3], [0.9, 1.0])
    S = kr_test_sat(2)
    kr = similar(S)
    @test JutulDarcy.update_as_secondary!(kr, bc, nothing, S) ≈ [0.9 0.324 0.0; 0.0 0.064 1.0]
    test_kr_bounds(bc, 2)
end

function test_standard_kr()
    S = kr_test_sat(2)
    kr = similar(S)

    kr_1 = S -> S^2
    kr_2 = S -> S
    rel_single = JutulDarcy.RelativePermeabilities((kr_1, kr_2))
    JutulDarcy.update_as_secondary!(kr, rel_single, nothing, S)
    for i in axes(kr, 2)
        @test kr[1, i] == kr_1(S[1, i])
        @test kr[2, i] == kr_2(S[2, i])
    end

    # Quadratic in first region, linear in second
    rel_regs = JutulDarcy.RelativePermeabilities(((kr_1, kr_2), (kr_1, kr_2)), regions = [1, 2])
    S = repeat([0.5], 2, 2)
    kr = similar(S)
    JutulDarcy.update_as_secondary!(kr, rel_regs, nothing, S)
    @test S[1, 1] == S[2, 1] ≈ 0.25
    @test S[1, 2] == S[2, 2] ≈ 0.5
end


@testset "RelativePermeabilities" begin
    @testset "BrooksCorey" begin
        test_brooks_corey_kr()
    end
    @testset "Standard kr" begin
        test_standard_kr()
    end
end
