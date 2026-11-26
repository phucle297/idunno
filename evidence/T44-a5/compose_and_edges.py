#!/usr/bin/env python3
"""T44 A5: 1:1 AA-off vs AA-on composites, Lanczos-down 2560->1280, hard-stair edge counts."""
from __future__ import annotations
from pathlib import Path
import csv
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
# Character-focused 1:1 crops (no scale). Sheet framing from A4 QA: (440,130)-(840,550).
# Gameplay camera: slightly lower in the frame; generous box around the figurine.
CROPS = {
    "town_sheet": (440, 130, 840, 550),
    "interior_sheet": (440, 130, 840, 550),
    "town_game": (500, 280, 780, 640),
    "interior_game": (500, 280, 780, 640),
}

def luma(im: Image.Image) -> np.ndarray:
    a = np.asarray(im.convert("RGB"), dtype=np.float32)
    return 0.299 * a[:, :, 0] + 0.587 * a[:, :, 1] + 0.114 * a[:, :, 2]

def hard_stairs(L: np.ndarray) -> int:
    """Count isolated 1-px sharp transitions (luma |Δ|>=32) along x and y."""
    dx = np.abs(np.diff(L, axis=1)) >= 32.0
    dy = np.abs(np.diff(L, axis=0)) >= 32.0
    n = 0
    # pad so we can test neighbours
    hx = np.pad(dx, ((0, 0), (1, 1)), constant_values=False)
    hy = np.pad(dy, ((1, 1), (0, 0)), constant_values=False)
    # 1-px run: a True with False on both sides along the axis
    n += int(np.sum(hx[:, 1:-1] & ~hx[:, 0:-2] & ~hx[:, 2:]))
    n += int(np.sum(hy[1:-1, :] & ~hy[0:-2, :] & ~hy[2:, :]))
    return n

def side_by_side(left: Image.Image, right: Image.Image, label_l: str, label_r: str) -> Image.Image:
    w, h = left.size
    bar = 28
    canvas = Image.new("RGB", (w * 2, h + bar), (20, 20, 20))
    canvas.paste(left, (0, bar))
    canvas.paste(right, (w, bar))
    d = ImageDraw.Draw(canvas)
    d.text((8, 6), label_l, fill=(255, 255, 255))
    d.text((w + 8, 6), label_r, fill=(255, 255, 255))
    return canvas

def main() -> None:
    pairs = [
        "town_sheet",
        "town_game",
        "interior_sheet",
        "interior_game",
    ]
    rows = []
    for tag in pairs:
        off = Image.open(OUT / f"{tag}_aaoff.png").convert("RGB")
        on = Image.open(OUT / f"{tag}_aaon.png").convert("RGB")
        assert off.size == on.size == (1280, 720), (tag, off.size, on.size)
        sbs = side_by_side(off, on, f"{tag} AA-off (1:1, 1280x720)", f"{tag} AA-on MSAA 2x (1:1, 1280x720)")
        sbs.save(OUT / f"side_by_side_{tag}.png")
        box = CROPS[tag]
        crop_off = off.crop(box)
        crop_on = on.crop(box)
        crop_off.save(OUT / f"crop_{tag}_aaoff.png")
        crop_on.save(OUT / f"crop_{tag}_aaon.png")
        crop_sbs = side_by_side(crop_off, crop_on, f"{tag} crop AA-off 1:1", f"{tag} crop AA-on 1:1")
        crop_sbs.save(OUT / f"crop_side_by_side_{tag}.png")
        n_off = hard_stairs(luma(crop_off))
        n_on = hard_stairs(luma(crop_on))
        drop = (n_off - n_on) / n_off * 100.0 if n_off else 0.0
        rows.append(dict(tag=tag, crop="x".join(map(str, box)), aaoff=n_off, aaon=n_on, drop_pct=round(drop, 1)))
        print(f"EDGES {tag}: off={n_off} on={n_on} drop={drop:.1f}% crop={box}")
    # Combined plate+hood/body: sum town+interior sheet crops (closer view of plate/hood)
    # and report per-view plus a combined silhouette total.
    tot_off = sum(r["aaoff"] for r in rows)
    tot_on = sum(r["aaon"] for r in rows)
    tot_drop = (tot_off - tot_on) / tot_off * 100.0 if tot_off else 0.0
    rows.append(dict(tag="ALL_CROPS_SUM", crop="sum", aaoff=tot_off, aaon=tot_on, drop_pct=round(tot_drop, 1)))
    print(f"EDGES ALL_CROPS_SUM: off={tot_off} on={tot_on} drop={tot_drop:.1f}%")
    sheet_off = sum(r["aaoff"] for r in rows if r["tag"].endswith("_sheet"))
    sheet_on = sum(r["aaon"] for r in rows if r["tag"].endswith("_sheet"))
    sheet_drop = (sheet_off - sheet_on) / sheet_off * 100.0 if sheet_off else 0.0
    rows.append(dict(tag="SHEET_CROPS_SUM", crop="sum", aaoff=sheet_off, aaon=sheet_on, drop_pct=round(sheet_drop, 1)))
    print(f"EDGES SHEET_CROPS_SUM: off={sheet_off} on={sheet_on} drop={sheet_drop:.1f}%")

    with (OUT / "edge_pixels.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["tag", "crop", "aaoff", "aaon", "drop_pct"])
        w.writeheader()
        w.writerows(rows)

    # 2560x1440 Lanczos-down to 1280x720
    for tag in pairs:
        for aa in ("off", "on"):
            src = OUT / f"{tag}_2560_aa{aa}.png"
            if not src.exists():
                print("MISSING", src)
                continue
            im = Image.open(src).convert("RGB")
            assert im.size == (2560, 1440), (src, im.size)
            down = im.resize((1280, 720), Image.Resampling.LANCZOS)
            down.save(OUT / f"{tag}_2560_lanczos_aa{aa}.png")
        # reference strip: 1:1 AA-off | 1:1 AA-on | 2560 Lanczos-down AA-off
        a = Image.open(OUT / f"{tag}_aaoff.png").convert("RGB")
        b = Image.open(OUT / f"{tag}_aaon.png").convert("RGB")
        c = Image.open(OUT / f"{tag}_2560_lanczos_aaoff.png").convert("RGB")
        bar = 28
        canvas = Image.new("RGB", (1280 * 3, 720 + bar), (20, 20, 20))
        canvas.paste(a, (0, bar)); canvas.paste(b, (1280, bar)); canvas.paste(c, (2560, bar))
        d = ImageDraw.Draw(canvas)
        d.text((8, 6), f"{tag} AA-off 1280 1:1", fill=(255, 255, 255))
        d.text((1288, 6), f"{tag} AA-on 1280 1:1", fill=(255, 255, 255))
        d.text((2568, 6), f"{tag} 2560 Lanczos-down to 1280 (AA-off)", fill=(255, 255, 255))
        canvas.save(OUT / f"refstrip_{tag}.png")
    print("COMPOSE_OK")

if __name__ == "__main__":
    main()
