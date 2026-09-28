# Replication materials

**Generative AI use and scientific literacy among Chinese adolescents: the mediating role of academic help seeking**

These scripts reproduce every table, figure and reported statistic in the article from the public PISA 2025 files. No data are included.

## Data

Download the following two SPSS files from the OECD PISA 2025 database (https://www.oecd.org/en/data/datasets/pisa-2025-database.html):

- `CY09_MS_STU_PUF.sav` (student questionnaire file)
- `CY09_MS_SCH_PUF.sav` (school questionnaire file)

Place both files in `data/`, or set the environment variable `PISA_DATA_DIR` to the folder that contains them. The analysis uses the B-S-J-Z (China) sample (country code `QCI`).

## Software

- Python 3.14 with the packages in `requirements.txt` (`pip install -r requirements.txt`)
- R 4.6.1 with WeMix 4.0.3, lavaan 0.7-2, semTools 0.5-9 and MASS 7.3-65 (`Rscript install_packages.R`)
- Figures use the Arial font.

## Running the analysis

Run the steps in order from this folder. Results are written to `output/`.

| Step | Command | Produces | Approx. time |
|---|---|---|---|
| 1 | `python scripts/01_prepare_data.py` | `bsjz_analysis.csv` (analysis file) | 1 min |
| 2 | `Rscript scripts/02_measurement.R` | CFA fit, loadings, reliability, invariance (Section 4.2) | 5 min |
| 3 | `python scripts/03_descriptives.py` | sample description, sample flow, Table 1, purpose distribution, difference-score reliability (Sections 3.1–3.3, 4.1) | 2 min |
| 4 | `Rscript scripts/04_mediation_models.R` | Table 2, Table 3, curvilinear model, Table 5, moderation by gender and ESCS (Sections 4.3, 4.5–4.7) | 30 min |
| 5 | `Rscript scripts/05_purposes.R` | Table 4 and the difference-score specifications (Section 4.4) | 35 min |
| 6 | `python scripts/06_figures.py` | Figures 1–5 (`output/figures`) | 1 min |

Steps 4 and 5 are independent and can run at the same time. `scripts/helpers.R` contains the functions shared by steps 4 and 5.

## Output files and the article

| Article | File(s) in `output/` |
|---|---|
| Table 1 | `table1_descriptives.csv`, `table1_correlations.csv` |
| Table 2, Figure 3 | `table2_main_model.csv` |
| Table 3 | `table2_main_model.csv` (main model), `table3_fixed_effects_brr.csv`, `table3_additional_covariates.csv`, `table3_excluding_low_effort.csv`, `table3_out_of_school_ai.csv` |
| Table 4, Figure 4 | `table4_purpose_ST438Q0[1-4]DA.csv`, `table4_users_entered_together.csv` |
| Table 5 | `table5_serial_mediation.csv` |
| Figure 2 | `purpose_distribution.csv` |
| Figure 5 and Section 4.7 | `quadratic_model.csv`, `quadratic_predictions.csv`, `figure5_curve.csv` |
| Section 4.4 (robustness of H5) | `h5_*.csv` |
| Section 4.6 | `rq1_gender.csv`, `rq1_escs.csv` |
| Section 4.2 | `measurement_*.csv` |
| Section 3.1 | `sample_flow.csv`, `missing_by_variable.csv` |

## Notes

- Effects in the model output are labelled as follows: `a` = GenAI use → mediator, `b` = mediator → scientific literacy, `ind` = indirect effect, `direct` and `total` = associations of GenAI use with scientific literacy. `AI`, `META`, `HELP`, `EFF` and `SCI` denote GenAI use (AIUSESCH), metacognitive strategies (GOALSET), help seeking (SELFREG), science self-efficacy (EFFSCIE) and scientific literacy (PV1–PV10SCIE). Suffixes `_w` and `_b` mark within-school and between-school components. The column `points` gives effects in PISA score points.
- Confidence intervals for indirect effects are Monte Carlo intervals (20,000 draws). With the fixed seeds in steps 4 and 5 the results are reproducible exactly; with other seeds the interval limits can differ in the third decimal.
- `W_FSTUWT` and `W_NRASCHBWT` are passed to WeMix as unconditional weights; WeMix derives the conditional within-school weights.
