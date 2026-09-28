# Step 2. Measurement models (Section 4.2): ordinal four-factor CFA, reliability,
# measurement invariance across gender, single-factor comparison model.
# Run from the package root:  Rscript scripts/02_measurement.R

suppressPackageStartupMessages({ library(lavaan); library(semTools) })
out <- "output"
d <- read.csv(file.path(out, "bsjz_analysis.csv"))

AI   <- c("ST438Q01DA", "ST438Q02DA", "ST438Q03DA", "ST438Q04DA")
META <- c("ST432Q02DA", "ST432Q03DA", "ST432Q04DA", "ST432Q06DA")
HELP <- c("ST433Q01DA", "ST433Q02DA", "ST433Q04DA", "ST433Q06DA")
EFF  <- c("ST129Q03TA", "ST129Q05TA", "ST129Q08DA", "ST129Q11DA", "ST129Q12DA", "ST129Q14DA")
items <- c(AI, META, HELP, EFF)

# higher values = more of the construct (ST433: 1 = strongly agree; ST129: 1 = easily)
for (v in c(HELP, EFF)) d[[v]] <- 5 - d[[v]]
d$sex <- ifelse(d$male == 1, "male", "female")

model <- paste0("AI =~ ", paste(AI, collapse = " + "), "\n",
                "META =~ ", paste(META, collapse = " + "), "\n",
                "HELP =~ ", paste(HELP, collapse = " + "), "\n",
                "EFF =~ ", paste(EFF, collapse = " + "))
fit_idx <- c("cfi.scaled", "tli.scaled", "rmsea.scaled", "srmr")

cfa4 <- cfa(model, data = d, ordered = items, estimator = "WLSMV", sampling.weights = "W_FSTUWT")
cfa1 <- cfa(paste("F =~", paste(items, collapse = " + ")), data = d, ordered = items,
            estimator = "WLSMV", sampling.weights = "W_FSTUWT")
fits <- rbind(four_factor = fitMeasures(cfa4, fit_idx), one_factor = fitMeasures(cfa1, fit_idx))
print(round(fits, 3))
write.csv(round(fits, 3), file.path(out, "measurement_fit.csv"))

std <- standardizedSolution(cfa4)
load <- std[std$op == "=~", c("lhs", "rhs", "est.std")]
names(load) <- c("factor", "item", "loading")
print(load, digits = 2, row.names = FALSE)
write.csv(load, file.path(out, "measurement_loadings.csv"), row.names = FALSE)
write.csv(round(lavInspect(cfa4, "cor.lv"), 3), file.path(out, "measurement_latent_correlations.csv"))

alpha <- function(v) {
  x <- na.omit(d[, v]); k <- length(v)
  k / (k - 1) * (1 - sum(apply(x, 2, var)) / var(rowSums(x)))
}
rel <- data.frame(scale = c("AI", "META", "HELP", "EFF"),
                  alpha = sapply(list(AI, META, HELP, EFF), alpha),
                  omega = unname(unlist(compRelSEM(cfa4))[c("AI", "META", "HELP", "EFF")]))
print(rel, digits = 3)
write.csv(rel, file.path(out, "measurement_reliability.csv"), row.names = FALSE)

ev <- eigen(cor(d[, items], use = "pairwise.complete.obs"))$values
cat("first unrotated component:", round(100 * ev[1] / sum(ev), 1), "% of item variance\n")

# invariance across gender for ordinal indicators (Wu and Estabrook, 2016)
steps <- list(configural = NULL, thresholds = "thresholds", metric = c("thresholds", "loadings"),
              scalar = c("thresholds", "loadings", "intercepts"))
inv <- t(sapply(steps, function(eq) {
  syn <- measEq.syntax(configural.model = model, data = d, ordered = items, parameterization = "delta",
                       ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016", group = "sex", group.equal = eq)
  fitMeasures(cfa(as.character(syn), data = d, ordered = items, estimator = "WLSMV", group = "sex",
                  sampling.weights = "W_FSTUWT"), fit_idx)
}))
print(round(inv, 3))
write.csv(round(inv, 3), file.path(out, "measurement_invariance_gender.csv"))
