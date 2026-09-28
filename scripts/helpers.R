# Shared functions for the weighted two-level mediation models (sourced by steps 4 and 5).

suppressPackageStartupMessages({ library(WeMix); library(MASS) })
OUT <- "output"
N_MC <- 20000

# analytic sample: complete data on every variable of the main, purpose and self-efficacy models
REQUIRED <- c("AIUSESCH", "ST438Q01DA", "ST438Q02DA", "ST438Q03DA", "ST438Q04DA", "GOALSET", "SELFREG",
              "EFFSCIE", "ESCS", "ST331Q03JA", "male", "grade")
CTRL <- "male + grade + ESCSz_w + EFFORT_w + ESCSz_b + EFFORT_b"

# Standardize with the student weight and split each variable into a within-school part (_w,
# deviation from the school mean) and a between-school part (_b, school mean).
# extra: additional variables as list(new_name = "column_name").
prep_data <- function(required = REQUIRED, extra = list(), subset = NULL) {
  d <- read.csv(file.path(OUT, "bsjz_analysis.csv"))
  d <- d[complete.cases(d[, unique(c(required, unlist(extra)))]), ]
  if (!is.null(subset)) d <- d[subset(d), ]
  w <- d$W_FSTUWT
  wz <- function(x) { m <- weighted.mean(x, w); (x - m) / sqrt(weighted.mean((x - m)^2, w)) }
  vars <- c(list(AI = "AIUSESCH", FREQ = "ai_freq", REL = "rel_learn", META = "GOALSET",
                 HELP = "SELFREG", ESCSz = "ESCS", EFFORT = "ST331Q03JA"), extra)
  for (nm in names(vars)) {
    d[[nm]] <- wz(d[[vars[[nm]]]])
    m <- ave(d[[nm]], d$CNTSCHID)
    d[[paste0(nm, "_w")]] <- d[[nm]] - m
    d[[paste0(nm, "_b")]] <- m
  }
  sd_pv <- numeric(10)
  for (i in 1:10) {
    pv <- d[[paste0("PV", i, "SCIE")]]
    sd_pv[i] <- sqrt(weighted.mean((pv - weighted.mean(pv, w))^2, w))
    d[[paste0("SCI", i)]] <- wz(pv)
  }
  # unconditional weights; WeMix derives the conditional within-school weights (cWeights = FALSE)
  d$w1 <- d$W_FSTUWT
  d$w2 <- d$W_NRASCHBWT
  attr(d, "sci_sd") <- mean(sd_pv)
  d
}

fit_mix <- function(rhs_formula, d) {
  m <- mix(as.formula(paste(rhs_formula, "+ (1|CNTSCHID)")), data = d, weights = c("w1", "w2"))
  list(est = m$coef, V = m$cov_mat)
}

# combine the ten plausible-value fits (Rubin's rules, full covariance matrix)
rubin <- function(fits) {
  E <- sapply(fits, `[[`, "est")
  M <- ncol(E)
  list(est = rowMeans(E), V = Reduce(`+`, lapply(fits, `[[`, "V")) / M + (1 + 1 / M) * cov(t(E)))
}
fit_pv <- function(rhs, d) rubin(lapply(1:10, function(i) fit_mix(paste0("SCI", i, " ~ ", rhs), d)))

# Monte Carlo draws of coefficients from one equation (joint normal with the pooled covariance)
draws <- function(fit, names) {
  x <- matrix(mvrnorm(N_MC, fit$est[names], fit$V[names, names, drop = FALSE]), ncol = length(names))
  colnames(x) <- names
  x
}
row_fixed <- function(label, fit, nm) {
  est <- unname(fit$est[nm]); se <- sqrt(fit$V[nm, nm])
  data.frame(effect = label, est = est, se = se, ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se)
}
row_draw <- function(label, x) {
  data.frame(effect = label, est = mean(x), se = sd(x),
             ci_lo = unname(quantile(x, 0.025)), ci_hi = unname(quantile(x, 0.975)))
}
save_table <- function(rows, file, d) {
  res <- do.call(rbind, rows); rownames(res) <- NULL
  res$points <- ifelse(grepl("SCI|^ind", res$effect), res$est * attr(d, "sci_sd"), NA)
  cat("\n##", file, "(N =", nrow(d), ")\n"); print(res, digits = 3, row.names = FALSE)
  write.csv(res, file.path(OUT, file), row.names = FALSE)
  invisible(res)
}

# parallel mediation through metacognitive strategies (META) and help seeking (HELP)
mediation <- function(d, xs, file, ctrl = CTRL) {
  xterm <- paste(c(paste0(xs, "_w"), paste0(xs, "_b")), collapse = " + ")
  aM <- fit_mix(paste("META ~", xterm, "+", ctrl), d)
  aH <- fit_mix(paste("HELP ~", xterm, "+", ctrl), d)
  y <- fit_pv(paste(xterm, "+ META_w + META_b + HELP_w + HELP_b +", ctrl), d)
  tot <- fit_pv(paste(xterm, "+", ctrl), d)
  b <- draws(y, c("META_w", "HELP_w"))
  rows <- list(row_fixed("b: META -> SCI", y, "META_w"), row_fixed("b: HELP -> SCI", y, "HELP_w"))
  for (x in paste0(xs, "_w")) {
    am <- draws(aM, x)[, 1]; ah <- draws(aH, x)[, 1]
    rows <- c(rows, list(
      row_fixed(paste("total:", x, "-> SCI"), tot, x),
      row_fixed(paste("direct:", x, "-> SCI"), y, x),
      row_fixed(paste("a:", x, "-> META"), aM, x),
      row_fixed(paste("a:", x, "-> HELP"), aH, x),
      row_draw(paste("ind:", x, "-> META -> SCI"), am * b[, "META_w"]),
      row_draw(paste("ind:", x, "-> HELP -> SCI"), ah * b[, "HELP_w"]),
      row_draw(paste("ind total:", x), am * b[, "META_w"] + ah * b[, "HELP_w"])))
  }
  save_table(rows, file, d)
}

# design-based check: school fixed effects (within-school transformation) with 80 BRR weights (Fay 0.5)
fe_brr <- function(d) {
  dm <- function(x) x - ave(x, d$CNTSCHID)
  X <- cbind(dm(d$male), dm(d$grade), d$ESCSz_w, d$EFFORT_w)
  ols <- function(y, Z, w) lm.wfit(cbind(1, Z), y, w)$coefficients[-1]
  est_once <- function(w, pv) {
    y <- dm(d[[paste0("SCI", pv)]])
    aM <- ols(d$META_w, cbind(d$AI_w, X), w)[1]; aH <- ols(d$HELP_w, cbind(d$AI_w, X), w)[1]
    by <- ols(y, cbind(d$AI_w, d$META_w, d$HELP_w, X), w); tt <- ols(y, cbind(d$AI_w, X), w)[1]
    c(total = tt, direct = by[1], a_META = aM, a_HELP = aH, b_META = by[2], b_HELP = by[3],
      ind_META = aM * by[2], ind_HELP = aH * by[3], ind_total = aM * by[2] + aH * by[3])
  }
  per_pv <- lapply(1:10, function(pv) {
    full <- est_once(d$W_FSTUWT, pv)
    reps <- sapply(1:80, function(r) est_once(d[[paste0("W_FSTURWT", r)]], pv))
    list(est = full, var = rowSums((reps - full)^2) / (80 * 0.5^2))
  })
  E <- sapply(per_pv, `[[`, "est")
  est <- rowMeans(E)
  se <- sqrt(rowMeans(sapply(per_pv, `[[`, "var")) + 1.1 * apply(E, 1, var))
  data.frame(effect = sub("\\..*$", "", names(est)), est = est, se = se,
             ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se, row.names = NULL)
}
