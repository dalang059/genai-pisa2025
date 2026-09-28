"""
Step 1. Build the analysis file for B-S-J-Z (China) from the PISA 2025 public-use files.

Input (not distributed; download from the OECD PISA 2025 database):
    CY09_MS_STU_PUF.sav  student questionnaire file
    CY09_MS_SCH_PUF.sav  school questionnaire file
The folder containing both files is taken from the environment variable PISA_DATA_DIR,
or defaults to <package>/data.

Output:
    output/bsjz_analysis.csv  one row per B-S-J-Z student
"""
import os
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat

ROOT = Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get("PISA_DATA_DIR", ROOT / "data"))
OUT = ROOT / "output"
OUT.mkdir(exist_ok=True)

COUNTRY = "QCI"  # B-S-J-Z (China)
AI = ["ST438Q01DA", "ST438Q02DA", "ST438Q03DA", "ST438Q04DA"]    # summarize, research, draft, help me learn
META = ["ST432Q02DA", "ST432Q03DA", "ST432Q04DA", "ST432Q06DA"]  # index GOALSET
HELP = ["ST433Q01DA", "ST433Q02DA", "ST433Q04DA", "ST433Q06DA"]  # index SELFREG
EFF = ["ST129Q03TA", "ST129Q05TA", "ST129Q08DA", "ST129Q11DA", "ST129Q12DA", "ST129Q14DA"]
PVS = [f"PV{i}SCIE" for i in range(1, 11)]
REPS = [f"W_FSTURWT{r}" for r in range(1, 81)]
STUDENT_VARS = (["CNT", "CNTSCHID", "CNTSTUID", "W_FSTUWT", "ST004D01T", "ST001D01T", "AGE", "ESCS",
                 "ST331Q03JA", "AIUSESCH", "GOALSET", "SELFREG", "EFFSCIE", "PERSEV", "FAMSUP",
                 "IC170Q10DA", "IC171Q10DA", "ST436Q16DA"] + AI + META + HELP + EFF + PVS + REPS)

stu, _ = pyreadstat.read_sav(DATA / "CY09_MS_STU_PUF.sav", usecols=STUDENT_VARS)
stu = stu[stu["CNT"] == COUNTRY].copy()
sch, _ = pyreadstat.read_sav(DATA / "CY09_MS_SCH_PUF.sav", usecols=["CNT", "CNTSCHID", "W_NRASCHBWT"])
sch = sch[sch["CNT"] == COUNTRY].drop(columns="CNT")
d = stu.merge(sch, on="CNTSCHID", how="left", validate="many_to_one")
assert d["W_NRASCHBWT"].notna().all(), "school weight missing for some students"

d["male"] = (d["ST004D01T"] == 2).astype(int)
d["grade"] = d["ST001D01T"] - d["ST001D01T"].median()

# purposes of GenAI use (1 = never or almost never ... 5 = every day or almost every day)
d["ai_freq"] = d[AI].mean(axis=1)                                  # mean of the four purposes
d["q_other"] = d[AI[:3]].mean(axis=1)                              # summarize, research, draft
d["rel_learn"] = d["ST438Q04DA"] - d["q_other"]                    # help me learn relative to other uses
d["rel2"] = d[["ST438Q02DA", "ST438Q04DA"]].mean(axis=1) - d[["ST438Q01DA", "ST438Q03DA"]].mean(axis=1)
d["nonuser"] = np.where(d[AI].isna().any(axis=1), np.nan, (d[AI] == 1).all(axis=1).astype(float))

# out-of-school AI tool use: category 6 = "not available to me outside school"
d["ai_outside"] = d["IC171Q10DA"].where(d["IC171Q10DA"] != 6)

d.to_csv(OUT / "bsjz_analysis.csv", index=False)
print(f"students: {len(d)}, schools: {d['CNTSCHID'].nunique()} -> {OUT / 'bsjz_analysis.csv'}")
