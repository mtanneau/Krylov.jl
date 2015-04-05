cgne_tol = 1.0e-4;  # We're tolerant just so random tests don't fail.

function test_cgne(A, b; λ=0.0)
  (nrow, ncol) = size(A);
  (x, stats) = cgne(A, b, λ=λ);
  r = b - A * x;
  if λ > 0
    s = r / sqrt(λ);
    r = r - sqrt(λ) * s;
  end
  resid = norm(r) / norm(b);
  @printf("CGNE: residual: %7.1e\n", resid);
  return (x, stats, resid)
end

function check_min_norm(A, b, x; λ=0.0)
  (nrow, ncol) = size(A);
  if λ > 0.0
    AI = [A sqrt(λ)*eye(nrow)];
    xI = [x ; (b-A*x)/sqrt(λ)];
  else
    AI = A;
    xI = x;
  end
  xmin = AI' * ((AI * AI') \ b);
  xmin_norm = norm(xmin);
  @printf("CGNE: ‖x - xmin‖ = %7.1e\n", norm(xI - xmin));
  return (xI, xmin, xmin_norm)
end

# Underdetermined consistent.
A = rand(10, 25); b = A * ones(25);
(x, stats, resid) = test_cgne(A, b);
@test(resid <= cgne_tol);
@test(stats.solved);
(xI, xmin, xmin_norm) = check_min_norm(A, b, x);
@test(norm(xI - xmin) <= cond(A) * cgne_tol * xmin_norm);

# Underdetermined inconsistent.
A = ones(10, 25); b = rand(10); b[1] = -1.0;
(x, stats, resid) = test_cgne(A, b);
@test(stats.inconsistent);

# Square consistent.
A = rand(10, 10); b = A * ones(10);
(x, stats, resid) = test_cgne(A, b);
@test(resid <= cgne_tol);
@test(stats.solved);
(xI, xmin, xmin_norm) = check_min_norm(A, b, x);
@test(norm(xI - xmin) <= cond(A) * cgne_tol * xmin_norm);

# Square inconsistent.
A = ones(10, 10); b = rand(10); b[1] = -1.0;
(x, stats, resid) = test_cgne(A, b);
@test(stats.inconsistent);

# Overdetermined consistent.
A = rand(25, 10); b = A * ones(10);
(x, stats, resid) = test_cgne(A, b);
@test(resid <= cgne_tol);
@test(stats.solved);
(xI, xmin, xmin_norm) = check_min_norm(A, b, x);
@test(norm(xI - xmin) <= cond(A) * cgne_tol * xmin_norm);

# Overdetermined inconsistent.
A = ones(5, 3); b = rand(5); b[1] = -1.0;
(x, stats, resid) = test_cgne(A, b);
@test(stats.inconsistent);

# With regularization, all systems are underdetermined and consistent.
(x, stats, resid) = test_cgne(A, b, λ=1.0e-3);
@test(resid <= cgne_tol);
@test(stats.solved);
(xI, xmin, xmin_norm) = check_min_norm(A, b, x, λ=1.0e-3);
@test(norm(xI - xmin) <= cond(A) * cgne_tol * xmin_norm);

