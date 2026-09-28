"""
Step 3. Sample description, analytic sample, index composition, Table 1 (with BRR significance),
distribution of the four purposes (Figure 2), and reliability of the difference score.
Requires output/bsjz_analysis.csv (step 1) and output/measurement_loadings.csv (step 2).
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output"
full = pd.read_csv(OUT / "bsjz_analysis.csv").copy()

AI = ["ST438Q01DA", "ST438Q02DA", "ST438Q03DA", "ST438Q04DA"]
PVS = [f"PV{i}SCIE" for i in range(1, 11)]
REPS = [f"W_FSTURWT{r}" for r in range(1, 81)]
REQUIRED = ["AIUSESCH"] + AI + ["GOALSET", "SELFREG", "EFFSCIE", "ESCS", "ST331Q03JA", "male", "grade"]


def wmean(x, w):
    return np.average(x, weights=w)


def wsd(x, w):
    return np.sqrt(np.average((x - wmean(x, w)) ** 2, weights=w))


def wcor(x, y, w):
    mx, my = wmean(x, w), wmean(y, w)
    return np.average((x - mx) * (y - my), weights=w) / np.sqrt(
        np.average((x - mx) ** 2, weights=w) * np.average((y - my) ** 2, weights=w))


def pct(mask, w):
    return 100 * w[mask].sum() / w.sum()


# ---------------------------------------------------------------- sample (Section 3.1)
w = full["W_FSTUWT"]
print(f"students {len(full)}, schools {full['CNTSCHID'].nunique()}, "
      f"median students per school {full.groupby('CNTSCHID').size().median():.0f}")
print(f"female {pct(full['ST004D01T'] == 1, w):.1f}%, age {wmean(full['AGE'].dropna(), w[full['AGE'].notna()]):.2f} "
      f"(SD {full['AGE'].std():.2f}), grades {full.groupby('ST001D01T')['W_FSTUWT'].sum().div(w.sum()).mul(100).round(1).to_dict()}")

missing = full[REQUIRED].isna().mean().mul(100).round(2)
flow = [("B-S-J-Z student file", len(full))]
keep = pd.Series(True, index=full.index)
for v in REQUIRED:
    keep &= full[v].notna()
    flow.append((f"non-missing {v}", int(keep.sum())))
pd.DataFrame(flow, columns=["step", "n"]).to_csv(OUT / "sample_flow.csv", index=False)
missing.rename("pct_missing").to_csv(OUT / "missing_by_variable.csv")
print("missing (%):", missing.to_dict())
d = full[keep].reset_index(drop=True)
wd = d["W_FSTUWT"].to_numpy()
print(f"analytic sample: {len(d)} students ({100 * len(d) / len(full):.1f}%), {d['CNTSCHID'].nunique()} schools")


def icc(v):
    x = full[["CNTSCHID", v]].dropna()
    g = x.groupby("CNTSCHID")[v]
    n, k, N = g.size(), g.ngroups, len(x)
    msb = (n * (g.mean() - x[v].mean()) ** 2).sum() / (k - 1)
    msw = ((x[v] - g.transform("mean")) ** 2).sum() / (N - k)
    n0 = (N - (n ** 2).sum() / N) / (k - 1)
    s2b = (msb - msw) / n0
    return s2b / (s2b + msw)


full["sci_mean"] = full[PVS].mean(axis=1)
print(f"ICC scientific literacy {icc('sci_mean'):.2f}, ICC ESCS {icc('ESCS'):.2f}")

# ---------------------------------------------------------------- index composition (Section 3.2.3)
def r2(index, items):
    x = full.dropna(subset=[index] + items)
    X = np.column_stack([np.ones(len(x)), x[items]])
    b = np.linalg.lstsq(X, x[index], rcond=None)[0]
    return 1 - np.var(x[index] - X @ b) / np.var(x[index])


print(f"R2 GOALSET ~ ST432 items: {r2('GOALSET', ['ST432Q02DA', 'ST432Q03DA', 'ST432Q04DA', 'ST432Q06DA']):.3f}; "
      f"R2 SELFREG ~ ST433 items: {r2('SELFREG', ['ST433Q01DA', 'ST433Q02DA', 'ST433Q04DA', 'ST433Q06DA']):.3f}")

# ---------------------------------------------------------------- purposes (Section 4.1, Figure 2)
labels = {"ST438Q01DA": "Summarize a text I had to read", "ST438Q02DA": "Research a new topic",
          "ST438Q03DA": "Draft texts for writing assignments", "ST438Q04DA": "Help me learn"}
dist = pd.DataFrame({labels[i]: [pct(d[i] == k, pd.Series(wd)) for k in range(1, 6)] for i in AI},
                    index=["never", "yearly", "monthly", "weekly", "daily"]).T
dist.round(2).to_csv(OUT / "purpose_distribution.csv")
print(dist.round(1))
print(f"non-users {pct(d['nonuser'] == 1, pd.Series(wd)):.1f}%; "
      f"item correlations {d[AI].corr().values[np.triu_indices(4, 1)].min():.2f} to "
      f"{d[AI].corr().values[np.triu_indices(4, 1)].max():.2f}")


def share_among_answered(var, value):
    answered = full[var].notna()
    return pct(full.loc[answered, var] == value, w[answered])


print(f"AI resources not available at school: {share_among_answered('IC170Q10DA', 6):.0f}%; "
      f"never asked to assess AI-generated information: {share_among_answered('ST436Q16DA', 1):.0f}%")
print(f"out-of-school AI item answered by {100 * full['IC171Q10DA'].notna().mean():.0f}%, "
      f"'not available outside school': {share_among_answered('IC171Q10DA', 6):.0f}%")

# ---------------------------------------------------------------- difference-score reliability (Section 3.3.3)
def alpha(X):
    X = np.asarray(X, float)
    k = X.shape[1]
    return k / (k - 1) * (1 - X.var(axis=0, ddof=1).sum() / X.sum(axis=1).var(ddof=1))


def diff_reliability(x, y, rx, ry):
    sx, sy, sxy = x.var(ddof=1), y.var(ddof=1), np.cov(x, y)[0, 1]
    return (sx * rx + sy * ry - 2 * sxy) / (sx + sy - 2 * sxy)


loadings = pd.read_csv(OUT / "measurement_loadings.csv").set_index("item")["loading"]
r_q4 = loadings["ST438Q04DA"] ** 2          # single-item reliability approximated by its communality
for name, sub in (("all students", d), ("users", d[d["nonuser"] == 0])):
    rel = diff_reliability(sub["ST438Q04DA"], sub["q_other"], r_q4, alpha(sub[AI[:3]]))
    print(f"reliability of the difference score, {name}: {rel:.2f}")

# ---------------------------------------------------------------- Table 1
VARS = {"AIUSESCH": "GenAI use", "GOALSET": "Metacognitive strategies", "SELFREG": "Help seeking",
        "EFFSCIE": "Science self-efficacy", "ESCS": "ESCS", "ST331Q03JA": "Questionnaire effort",
        "male": "Male", "rel_learn": "Help me learn relative to other uses"}
REP = d[REPS].to_numpy()


def brr_cor(x, y):
    est = wcor(x, y, wd)
    reps = np.array([wcor(x, y, REP[:, r]) for r in range(80)])
    return est, np.sum((reps - est) ** 2) / (80 * 0.5 ** 2)


names = list(VARS) + ["SCIE"]
rows = []
for i, a in enumerate(names):
    for b in names[:i]:
        if a == "SCIE":
            ests, vs = zip(*[brr_cor(d[b].to_numpy(), d[p].to_numpy()) for p in PVS])
            est, se = np.mean(ests), np.sqrt(np.mean(vs) + 1.1 * np.var(ests, ddof=1))
        else:
            est, v = brr_cor(d[a].to_numpy(), d[b].to_numpy())
            se = np.sqrt(v)
        rows.append((a, b, est, se, abs(est / se) > 1.96))
cors = pd.DataFrame(rows, columns=["variable", "with", "r", "se_brr", "significant_05"])
cors.round(3).to_csv(OUT / "table1_correlations.csv", index=False)

desc = pd.DataFrame({"M": [wmean(d[v], wd) for v in VARS] + [np.mean([wmean(d[p], wd) for p in PVS])],
                     "SD": [wsd(d[v], wd) for v in VARS] + [np.mean([wsd(d[p], wd) for p in PVS])]},
                    index=list(VARS.values()) + ["Scientific literacy"])
desc.round(2).to_csv(OUT / "table1_descriptives.csv")
print(desc.round(2))
print(cors[~cors["significant_05"]][["variable", "with", "r"]].round(3).to_string(index=False))
