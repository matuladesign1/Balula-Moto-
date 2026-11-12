#!/usr/bin/env python3
"""Aperçu à plat de la carte de Kinshasa (outil facultatif pour le développeur).

Lit data/maps/kinshasa.json, projette les positions GPS comme le jeu le fait, dessine les routes et
les lieux, et signale les lieux qui chevauchent une route. Nécessite matplotlib.

Usage :  python3 tools/preview_layout.py [sortie.png]
"""
import json
import math
import sys
from pathlib import Path

M_PER_DEG = 111000.0
# Rayon approximatif (en mètres, avant échelle des lieux) de l'emprise de chaque type de lieu.
RADIUS = {"gare": 38, "stade": 33, "palais": 36, "ccapac": 24, "victoire": 18, "tour": 16,
          "stele": 5, "panneau": 4, "garage": 14, "shop": 14}


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def projector(data):
    lon0, lat0 = data["origin"]["lon"], data["origin"]["lat"]
    scale = 1.0 / data.get("scale_divisor", 4.0)
    return lambda lon, lat: ((lon - lon0) * M_PER_DEG * scale, (lat0 - lat) * M_PER_DEG * scale)


def seg_dist(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    cx, cz = ax + t * dx, az + t * dz
    return math.hypot(px - cx, pz - cz)


def main():
    root = Path(__file__).resolve().parent.parent
    data = load(root / "data" / "maps" / "kinshasa.json")
    proj = projector(data)
    ls = data.get("landmark_scale", 1.5)
    roads = {}
    for r in data["roads"]:
        roads[r["id"]] = {"pts": [proj(lon, lat) for lon, lat in r["points"]], "w": r["width"], "name": r["name"]}
    print("Routes (longueur en m de jeu) :")
    total = 0.0
    for rid, r in roads.items():
        L = sum(math.dist(a, b) for a, b in zip(r["pts"], r["pts"][1:]))
        total += L
        print(f"  {rid:14s} {L:7.0f} m  largeur {r['w']}")
    print(f"  total {total:.0f} m")

    def clearance(p):
        best = 1e9
        who = None
        for rid, r in roads.items():
            for a, b in zip(r["pts"], r["pts"][1:]):
                d = seg_dist(p, a, b) - r["w"] / 2.0
                if d < best:
                    best, who = d, rid
        return best, who

    places = []
    for lm in data["landmarks"]:
        if "pos_m" in lm:
            x, z = lm["pos_m"]
        elif "lon" in lm:
            x, z = proj(lm["lon"], lm["lat"])
            x += lm.get("dx", 0.0)
            z += lm.get("dz", 0.0)
        else:
            continue
        r = RADIUS.get(lm["kind"], 10) * ls
        c, who = clearance((x, z))
        places.append((lm, x, z, r, c, who))
        flag = "  <-- CHEVAUCHE UNE ROUTE" if c < r * 0.6 else ""
        print(f"{lm['id']:18s} x={x:8.1f} z={z:8.1f} rayon~{r:5.1f}  dist. bord de route={c:6.1f} ({who}){flag}")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib absent : pas d'image.")
        return
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "tools" / "apercu_kinshasa.png"
    fig, ax = plt.subplots(figsize=(11, 16), dpi=110)
    for rid, r in roads.items():
        xs = [p[0] for p in r["pts"]]
        zs = [p[1] for p in r["pts"]]
        ax.plot(xs, zs, color="#999999", lw=r["w"] * 0.55, solid_capstyle="butt", zorder=1)
        ax.plot(xs, zs, color="#444444", lw=0.8, zorder=2)
        mid = r["pts"][len(r["pts"]) // 2]
        if r["name"]:
            ax.annotate(r["name"], mid, fontsize=7, color="#222222", zorder=6)
    for lm, x, z, r, c, who in places:
        circ = plt.Circle((x, z), r, color="#e0a000" if lm.get("real", True) else "#2080d0", alpha=0.45, zorder=3)
        ax.add_patch(circ)
        ax.annotate(lm["name"], (x, z), fontsize=7, color="black", zorder=7, ha="center")
    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_title("Kinshasa - aperçu à plat (x vers l'est, z vers le sud)")
    ax.grid(True, alpha=0.3)
    fig.savefig(out)
    print("Image :", out)


if __name__ == "__main__":
    main()
