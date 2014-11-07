#############################################################################
# JuMP
# An algebraic modelling langauge for Julia
# See http://github.com/JuliaOpt/JuMP.jl
#############################################################################
# test/nonlinear.jl
# Test general nonlinear
# Must be run as part of runtests.jl, as it needs a list of solvers.
#############################################################################
using JuMP, FactCheck

facts("[nonlinear] Test HS071 solves correctly") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # hs071
    # Polynomial objective and constraints
    # min x1 * x4 * (x1 + x2 + x3) + x3
    # st  x1 * x2 * x3 * x4 >= 25
    #     x1^2 + x2^2 + x3^2 + x4^2 = 40
    #     1 <= x1, x2, x3, x4 <= 5
    # Start at (1,5,5,1)
    # End at (1.000..., 4.743..., 3.821..., 1.379...)
    m = Model(solver=nl_solver)
    @defVar(m, 1 <= x[1:4] <= 5)
    @setNLObjective(m, Min, x[1]*x[4]*(x[1]+x[2]+x[3]) + x[3])
    @addNLConstraint(m, x[1]*x[2]*x[3]*x[4] >= 25)
    @addNLConstraint(m, sum{x[i]^2,i=1:4} == 40)
    setValue(x[1],1.0)
    setValue(x[2],5.0)
    setValue(x[3],5.0)
    setValue(x[4],1.0)
    status = solve(m)

    @fact status => :Optimal
    @fact getValue(x)[:] => roughly(
        [1.000000, 4.742999, 3.821150, 1.379408], 1e-5)
end; end; end


facts("[nonlinear] Test HS071 solves correctly, epigraph") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
        # hs071, with epigraph formulation
        # Linear objective, nonlinear constraints
        # min t
        # st  t >= x1 * x4 * (x1 + x2 + x3) + x3
        #     ...
        m = Model(solver=nl_solver)
        @defVar(m, 1 <= x[1:4] <= 5)
        @defVar(m, t)
        @setObjective(m, Min, t)
        @addNLConstraint(m, t >= x[1]*x[4]*(x[1]+x[2]+x[3]) + x[3])
        @addNLConstraint(m, x[1]*x[2]*x[3]*x[4] >= 25)
        @addNLConstraint(m, sum{x[i]^2,i=1:4} == 40)
        setValue(x[1],1.0)
        setValue(x[2],5.0)
        setValue(x[3],5.0)
        setValue(x[4],1.0)
        setValue(t, 100)
        status = solve(m)

        @fact status => :Optimal
        @fact getValue(x)[:] => roughly(
            [1.000000, 4.742999, 3.821150, 1.379408], 1e-5)
end; end; end


facts("[nonlinear] Test QP solve through NL pathway") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # Solve a problem with quadratic objective with linear
    # constraints, but force it to use the nonlinear code.
    m = Model(solver=nl_solver)
    @defVar(m, 0.5 <= x <=  2)
    @defVar(m, 0.0 <= y <= 30)
    @setObjective(m, Min, (x+y)^2)
    @addNLConstraint(m, x + y >= 1)
    status = solve(m)
    
    @fact status => :Optimal
    @fact m.objVal => roughly(1.0, 1e-6)
    @fact getValue(x)+getValue(y) => roughly(1.0, 1e-6)
end; end; end


facts("[nonlinear] Test quad con solve through NL pathway") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # Solve a problem with linear objective with quadratic
    # constraints, but force it to use the nonlinear code.
    m = Model(solver=nl_solver)
    @defVar(m, -2 <= x <= 2)
    @defVar(m, -2 <= y <= 2)
    @setNLObjective(m, Min, x - y)
    @addConstraint(m, x + x^2 + x*y + y^2 <= 1)
    status = solve(m)

    @fact status => :Optimal
    @fact getObjectiveValue(m) => roughly(-1-4/sqrt(3), 1e-6)
    @fact getValue(x) + getValue(y) => roughly(-1/3, 1e-3)
end; end; end


facts("[nonlinear] Test maximization objective") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # Solve a simple problem with a maximization objective
    m = Model(solver=nl_solver)
    @defVar(m, -2 <= x <= 2); setValue(x, -1.8)
    @defVar(m, -2 <= y <= 2); setValue(y,  1.5)
    @setNLObjective(m, Max, y - x)
    @addConstraint(m, x + x^2 + x*y + y^2 <= 1)

    @fact solve(m) => :Optimal
    @fact getObjectiveValue(m) => roughly(1+4/sqrt(3), 1e-6)
    @fact getValue(x) + getValue(y) => roughly(-1/3, 1e-3)
end; end; end


facts("[nonlinear] Test infeasibility detection") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # (Attempt to) solve an infeasible problem
    m = Model(solver=nl_solver)
    n = 10
    @defVar(m, 0 <= x[i=1:n] <= 1)
    @setNLObjective(m, Max, x[n])
    for i in 1:n-1
        @addNLConstraint(m, x[i+1]-x[i] == 0.15)
    end
    @fact solve(m, suppress_warnings=true) => :Infeasible
end; end; end


facts("[nonlinear] Test unboundedness detection") do
for nl_solver in nl_solvers
context("With solver $(typeof(nl_solver))") do 
    # (Attempt to) solve an unbounded problem
    m = Model(solver=nl_solver)
    @defVar(m, x >= 0)
    @setNLObjective(m, Max, x)
    @addNLConstraint(m, x >= 5)
    @fact solve(m, suppress_warnings=true) => :Unbounded
end; end; end


#############################################################################
# Test that output is produced in correct MPB form
type DummyNLPSolver <: MathProgBase.AbstractMathProgSolver
end
type DummyNLPModel <: MathProgBase.AbstractMathProgModel
end
MathProgBase.model(s::DummyNLPSolver) = DummyNLPModel()
function MathProgBase.loadnonlinearproblem!(m::DummyNLPModel, numVar, numConstr, x_l, x_u, g_lb, g_ub, sense, d::MathProgBase.AbstractNLPEvaluator)
    MathProgBase.initialize(d, [:ExprGraph])
    objexpr = MathProgBase.obj_expr(d)
    facts("[nonlinear] Test NL MPB interface ($objexpr)") do
        @fact objexpr => anyof(:(x[1]^x[2]), :(-1.0*x[1]+1.0*x[2]))
        @fact MathProgBase.isconstrlinear(d,1) => true
        @fact MathProgBase.constr_expr(d,1) => :(2.0*x[1] + 1.0*x[2] <= 1.0)
        @fact MathProgBase.constr_expr(d,2) => :(2.0*x[1]*x[1] + 1.0*x[2] + -2.0 >= 0)
        @fact MathProgBase.constr_expr(d,3) => :(sin(x[1]) * cos(x[2]) - 5 == 0.0)
        @fact MathProgBase.constr_expr(d,4) => :(1.0*x[1]^2 - 1.0 == 0.0)
        @fact MathProgBase.constr_expr(d,5) => :(2.0*x[1]^2 - 2.0 == 0.0)
    end
end
MathProgBase.setwarmstart!(m::DummyNLPModel,x) = nothing
MathProgBase.optimize!(m::DummyNLPModel) = nothing
MathProgBase.status(m::DummyNLPModel) = :Optimal
MathProgBase.getobjval(m::DummyNLPModel) = NaN
MathProgBase.getsolution(m::DummyNLPModel) = [1.0,1.0]
function test_nl_mpb()
    m = Model(solver=DummyNLPSolver())
    @defVar(m, x)
    @defVar(m, y)
    @setObjective(m, Min, -x+y)
    @addConstraint(m, 2x+y <= 1)
    @addConstraint(m, 2x^2+y >= 2)
    @addNLConstraint(m, sin(x)*cos(y) == 5)
    @addNLConstraint(m, nlconstr[i=1:2], i*x^2 == i)
    solve(m)

    @setNLObjective(m, Min, x^y)
    solve(m)
end
test_nl_mpb()