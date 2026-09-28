# Step 4. Main mediation model (Table 2), robustness checks (Table 3, curvilinear model and Figure 5
# data), serial mediation through science self-efficacy (Table 5), and moderation by gender and ESCS.
# Run from the package root:  Rscript scripts/04_mediation_models.R   (about 30 minutes)

source("scripts/helpers.R")
set.seed(20250901)

d <- prep_data()
cat("analytic sample:", nrow(d), "students in", length(unique(d$CNTSCHID)), "schools\n")

# ---------------------------------------------------------------- Table 2: H1-H4
main <- mediation(d, "AI", "table2_main_model.csv")

# ---------------------------------------------------------------- Table 3: robustness
brr <- fe_brr(d)
brr$points <- ifelse(grepl("^a_", brr$effect), NA, brr$est * attr(d, "sci_sd"))
write.csv(brr, file.path(OUT, "table3_fixed_effects_brr.csv"), row.names = FALSE)
print(brr, digits = 3)

d_cov <- prep_data(required = c(REQUIRED, "PERSEV", "FAMSUP"), extra = list(PERS = "PERSEV", FAM = "FAMSUP"))
mediation(d_cov, "AI", "table3_additional_covariates.csv",
          ctrl = paste(CTRL, "+ PERS_w + PERS_b + FAM_w + FAM_b"))

# exclude the 10% of students (weighted) with the lowest questionnaire effort
all_students <- read.csv(file.path(OUT, "bsjz_analysis.csv"))
e <- all_students[!is.na(all_students$ST331Q03JA), c("ST331Q03JA", "W_FSTUWT")]
e <- e[order(e$ST331Q03JA), ]
cutoff <- e$ST331Q03JA[which(cumsum(e$W_FSTUWT) / sum(e$W_FSTUWT) >= 0.10)[1]]
cat("\nexcluding questionnaire effort below", cutoff, "\n")
mediation(prep_data(subset = function(x) x$ST331Q03JA >= cutoff), "AI", "table3_excluding_low_effort.csv")

# exploratory contrast: AI tool use outside school
d_out <- prep_data(required = c(REQUIRED, "ai_outside"), extra = list(OUTAI = "ai_outside"))
mediation(d_out, "OUTAI", "table3_out_of_school_ai.csv")

# ---------------------------------------------------------------- curvilinear model (Section 4.7, Figure 5)
d$AI_w2 <- d$AI_w^2
q <- fit_pv(paste("AI_w + AI_w2 + AI_b +", CTRL), d)
b <- q$est[c("AI_w", "AI_w2")]
V <- q$V[c("AI_w", "AI_w2"), c("AI_w", "AI_w2")]
sd_pts <- attr(d, "sci_sd")
predict_diff <- function(x0, x1 = 0) {             # predicted f(x0) - f(x1), in SD and PISA points
  g <- c(x0 - x1, x0^2 - x1^2)
  est <- sum(g * b); se <- sqrt(as.numeric(t(g) %*% V %*% g))
  c(x = x0, reference = x1, est = est, ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se,
    points = est * sd_pts, points_lo = (est - 1.96 * se) * sd_pts, points_hi = (est + 1.96 * se) * sd_pts)
}
peak <- unname(-b[1] / (2 * b[2]))
quad <- rbind(row_fixed("linear", q, "AI_w"), row_fixed("quadratic", q, "AI_w2"))
write.csv(quad, file.path(OUT, "quadratic_model.csv"), row.names = FALSE)
pts <- as.data.frame(rbind(predict_diff(-1), predict_diff(1), predict_diff(2)))
write.csv(pts, file.path(OUT, "quadratic_predictions.csv"), row.names = FALSE)
w <- d$W_FSTUWT
share_above <- function(k) 100 * sum(w[d$AI_w > k]) / sum(w)
cat("\nquadratic model:\n"); print(quad, digits = 3)
cat("peak at", round(peak, 2), "SD; students above +1 SD:", round(share_above(1), 1),
    "%, above +2 SD:", round(share_above(2), 1), "%\n")
print(round(pts, 3))
wq <- function(p) { o <- order(d$AI_w); d$AI_w[o][which(cumsum(w[o]) / sum(w) >= p)[1]] }
grid <- seq(wq(0.01), wq(0.99), length.out = 200)
curve <- as.data.frame(t(sapply(grid, predict_diff)))
write.csv(curve[, c("x", "points", "points_lo", "points_hi")], file.path(OUT, "figure5_curve.csv"), row.names = FALSE)

# ---------------------------------------------------------------- Table 5: serial mediation (H6)
d6 <- prep_data(extra = list(EFF = "EFFSCIE"))
xt <- "AI_w + AI_b"
aM <- fit_mix(paste("META ~", xt, "+", CTRL), d6)
aH <- fit_mix(paste("HELP ~", xt, "+", CTRL), d6)
aE <- fit_mix(paste("EFF ~", xt, "+ META_w + META_b + HELP_w + HELP_b +", CTRL), d6)
y6 <- fit_pv(paste(xt, "+ META_w + META_b + HELP_w + HELP_b + EFF_w + EFF_b +", CTRL), d6)
am <- draws(aM, "AI_w")[, 1]; ah <- draws(aH, "AI_w")[, 1]
de <- draws(aE, c("AI_w", "META_w", "HELP_w")); by <- draws(y6, c("META_w", "HELP_w", "EFF_w"))
save_table(list(
  row_fixed("a: AI_w -> HELP", aH, "AI_w"), row_fixed("a: AI_w -> META", aM, "AI_w"),
  row_fixed("a: AI_w -> EFF", aE, "AI_w"), row_fixed("d: HELP -> EFF", aE, "HELP_w"),
  row_fixed("d: META -> EFF", aE, "META_w"), row_fixed("b: HELP -> SCI", y6, "HELP_w"),
  row_fixed("b: META -> SCI", y6, "META_w"), row_fixed("b: EFF -> SCI", y6, "EFF_w"),
  row_fixed("direct: AI_w -> SCI", y6, "AI_w"),
  row_draw("ind: AI -> HELP -> SCI", ah * by[, "HELP_w"]),
  row_draw("ind: AI -> META -> SCI", am * by[, "META_w"]),
  row_draw("ind: AI -> EFF -> SCI", de[, "AI_w"] * by[, "EFF_w"]),
  row_draw("ind: AI -> HELP -> EFF -> SCI", ah * de[, "HELP_w"] * by[, "EFF_w"]),
  row_draw("ind: AI -> META -> EFF -> SCI", am * de[, "META_w"] * by[, "EFF_w"])
), "table5_serial_mediation.csv", d6)

# ---------------------------------------------------------------- RQ1: moderation by gender and ESCS
moderation <- function(d, mod, values, file) {
  aM <- fit_mix(paste0("META ~ AI_w*", mod, " + AI_b + ", CTRL), d)
  aH <- fit_mix(paste0("HELP ~ AI_w*", mod, " + AI_b + ", CTRL), d)
  y <- fit_pv(paste0("AI_w*", mod, " + META_w*", mod, " + HELP_w*", mod, " + AI_b + META_b + HELP_b + ", CTRL), d)
  term <- function(fit, v) {                        # R labels the interaction in order of first appearance
    cand <- c(paste0(v, ":", mod), paste0(mod, ":", v))
    cand[cand %in% names(fit$est)][1]
  }
  A_M <- draws(aM, c("AI_w", term(aM, "AI_w"))); A_H <- draws(aH, c("AI_w", term(aH, "AI_w")))
  Y <- draws(y, c("AI_w", term(y, "AI_w"), "META_w", term(y, "META_w"), "HELP_w", term(y, "HELP_w")))
  at <- function(m) list(ind_META = (A_M[, 1] + A_M[, 2] * m) * (Y[, 3] + Y[, 4] * m),
                         ind_HELP = (A_H[, 1] + A_H[, 2] * m) * (Y[, 5] + Y[, 6] * m),
                         direct = Y[, 1] + Y[, 2] * m)
  rows <- list(row_fixed(paste("interaction: AI x", mod, "-> META"), aM, term(aM, "AI_w")),
               row_fixed(paste("interaction: AI x", mod, "-> HELP"), aH, term(aH, "AI_w")),
               row_fixed(paste("interaction: META x", mod, "-> SCI"), y, term(y, "META_w")),
               row_fixed(paste("interaction: HELP x", mod, "-> SCI"), y, term(y, "HELP_w")),
               row_fixed(paste("interaction: AI x", mod, "-> SCI (direct)"), y, term(y, "AI_w")))
  cond <- lapply(values, at)
  for (k in seq_along(values)) rows <- c(rows, list(
    row_draw(paste0("ind META at ", mod, " = ", values[k]), cond[[k]]$ind_META),
    row_draw(paste0("ind HELP at ", mod, " = ", values[k]), cond[[k]]$ind_HELP),
    row_draw(paste0("direct at ", mod, " = ", values[k]), cond[[k]]$direct)))
  hi <- cond[[length(values)]]; lo <- cond[[1]]
  rows <- c(rows, list(row_draw("difference ind META (highest - lowest)", hi$ind_META - lo$ind_META),
                       row_draw("difference ind HELP (highest - lowest)", hi$ind_HELP - lo$ind_HELP),
                       row_draw("difference direct (highest - lowest)", hi$direct - lo$direct)))
  save_table(rows, file, d)
}
moderation(d, "male", c(0, 1), "rq1_gender.csv")
moderation(d, "ESCSz_w", c(-1, 0, 1), "rq1_escs.csv")
