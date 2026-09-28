# Step 5. Purposes of GenAI use (H5): each purpose separately (Table 4, upper panel), the
# "help me learn" item and the other three purposes entered together among users (Table 4, lower
# panel), and the difference-score specifications reported in Section 4.4.
# Run from the package root:  Rscript scripts/05_purposes.R   (about 35 minutes)

source("scripts/helpers.R")
set.seed(20250902)
is_user <- function(x) x$nonuser == 0

items <- list(I1 = "ST438Q01DA", I2 = "ST438Q02DA", I3 = "ST438Q03DA", I4 = "ST438Q04DA")
d <- prep_data(extra = c(items, list(NONU = "nonuser", REL2 = "rel2")))

# Table 4, upper panel
for (k in names(items)) mediation(d, k, paste0("table4_purpose_", items[[k]], ".csv"))

# Table 4, lower panel: users only, original 1-5 scale, within-school centred
du <- prep_data(extra = list(REL2 = "rel2"), subset = is_user)
for (v in c("ST438Q04DA", "q_other")) {
  du[[paste0(v, "_w")]] <- du[[v]] - ave(du[[v]], du$CNTSCHID)
  du[[paste0(v, "_b")]] <- ave(du[[v]], du$CNTSCHID)
}
tot <- fit_pv(paste("ST438Q04DA_w + q_other_w + ST438Q04DA_b + q_other_b +", CTRL), du)
nm <- c("ST438Q04DA_w", "q_other_w")
contrast <- c(1, -1)
diff_est <- sum(contrast * tot$est[nm])
diff_se <- sqrt(as.numeric(t(contrast) %*% tot$V[nm, nm] %*% contrast))
lower <- rbind(row_fixed("help me learn (per response category)", tot, "ST438Q04DA_w"),
               row_fixed("mean of the other three purposes (per response category)", tot, "q_other_w"),
               data.frame(effect = "difference", est = diff_est, se = diff_se,
                          ci_lo = diff_est - 1.96 * diff_se, ci_hi = diff_est + 1.96 * diff_se))
lower$points <- lower$est * attr(du, "sci_sd")
lower$points_lo <- lower$ci_lo * attr(du, "sci_sd")
lower$points_hi <- lower$ci_hi * attr(du, "sci_sd")
cat("\nusers:", nrow(du), "\n"); print(lower, digits = 3, row.names = FALSE)
write.csv(lower, file.path(OUT, "table4_users_entered_together.csv"), row.names = FALSE)

# difference-score specifications (Section 4.4, robustness)
mediation(d, c("FREQ", "REL"), "h5_difference_score_all.csv")
mediation(du, c("FREQ", "REL"), "h5_difference_score_users.csv")
mediation(d, c("FREQ", "REL", "NONU"), "h5_difference_score_nonuser_indicator.csv")
mediation(du, c("FREQ", "REL2"), "h5_research_grouped_with_learning_users.csv")
