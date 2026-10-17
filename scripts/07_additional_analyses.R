# Step 7. Additional analyses added in the revision (Supplementary Tables S1-S6; Table 3, rows 5-8;
# Sections 4.3, 4.7 and 5.1).
# Run from the package root:  Rscript scripts/07_additional_analyses.R   (about 30 minutes)

source("scripts/helpers.R")
suppressPackageStartupMessages(library(mice))
set.seed(20251015)

d <- prep_data()

# ---------------------------------------------------------------- S1: all coefficients, within and between schools
xt <- "AI_w + AI_b"
eq <- list(
  "Metacognitive strategies" = fit_mix(paste("META ~", xt, "+", CTRL), d),
  "Help seeking" = fit_mix(paste("HELP ~", xt, "+", CTRL), d),
  "Scientific literacy (total)" = fit_pv(paste(xt, "+", CTRL), d),
  "Scientific literacy (full)" = fit_pv(paste(xt, "+ META_w + META_b + HELP_w + HELP_b +", CTRL), d))
coefs <- do.call(rbind, lapply(names(eq), function(k) {
  f <- eq[[k]]; se <- sqrt(diag(f$V))[names(f$est)]
  data.frame(equation = k, term = names(f$est), est = f$est, se = se,
             ci_lo = f$est - 1.96 * se, ci_hi = f$est + 1.96 * se, row.names = NULL)
}))
write.csv(coefs, file.path(OUT, "s1_all_coefficients.csv"), row.names = FALSE)
aMb <- draws(eq[[1]], "AI_b")[, 1]; aHb <- draws(eq[[2]], "AI_b")[, 1]
bb <- draws(eq[[4]], c("META_b", "HELP_b"))
save_table(list(
  row_fixed("between total: AI_b -> SCI", eq[[3]], "AI_b"),
  row_fixed("between direct: AI_b -> SCI", eq[[4]], "AI_b"),
  row_fixed("between a: AI_b -> META", eq[[1]], "AI_b"),
  row_fixed("between a: AI_b -> HELP", eq[[2]], "AI_b"),
  row_draw("between ind: AI_b -> META -> SCI", aMb * bb[, "META_b"]),
  row_draw("between ind: AI_b -> HELP -> SCI", aHb * bb[, "HELP_b"])
), "s1_between_school_indirect.csv", d)

# ---------------------------------------------------------------- S2: three-item help seeking
d3 <- prep_data(required = c(REQUIRED, "help3"), extra = list(H3 = "help3"))
w3 <- d3$W_FSTUWT
cat("\nthree-item score: r with SELFREG =",
    round(cov.wt(cbind(d3$help3, d3$SELFREG), wt = w3, cor = TRUE)$cor[1, 2], 3), "\n")
d3$HELP_w <- d3$H3_w; d3$HELP_b <- d3$H3_b
mediation(d3, "AI", "s2_help_three_items.csv")

# ---------------------------------------------------------------- S3: reverse order (help seeking -> GenAI use)
aA <- fit_mix(paste("AI ~ HELP_w + HELP_b + META_w + META_b +", CTRL), d)
yR <- fit_pv(paste("HELP_w + HELP_b + AI_w + AI_b + META_w + META_b +", CTRL), d)
tR <- fit_pv(paste("HELP_w + HELP_b + META_w + META_b +", CTRL), d)
save_table(list(
  row_fixed("a: HELP_w -> AI", aA, "HELP_w"),
  row_fixed("b: AI_w -> SCI", yR, "AI_w"),
  row_draw("ind: HELP_w -> AI -> SCI", draws(aA, "HELP_w")[, 1] * draws(yR, "AI_w")[, 1]),
  row_fixed("direct: HELP_w -> SCI", yR, "HELP_w"),
  row_fixed("total: HELP_w -> SCI", tR, "HELP_w")
), "s3_reverse_order.csv", d)

# ---------------------------------------------------------------- S4: mathematics and reading
mediation(use_domain(d, "MATH"), "AI", "s4_mathematics.csv")
mediation(use_domain(d, "READ"), "AI", "s4_reading.csv")

# ---------------------------------------------------------------- S6: why the bivariate association is zero
one_level <- function(w, pv) {
  y <- d[[paste0("SCI", pv)]]
  b <- function(...) lm.wfit(cbind(1, ...), y, w)$coefficients
  c(no_controls = b(d$AI)[2],
    escs = b(d$AI, d$ESCSz)[2],
    escs_and_covariates = b(d$AI, d$ESCSz, d$male, d$grade, d$EFFORT)[2],
    within = b(d$AI_w, d$AI_b)[2], between = b(d$AI_w, d$AI_b)[3],
    within_escs = b(d$AI_w, d$AI_b, d$ESCSz_w, d$ESCSz_b)[2],
    between_escs = b(d$AI_w, d$AI_b, d$ESCSz_w, d$ESCSz_b)[3])
}
brr_pool <- function(fun, data, pvs = 1:10) {
  per <- lapply(pvs, function(pv) {
    full <- fun(data$W_FSTUWT, pv)
    reps <- sapply(1:80, function(r) fun(data[[paste0("W_FSTURWT", r)]], pv))
    list(est = full, var = rowSums((reps - full)^2) / (80 * 0.5^2))
  })
  E <- sapply(per, `[[`, "est")
  est <- rowMeans(E)
  se <- sqrt(rowMeans(sapply(per, `[[`, "var")) + (1 + 1 / ncol(E)) * apply(E, 1, var))
  data.frame(effect = sub("\\..*$", "", names(est)), est = est, se = se,
             ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se, row.names = NULL)
}
s6 <- brr_pool(one_level, d)
s6$points <- s6$est * attr(d, "sci_sd")
print(s6, digits = 3)
write.csv(s6, file.path(OUT, "s6_single_level_associations.csv"), row.names = FALSE)

# ---------------------------------------------------------------- S5: multiple imputation (all students)
all_students <- read.csv(file.path(OUT, "bsjz_analysis.csv"))
all_students$pv_mean <- rowMeans(all_students[, paste0("PV", 1:10, "SCIE")])
all_students$pv_school <- ave(all_students$pv_mean, all_students$CNTSCHID)
all_students$escs_school <- ave(all_students$ESCS, all_students$CNTSCHID, FUN = function(x) mean(x, na.rm = TRUE))
imp_vars <- c("AIUSESCH", "GOALSET", "SELFREG", "EFFSCIE", "ESCS", "ST331Q03JA", "grade", "male",
              "pv_mean", "pv_school", "escs_school")
imp <- mice(all_students[, imp_vars], m = 10, method = "pmm", printFlag = FALSE)
fe_one <- function(x, w, pv) {
  wz <- function(v) { m <- weighted.mean(v, w); (v - m) / sqrt(weighted.mean((v - m)^2, w)) }
  dm <- function(v) v - ave(v, all_students$CNTSCHID)
  ols <- function(y, Z) lm.wfit(cbind(1, Z), y, w)$coefficients[-1]
  AI <- dm(wz(x$AIUSESCH)); M <- dm(wz(x$GOALSET)); H <- dm(wz(x$SELFREG))
  X <- cbind(dm(x$male), dm(x$grade), dm(wz(x$ESCS)), dm(wz(x$ST331Q03JA)))
  y <- dm(wz(pv))
  aM <- ols(M, cbind(AI, X))[1]; aH <- ols(H, cbind(AI, X))[1]
  by <- ols(y, cbind(AI, M, H, X)); tt <- ols(y, cbind(AI, X))[1]
  c(total = tt, direct = by[1], a_META = aM, a_HELP = aH, b_META = by[2], b_HELP = by[3],
    ind_META = aM * by[2], ind_HELP = aH * by[3], ind_total = aM * by[2] + aH * by[3])
}
res <- list()
for (k in 1:10) {
  x <- complete(imp, k)
  for (pv in 1:10) {
    y <- all_students[[paste0("PV", pv, "SCIE")]]
    full <- fe_one(x, all_students$W_FSTUWT, y)
    reps <- sapply(1:80, function(r) fe_one(x, all_students[[paste0("W_FSTURWT", r)]], y))
    res[[length(res) + 1]] <- list(est = full, var = rowSums((reps - full)^2) / (80 * 0.5^2))
  }
}
E <- sapply(res, `[[`, "est")
est <- rowMeans(E)
se <- sqrt(rowMeans(sapply(res, `[[`, "var")) + (1 + 1 / ncol(E)) * apply(E, 1, var))
s5 <- data.frame(effect = sub("\\..*$", "", names(est)), est = est, se = se,
                 ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se, row.names = NULL)
cat("\n## multiple imputation, N =", nrow(all_students), "\n"); print(s5, digits = 3)
write.csv(s5, file.path(OUT, "s5_multiple_imputation.csv"), row.names = FALSE)
