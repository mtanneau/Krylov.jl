# An implementation of BICGSTAB for the solution of unsymmetric and square consistent linear system Ax = b.
#
# This method is described in
#
# H. A. van der Vorst
# Bi-CGSTAB: A fast and smoothly converging variant of Bi-CG for the solution of nonsymmetric linear systems.
# SIAM Journal on Scientific and Statistical Computing, 13(2), pp. 631--644, 1992.
#
# G. L.G. Sleijpen and D. R. Fokkema
# BiCGstab(ℓ) for linear equations involving unsymmetric matrices with complex spectrum.
# Electronic Transactions on Numerical Analysis, 1, pp. 11--32, 1993.
#
# Alexis Montoison, <alexis.montoison@polymtl.ca>
# Montréal, October 2020.

export bicgstab

"""
    (x, stats) = bicgstab(A, b::AbstractVector{T}; c::AbstractVector{T}=b,
                          M=opEye(), N=opEye(), atol::T=√eps(T), rtol::T=√eps(T),
                          itmax::Int=0, verbose::Int=0) where T <: AbstractFloat

Solve the square linear system Ax = b using the BICGSTAB method.

The Biconjugate Gradient Stabilized method is a variant of BiCG, like CGS,
but using different updates for the Aᵀ-sequence in order to obtain smoother
convergence than CGS.

If BICGSTAB stagnates, we recommend DQGMRES and BiLQ as alternative methods for unsymmetric square systems.

BICGSTAB stops when `itmax` iterations are reached or when `‖rₖ‖ ≤ atol + ‖b‖ * rtol`.
`atol` is an absolute tolerance and `rtol` is a relative tolerance.

Additional details can be displayed if verbose mode is enabled (verbose > 0).
Information will be displayed every `verbose` iterations.

This implementation allows a left preconditioner `M` and a right preconditioner `N`.
"""
function bicgstab(A, b :: AbstractVector{T}; c :: AbstractVector{T}=b,
                  M=opEye(), N=opEye(), atol :: T=√eps(T), rtol :: T=√eps(T),
                  itmax :: Int=0, verbose :: Int=0) where T <: AbstractFloat

  n, m = size(A)
  m == n || error("System must be square")
  length(b) == m || error("Inconsistent problem size")
  (verbose > 0) && @printf("BICGSTAB: system of size %d\n", n)

  # Check M == Iₘ and N == Iₙ
  MisI = isa(M, opEye)
  NisI = isa(N, opEye)

  # Check type consistency
  eltype(A) == T || error("eltype(A) ≠ $T")
  MisI || (eltype(M) == T) || error("eltype(M) ≠ $T")
  NisI || (eltype(N) == T) || error("eltype(N) ≠ $T")

  # Determine the storage type of b
  S = typeof(b)

  # Set up workspace.
  x = kzeros(S, n)  # x₀
  s = kzeros(S, n)  # s₀
  v = kzeros(S, n)  # v₀
  r = copy(M * b)   # r₀
  p = copy(r)       # p₁

  α = one(T) # α₀
  ω = one(T) # ω₀
  ρ = one(T) # ρ₀

  # Compute residual norm ‖r₀‖₂.
  rNorm = @knrm2(n, r)
  rNorm == 0 && return (x, SimpleStats(true, false, [rNorm], T[], "x = 0 is a zero-residual solution"))

  iter = 0
  itmax == 0 && (itmax = 2*n)

  rNorms = [rNorm;]
  ε = atol + rtol * rNorm
  (verbose > 0) && @printf("%5s  %7s  %8s  %8s\n", "k", "‖rₖ‖", "αₖ", "ωₖ")
  display(iter, verbose) && @printf("%5d  %7.1e  %8.1e  %8.1e\n", iter, rNorm, α, ω)

  next_ρ = @kdot(n, r, c)  # ρ₁ = ⟨r₀,r̅₀⟩
  next_ρ == 0 && return (x, SimpleStats(false, false, [rNorm], T[], "Breakdown bᵀc = 0"))

  # Stopping criterion.
  solved = rNorm ≤ ε
  tired = iter ≥ itmax
  breakdown = false
  status = "unknown"

  while !(solved || tired || breakdown)
    # Update iteration index and ρ.
    iter = iter + 1
    ρ = next_ρ

    y = N * p                            # yₖ = N⁻¹pₖ
    q = A * y                            # qₖ = Ayₖ
    Mq = M * q; @kcopy!(n, Mq, v)        # vₖ = M⁻¹qₖ
    α = ρ / @kdot(n, v, c)               # αₖ = ⟨rₖ₋₁,r̅₀⟩ / ⟨vₖ,r̅₀⟩
    @kcopy!(n, r, s)                     # sₖ = rₖ₋₁
    @kaxpy!(n, -α, v, s)                 # sₖ = sₖ - αₖvₖ
    @kaxpy!(n, α, y, x)                  # xₐᵤₓ = xₖ₋₁ + αₖyₖ
    z = N * s                            # zₖ = N⁻¹sₖ
    d = A * z                            # dₖ = Azₖ
    t = M * d                            # tₖ = M⁻¹dₖ
    ω = @kdot(n, t, s) / @kdot(n, t, t)  # ⟨tₖ,sₖ⟩ / ⟨tₖ,tₖ⟩
    @kaxpy!(n, ω, z, x)                  # xₖ = xₐᵤₓ + ωₖzₖ
    @kcopy!(n, s, r)                     # rₖ = sₖ
    @kaxpy!(n, -ω, t, r)                 # rₖ = rₖ - ωₖtₖ
    next_ρ = @kdot(n, r, c)              # ρₖ₊₁ = ⟨rₖ,r̅₀⟩
    β = (next_ρ / ρ) * (α / ω)           # βₖ₊₁ = (ρₖ₊₁ / ρₖ) * (αₖ / ωₖ)
    @kaxpy!(n, -ω, v, p)                 # pₐᵤₓ = pₖ - ωₖvₖ
    @kaxpby!(n, one(T), r, β, p)         # pₖ₊₁ = rₖ₊₁ + βₖ₊₁pₐᵤₓ

    # Compute residual norm ‖rₖ‖₂.
    rNorm = @knrm2(n, r)
    push!(rNorms, rNorm)

    # Update stopping criterion.
    solved = rNorm ≤ ε
    tired = iter ≥ itmax
    breakdown = (α == 0 || isnan(α))
    display(iter, verbose) && @printf("%5d  %7.1e  %8.1e  %8.1e\n", iter, rNorm, α, ω)
  end
  (verbose > 0) && @printf("\n")

  status = tired ? "maximum number of iterations exceeded" : (breakdown ? "breakdown αₖ == 0" : "solution good enough given atol and rtol")
  stats = SimpleStats(solved, false, rNorms, T[], status)
  return (x, stats)
end
