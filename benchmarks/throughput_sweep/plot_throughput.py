#!/usr/bin/env python3
"""Plot measured FP arithmetic throughput from measurements.csv."""
import csv
from pathlib import Path
import matplotlib.pyplot as plt

folder = Path(__file__).resolve().parent
csv_path = folder / "measurements.csv"
with csv_path.open(newline="", encoding="utf-8") as source:
    rows = list(csv.DictReader(source))
missing = [r["case"] + "/" + r["mode"] for r in rows if not r["region_cycles"].strip()]
if missing:
    raise SystemExit("Fill region_cycles in measurements.csv first; missing: " + ", ".join(missing))

fig, ax = plt.subplots(figsize=(9, 5.5))
styles = {
    "fadd3": ("#1769aa", "FADD3"),
    "fadd2": ("#d1495b", "FADD.S (two instructions per triple sum)"),
}
for mode, (color, label) in styles.items():
    series = sorted((r for r in rows if r["mode"] == mode),
                    key=lambda r: (int(r["fp_additions"]), r["case"]))
    x = [int(r["fp_additions"]) for r in series]
    cycles = [int(r["region_cycles"]) for r in series]
    y = [a / c for a, c in zip(x, cycles)]
    ax.plot(x, y, marker="o", linewidth=2, color=color, label=label)

ax.set_xlabel("Equivalent binary FP additions in benchmark")
ax.set_ylabel("Throughput (FP additions / cycle)")
ax.set_title("FADD3 vs FADD.S throughput")
ax.grid(True, alpha=0.3)
ax.legend()
fig.tight_layout()
output = folder / "throughput_comparison.png"
fig.savefig(output, dpi=180)
print(f"Wrote {output}")
