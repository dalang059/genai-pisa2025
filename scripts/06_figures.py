"""
Step 6. Figures 1-5 (TIFF, RGB, 600 dpi) in output/figures.
Requires the outputs of steps 3-5.
"""
import io
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output"
FIG = OUT / "figures"
FIG.mkdir(parents=True, exist_ok=True)
MM = 1 / 25.4
INK, INK2, GREY, BLUE = "#0b0b0b", "#52514e", "#898781", "#2a78d6"
BLUES = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#104281"]
plt.rcParams.update({"font.family": "Arial", "font.size": 8, "axes.edgecolor": GREY,
                     "axes.labelcolor": INK, "xtick.color": INK2, "ytick.color": INK2})


def save(fig, name):
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=600, facecolor="white")
    plt.close(fig)
    buf.seek(0)
    Image.open(buf).convert("RGB").save(FIG / f"{name}.tif", dpi=(600, 600), compression="tiff_lzw")


def tidy(ax):
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_linewidth(0.6)
    ax.tick_params(width=0.6, length=3)


def diagram(ax, boxes, width=38, height=13):
    for x, y, label in boxes.values():
        ax.add_patch(FancyBboxPatch((x, y), width, height, boxstyle="round,pad=0,rounding_size=2",
                                    fc="white", ec=INK, lw=0.9))
        ax.text(x + width / 2, y + height / 2, label, ha="center", va="center", fontsize=8, color=INK)

    def port(key, side):
        x, y, _ = boxes[key]
        return {"l": (x, y + height / 2), "r": (x + width, y + height / 2), "t": (x + width / 2, y + height),
                "b": (x + width / 2, y), "tl": (x, y + 0.8 * height), "bl": (x, y + 0.2 * height),
                "tr": (x + width, y + 0.8 * height), "br": (x + width, y + 0.2 * height)}[side]

    def arrow(a, b, label=None, pos=0.5, off=(0, 2.4), dashed=False, rad=0.0):
        ax.add_patch(FancyArrowPatch(a, b, arrowstyle="-|>", mutation_scale=8, lw=0.9, color=INK,
                                     linestyle=(0, (4, 2)) if dashed else "-", shrinkA=1, shrinkB=1,
                                     connectionstyle=f"arc3,rad={rad}"))
        if label:
            ax.text(a[0] + (b[0] - a[0]) * pos + off[0], a[1] + (b[1] - a[1]) * pos + off[1], label,
                    ha="center", va="center", fontsize=7.5, color=INK, bbox=dict(fc="white", ec="none", pad=0.6))

    return port, arrow


# ---------------------------------------------------------------- Figure 1: hypothesized model
fig, ax = plt.subplots(figsize=(180 * MM, 68 * MM))
ax.set_xlim(0, 180); ax.set_ylim(3, 77); ax.axis("off")
port, arrow = diagram(ax, {"ai": (4, 33.5, "GenAI use\nfor schoolwork"), "meta": (50, 61, "Metacognitive\nstrategy use"),
                           "help": (50, 6, "Academic\nhelp seeking"), "eff": (100, 61, "Science\nself-efficacy"),
                           "sci": (140, 33.5, "Scientific\nliteracy")})
arrow(port("ai", "tr"), port("meta", "l"), "H2a (+)", off=(-7, 1))
arrow(port("ai", "br"), port("help", "l"), "H2b (+)", off=(-7, -1))
arrow(port("meta", "br"), port("sci", "tl"), "H3a (+)", pos=0.62, off=(3, -3.6))
arrow(port("help", "r"), port("sci", "bl"), "H3b (+)", pos=0.5, off=(2, -3.5))
arrow(port("ai", "r"), port("sci", "l"), "H1 (−)", off=(0, 2.6))
arrow(port("meta", "r"), port("eff", "l"), dashed=True)
arrow(port("help", "tr"), port("eff", "b"), dashed=True)
arrow(port("eff", "r"), (port("sci", "t")[0] + 6, port("sci", "t")[1]), "H6", off=(4, 2), dashed=True, rad=-0.3)
save(fig, "Figure1")

# ---------------------------------------------------------------- Figure 2: distribution of purposes
dist = pd.read_csv(OUT / "purpose_distribution.csv", index_col=0)
dist.index = [s.replace("Draft texts for writing assignments", "Draft texts for\nwriting assignments")
              .replace("Summarize a text I had to read", "Summarize a text\nI had to read")
              .replace("Research a new topic", "Research a\nnew topic") for s in dist.index]
dist = dist.loc[dist[["weekly", "daily"]].sum(axis=1).sort_values().index]
legend = ["Never or almost never", "Once or twice a year", "Once or twice a month", "Once or twice a week",
          "Almost every day"]
fig, ax = plt.subplots(figsize=(170 * MM, 62 * MM))
left = np.zeros(len(dist))
for k, (col, lab, colour) in enumerate(zip(dist.columns, legend, BLUES)):
    vals = dist[col].to_numpy()
    ax.barh(range(len(dist)), vals, left=left, color=colour, edgecolor="white", linewidth=1.2, height=0.62, label=lab)
    for i, v in enumerate(vals):
        if v >= 6:
            ax.text(left[i] + v / 2, i, f"{v:.0f}%", ha="center", va="center", fontsize=7,
                    color="white" if k >= 2 else INK)
    left += vals
ax.set_yticks(range(len(dist))); ax.set_yticklabels(dist.index, color=INK)
ax.set_xlim(0, 100); ax.set_xlabel("Weighted percentage of students")
tidy(ax)
ax.legend(ncol=5, loc="lower left", bbox_to_anchor=(-0.02, 1.02), frameon=False, fontsize=6.8,
          handlelength=1.0, columnspacing=0.8, handletextpad=0.4)
fig.tight_layout()
save(fig, "Figure2")

# ---------------------------------------------------------------- Figure 3: estimated mediation model
m = pd.read_csv(OUT / "table2_main_model.csv").set_index("effect")


def coef(key):
    r = m.loc[key]
    return f"{r.est:.3f}{'*' if r.ci_lo > 0 or r.ci_hi < 0 else ''}".replace("-", "−")


fig, ax = plt.subplots(figsize=(170 * MM, 70 * MM))
ax.set_xlim(0, 170); ax.set_ylim(0, 74); ax.axis("off")
port, arrow = diagram(ax, {"ai": (4, 30.5, "GenAI use\nfor schoolwork"), "meta": (66, 57, "Metacognitive\nstrategy use"),
                           "help": (66, 4, "Academic\nhelp seeking"), "sci": (128, 30.5, "Scientific\nliteracy")})
arrow(port("ai", "tr"), port("meta", "l"), coef("a: AI_w -> META"), off=(-6, 1.5))
arrow(port("ai", "br"), port("help", "l"), coef("a: AI_w -> HELP"), off=(-6, -1.5))
arrow(port("meta", "r"), port("sci", "tl"), coef("b: META -> SCI"), off=(6, 1.5))
arrow(port("help", "r"), port("sci", "bl"), coef("b: HELP -> SCI"), off=(6, -1.5))
arrow(port("ai", "r"), port("sci", "l"),
      f"direct {coef('direct: AI_w -> SCI')}  (total {coef('total: AI_w -> SCI')})", off=(0, 2.6))
ax.text(85, 0.5, f"Indirect via help seeking = {coef('ind: AI_w -> HELP -> SCI')};  via metacognitive strategies = "
        f"{coef('ind: AI_w -> META -> SCI')};  total indirect = {coef('ind total: AI_w')}",
        ha="center", va="top", fontsize=7, color=INK2)
save(fig, "Figure3")

# ---------------------------------------------------------------- Figure 4: purposes and scientific literacy
names = {"ST438Q01DA": "Summarize a text I had to read", "ST438Q02DA": "Research a new topic",
         "ST438Q03DA": "Draft texts for writing assignments", "ST438Q04DA": "Help me learn"}
key = {"ST438Q01DA": "I1", "ST438Q02DA": "I2", "ST438Q03DA": "I3", "ST438Q04DA": "I4"}
panel_a = pd.DataFrame([
    (lab, *pd.read_csv(OUT / f"table4_purpose_{item}.csv").set_index("effect")
     .loc[f"total: {key[item]}_w -> SCI", ["est", "ci_lo", "ci_hi"]].to_list())
    for item, lab in names.items()], columns=["label", "est", "lo", "hi"])
lower = pd.read_csv(OUT / "table4_users_entered_together.csv")
panel_b = pd.DataFrame({"label": ["Help me learn", "Mean of the other\nthree purposes"],
                        "est": lower.points[:2].to_numpy(), "lo": lower.points_lo[:2].to_numpy(),
                        "hi": lower.points_hi[:2].to_numpy()})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(170 * MM, 58 * MM), gridspec_kw={"width_ratios": [1.35, 1]})
for ax, df, xlabel, title, fmt in (
        (a1, panel_a, "Total association with scientific literacy (β)", "A  Each purpose separately", "{:+.3f}"),
        (a2, panel_b, "PISA points per category", "B  Users, entered together", "{:+.1f}")):
    y = np.arange(len(df))[::-1]
    ax.axvline(0, color=GREY, lw=0.6, zorder=0)
    ax.hlines(y, df.lo, df.hi, color=BLUE, lw=1.5)
    ax.plot(df.est, y, "o", color=BLUE, ms=5, mec="white", mew=1)
    for yi, est, hi in zip(y, df.est, df.hi):
        ax.text(hi, yi, " " + fmt.format(est).replace("-", "−"), va="center", ha="left", fontsize=7,
                color=INK2, bbox=dict(fc="white", ec="none", pad=0.4))
    ax.set_yticks(y); ax.set_yticklabels(df.label, color=INK)
    ax.set_xlabel(xlabel); ax.set_title(title, loc="left", fontsize=8, color=INK, fontweight="bold")
    ax.set_ylim(-0.6, len(df) - 0.3)
    tidy(ax)
a1.set_xlim(-0.1, 0.09); a2.set_xlim(-10.5, 12)
fig.tight_layout(w_pad=2.5)
save(fig, "Figure4")

# ---------------------------------------------------------------- Figure 5: curvilinear association
c = pd.read_csv(OUT / "figure5_curve.csv")
fig, ax = plt.subplots(figsize=(85 * MM, 62 * MM))
ax.fill_between(c.x, c.points_lo, c.points_hi, color=BLUE, alpha=0.18, lw=0)
ax.plot(c.x, c.points, color=BLUE, lw=1.5)
ax.axhline(0, color=GREY, lw=0.6, zorder=0)
ax.set_xlabel("GenAI use relative to school mean (SD)")
ax.set_ylabel("Predicted difference in scientific\nliteracy (PISA score points)")
ax.set_xticks([-2, -1, 0, 1, 2, 3]); ax.set_xlim(c.x.min(), c.x.max())
tidy(ax)
fig.tight_layout()
save(fig, "Figure5")
print("figures written to", FIG)
