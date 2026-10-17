"""
Step 8. Checks added in the revision (Sections 3.2 and 4.1):
  - students excluded for missing data compared with the analytic sample
  - assessing AI-generated information in lessons (ST436Q16DA) and AI tools at school (IC170Q10DA)
Weighted estimates with BRR standard errors (80 replicates, Fay's factor 0.5).
Run from the package root:  python scripts/08_sample_checks.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

OUT = Path(__file__).resolve().parents[1] / "output"
REQUIRED = ["AIUSESCH", "ST438Q01DA", "ST438Q02DA", "ST438Q03DA", "ST438Q04DA", "GOALSET", "SELFREG",
            "EFFSCIE", "ESCS", "ST331Q03JA", "male", "grade"]
REPS = [f"W_FSTURWT{r}" for r in range(1, 81)]

d = pd.read_csv(OUT / "bsjz_analysis.csv")
excluded = d[REQUIRED].isna().any(axis=1)


def brr(stat):
    full = stat(d["W_FSTUWT"])
    reps = np.array([stat(d[r]) for r in REPS])
    return full, np.sqrt(((reps - full) ** 2).sum() / (80 * 0.5 ** 2))


def mean_diff(col):
    def stat(w):
        ok = d[col].notna()
        m = lambda grp: np.average(d.loc[ok & grp, col], weights=w[ok & grp])
        return m(excluded) - m(~excluded)
    return stat


rows = []
pv = [brr(mean_diff(f"PV{i}SCIE")) for i in range(1, 11)]
est = np.mean([p[0] for p in pv])
se = np.sqrt(np.mean([p[1] ** 2 for p in pv]) + 1.1 * np.var([p[0] for p in pv], ddof=1))
rows.append(("scientific literacy (points)", est, se))
for col in ["AIUSESCH", "GOALSET", "SELFREG", "EFFSCIE", "ESCS", "male"]:
    rows.append((col, *brr(mean_diff(col))))
miss = pd.DataFrame(rows, columns=["variable", "excluded_minus_analytic", "se"])
print(f"excluded: {excluded.sum()} students ({100 * d.W_FSTUWT[excluded].sum() / d.W_FSTUWT.sum():.1f}% weighted)")
print(miss.round(3).to_string(index=False))
miss.to_csv(OUT / "missing_data_comparison.csv", index=False)

a = d[~excluded].copy()
a.loc[~a["ST436Q16DA"].between(1, 4), "ST436Q16DA"] = np.nan
a.loc[a["IC170Q10DA"] > 6, "IC170Q10DA"] = np.nan


def share(col, value):
    def stat(w):
        ok = a[col].notna()
        return 100 * w[ok & (a[col] == value)].sum() / w[ok].sum()
    full = stat(a["W_FSTUWT"])
    reps = np.array([stat(a[r]) for r in REPS])
    return full, np.sqrt(((reps - full) ** 2).sum() / (80 * 0.5 ** 2))


labels = {"ST436Q16DA": {1: "never or almost never", 2: "sometimes", 3: "often", 4: "very often"},
          "IC170Q10DA": {6: "not available at school", 1: "never or almost never", 2: "once or twice a month",
                         3: "once or twice a week", 4: "every day or almost every day", 5: "several times a day"}}
ctx = pd.DataFrame([(col, lab, int(a[col].notna().sum()), *share(col, v))
                    for col, cats in labels.items() for v, lab in cats.items()],
                   columns=["item", "category", "n", "percent", "se"])
print(ctx.round(1).to_string(index=False))
ctx.to_csv(OUT / "ai_at_school.csv", index=False)
