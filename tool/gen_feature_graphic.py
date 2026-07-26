"""Generates store_assets/feature-graphic.png — the Play Store feature graphic.

The store requires exactly 1024x500, but several placements cover-crop it to
roughly 16:9 (the 303x170 card in particular), which slices 66 px off each
side. Everything that must stay readable is therefore laid out inside
SAFE_X0..SAFE_X1 with extra padding; only decoration lives outside it.

The artwork is a procedural reef-aquarium scene: depth gradient, rippled water
surface seen from below, god rays tracing from the surface down to the sand,
caustics, rock/coral silhouettes, three reef fish, bubbles and marine snow.

Usage:  python tool/gen_feature_graphic.py [--preview] [--bg=PATH]
        --preview  also writes 303x170 crop and safe-box previews to %TEMP%.
        --bg=PATH  use an external image as the backdrop instead of the
                   procedural scene (see store_assets/README.md); the wordmark,
                   card and safe-area layout are applied on top unchanged.
"""

from __future__ import annotations

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------- geometry --

OUT_W, OUT_H = 1024, 500
SS = 2  # supersampling factor
W, H = OUT_W * SS, OUT_H * SS

# Central region that survives the 16:9 cover-crop (66 px each side at 1x),
# plus 44 px of breathing room so nothing sits on the crop seam.
SAFE_X0, SAFE_X1 = 110 * SS, 914 * SS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store_assets", "feature-graphic.png")

FONT_DIR = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")
FONT_TITLE = os.path.join(FONT_DIR, "seguibl.ttf")   # Segoe UI Black
FONT_BODY = os.path.join(FONT_DIR, "segoeuib.ttf")   # Segoe UI Bold
FONT_SMALL = os.path.join(FONT_DIR, "segoeui.ttf")   # Segoe UI

# Brand palette, matching lib/app/theme.dart.
TEAL = (10, 133, 153)
HEALTHY = (47, 169, 104)
HEALTHY_LT = (125, 232, 160)

rng = random.Random(20260726)

# ------------------------------------------------------------------ helpers --


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vertical_gradient(stops):
    """stops: [(pos 0..1, (r,g,b)), ...] -> (H, 3) float array."""
    ys = np.linspace(0.0, 1.0, H)
    out = np.zeros((H, 3), dtype=np.float64)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        m = (ys >= p0) & (ys <= p1)
        t = smoothstep((ys[m] - p0) / (p1 - p0))
        for k in range(3):
            out[m, k] = c0[k] + (c1[k] - c0[k]) * t
    return out


def caustic_field(xx, yy, scale, phase):
    """Thin interlocking bright lines, the classic water-caustic net."""
    a = np.sin(xx * scale + np.sin(yy * scale * 0.7 + phase) * 1.7 + phase)
    b = np.sin(yy * scale * 1.25 + np.sin(xx * scale * 0.9 - phase) * 1.5 - phase * 0.7)
    c = np.sin((xx + yy * 0.6) * scale * 0.55 + phase * 1.3)
    n = (a + b + c) / 3.0
    return np.clip(1.0 - np.abs(n) * 3.1, 0.0, 1.0) ** 2.2


def blur_array(arr, radius):
    """Gaussian-blur a float H*W array via PIL."""
    lo, hi = float(arr.min()), float(arr.max())
    if hi - lo < 1e-9:
        return arr
    img = Image.fromarray(((arr - lo) / (hi - lo) * 255).astype(np.uint8), "L")
    img = img.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img, dtype=np.float64) / 255.0 * (hi - lo) + lo


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m
# --------------------------------------------------- silhouettes & bubbles --


def rock_ridge(d, cx, half_w, height, bed_y, color, lumps=7):
    """A rounded rock outcrop: overlapping discs under an irregular profile."""
    for i in range(lumps):
        t = i / max(1, lumps - 1)
        lx = cx + (t - 0.5) * 2 * half_w
        prof = math.cos((t - 0.5) * math.pi) ** 0.75
        lh = height * prof * rng.uniform(0.72, 1.05)
        lw = half_w * rng.uniform(0.30, 0.48)
        d.ellipse([lx - lw, bed_y - lh, lx + lw, bed_y + height * 0.9], fill=color)


def finger_coral(d, x, bed_y, height, color, fingers=6, spread=0.34):
    """A cluster of blunt, upward finger corals — reads as reef, not as a skyline."""
    # A low mound the fingers grow out of, so the cluster has a base.
    mw = height * 0.62
    d.ellipse([x - mw, bed_y - height * 0.16, x + mw, bed_y + height * 0.45],
              fill=color)
    for i in range(fingers):
        t = (i / max(1, fingers - 1)) - 0.5
        tilt = t * spread * 2 + rng.uniform(-0.10, 0.10)
        h = height * (1.0 - abs(t) * 0.55) * rng.uniform(0.72, 1.10)
        w = max(3.0, height * rng.uniform(0.17, 0.26))
        bx = x + t * height * 0.80
        # Draw each finger as a tapering stack of discs — organic, not stick-like.
        segs = 9
        for s in range(segs + 1):
            f = s / segs
            sx = bx + math.sin(tilt) * h * f + math.sin(f * 2.0) * w * 0.18
            sy = bed_y - math.cos(tilt) * h * f
            r = w * (1.0 - 0.34 * f) / 2
            d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=color)
        if h > height * 0.60:  # a stubby branch off the side
            fa = tilt + rng.choice((-1, 1)) * rng.uniform(0.5, 0.85)
            fl = h * rng.uniform(0.26, 0.40)
            mx = bx + math.sin(tilt) * h * 0.58
            my = bed_y - math.cos(tilt) * h * 0.58
            for s in range(6):
                f = s / 5
                r = w * 0.40 * (1.0 - 0.3 * f)
                sx, sy = mx + math.sin(fa) * fl * f, my - math.cos(fa) * fl * f
                d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=color)


def _body_profile(t, a, b, ped):
    """Half-height of the body at 0 (snout) .. 1 (caudal peduncle), max 1."""
    tmax = a / (a + b)
    fmax = tmax ** a * (1 - tmax) ** b
    return ((t ** a) * ((1 - t) ** b) / fmax + ped * t ** 1.5) / (1 + ped)


def _fin(profile_pts, t0, t1, bulge, up):
    """A fin bulging off the given stretch of the body outline."""
    seg = [p for tt, p in profile_pts if t0 <= tt <= t1]
    if len(seg) < 3:
        return []
    outer = []
    for i, (x, y) in enumerate(seg):
        f = i / (len(seg) - 1)
        outer.append((x, y + (-1 if up else 1) * bulge * math.sin(math.pi * f) ** 0.8))
    return seg + outer[::-1]


def draw_fish(kind, length, flip=False):
    """A small, stylised reef fish rendered on its own transparent layer.

    Drawn at 3x and downscaled, which is what keeps the outlines smooth at the
    sizes these appear on the banner (70-125 px wide).
    """
    K = 3
    spec = FISH[kind]
    LW = int(length * SS * K)
    LH = int(LW * spec["depth"])
    pad = int(LH * 0.45)
    img_w, img_h = LW + pad * 2, LH + pad * 2
    layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cy = pad + LH / 2
    body_len = LW * 0.76
    a, b, ped = spec["a"], spec["b"], 0.13
    steps = 90
    top = [(t, (pad + t * body_len, cy - _body_profile(t, a, b, ped) * LH * 0.5))
           for t in (i / steps for i in range(steps + 1))]
    bot = [(t, (pad + t * body_len, cy + _body_profile(t, a, b, ped) * LH * 0.5))
           for t in (i / steps for i in range(steps + 1))]
    body = [p for _, p in top] + [p for _, p in bot][::-1]

    outline = spec.get("outline", (18, 22, 34, 235))
    fin_col = spec["fin"]
    ped_h = _body_profile(1.0, a, b, ped) * LH * 0.5

    # --- fins, behind the body ------------------------------------------------
    d.polygon(_fin(top, 0.20, 0.74, LH * spec["dorsal"], True), fill=fin_col)
    d.polygon(_fin(bot, 0.52, 0.86, LH * spec["anal"], False), fill=fin_col)

    # Start the caudal fin just inside the body so it never looks detached.
    x_ped = pad + body_len * 0.95
    x_tip = pad + LW
    if spec["tail"] == "fork":
        tail = [(x_ped, cy - ped_h), (x_tip, cy - LH * 0.40),
                (x_tip - LW * 0.09, cy), (x_tip, cy + LH * 0.40),
                (x_ped, cy + ped_h)]
    else:  # rounded paddle
        tail = [(x_ped, cy - ped_h)]
        for i in range(15):
            th = math.pi * (i / 14) - math.pi / 2
            tail.append((x_ped + (x_tip - x_ped) * (0.34 + 0.66 * math.cos(th)),
                         cy + LH * 0.34 * math.sin(th)))
        tail.append((x_ped, cy + ped_h))
    d.polygon(tail, fill=spec["tail_col"])

    # --- body -----------------------------------------------------------------
    d.polygon(body, fill=spec["body"])

    # Species markings, clipped to the body silhouette.
    marks = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    md = ImageDraw.Draw(marks)
    for m in spec["marks"]:
        if m[0] == "band":  # a slanted vertical bar, black-edged like a real one
            _, t, w, col = m
            x = pad + t * body_len
            for grow, c in ((1.34, (30, 22, 20, 255)), (1.0, col)):
                ww = w * LW * grow
                md.polygon([(x - ww, pad - LH), (x + ww * 0.55, pad - LH),
                            (x + ww * 1.35, pad + LH * 2), (x - ww * 0.2, pad + LH * 2)],
                           fill=c)
        elif m[0] == "palette":
            # The blue tang's marking: a black band hugging the back that
            # thickens towards the tail, plus one along the rear belly. The
            # blue oval they leave between them is what makes it read as Dory.
            _, col = m
            ts = [0.16 + i / 80 * 0.84 for i in range(81)]
            outer = [(pad + t * body_len,
                      cy - _body_profile(t, a, b, ped) * LH * 0.5) for t in ts]
            inner = [(x, y + LH * (0.10 + 0.34 * smoothstep((t - 0.55) / 0.45)))
                     for t, (x, y) in zip(ts, outer)]
            md.polygon(outer + inner[::-1], fill=col)
            ts2 = [0.62 + i / 60 * 0.38 for i in range(61)]
            outer2 = [(pad + t * body_len,
                       cy + _body_profile(t, a, b, ped) * LH * 0.5) for t in ts2]
            inner2 = [(x, y - LH * (0.04 + 0.18 * smoothstep((t - 0.62) / 0.38)))
                      for t, (x, y) in zip(ts2, outer2)]
            md.polygon(outer2 + inner2[::-1], fill=col)
            # A short bar back from the eye, where the marking starts.
            ex0 = pad + body_len * 0.09
            md.polygon([(ex0, cy - LH * 0.30), (ex0 + body_len * 0.13, cy - LH * 0.36),
                        (ex0 + body_len * 0.13, cy - LH * 0.02), (ex0, cy - LH * 0.06)],
                       fill=col)
        elif m[0] == "snout":  # pale nose
            _, t1, col = m
            pts_t = [p for tt, p in top if tt <= t1]
            pts_b = [p for tt, p in bot if tt <= t1]
            md.polygon(pts_t + pts_b[::-1], fill=col)
    body_mask = Image.new("L", (img_w, img_h), 0)
    ImageDraw.Draw(body_mask).polygon(body, fill=255)
    marks.putalpha(Image.composite(marks.getchannel("A"),
                                   Image.new("L", (img_w, img_h), 0), body_mask))
    layer = Image.alpha_composite(layer, marks)
    d = ImageDraw.Draw(layer)

    # Countershading: darker along the back, brighter on the belly.
    shade = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(int(LH)):
        f = i / max(1, LH - 1)
        al = int(30 * (1 - f) ** 2.0)
        sd.rectangle([0, pad + i, img_w, pad + i + 1], fill=(0, 16, 38, al))
    shade.putalpha(Image.composite(shade.getchannel("A"),
                                   Image.new("L", (img_w, img_h), 0), body_mask))
    layer = Image.alpha_composite(layer, shade)
    d = ImageDraw.Draw(layer)

    # Pectoral fin, then the outline, then the eye. Note ImageDraw *replaces*
    # alpha on an RGBA layer rather than blending, so this has to be opaque —
    # a translucent fill would punch a hole straight through the fish.
    fx = pad + body_len * 0.33
    fy = cy + LH * 0.06
    bc = spec["body"]
    pect = (int(bc[0] * 0.88), int(bc[1] * 0.88), int(bc[2] * 0.88), 255)
    d.polygon([(fx, fy), (fx + LW * 0.062, fy + LH * 0.11),
               (fx + LW * 0.010, fy + LH * 0.15)], fill=pect)
    d.line(body + [body[0]], fill=outline, width=max(2, int(LW * 0.008)))

    ex, ey = pad + body_len * 0.125, cy - LH * 0.15
    er = LH * 0.082
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(250, 250, 250, 255))
    pr = er * 0.62
    d.ellipse([ex - pr, ey - pr, ex + pr, ey + pr], fill=(14, 16, 24, 255))
    hr = pr * 0.34
    d.ellipse([ex - pr * 0.3 - hr, ey - pr * 0.3 - hr,
               ex - pr * 0.3 + hr, ey - pr * 0.3 + hr], fill=(255, 255, 255, 235))

    layer = layer.resize((img_w // K, img_h // K), Image.LANCZOS)
    return layer.transpose(Image.FLIP_LEFT_RIGHT) if flip else layer


# Stylised, not scientific — these read at 70-125 px wide.
FISH = {
    "clownfish": dict(
        depth=0.43, a=0.55, b=0.64, tail="round",
        body=(252, 128, 28, 255), fin=(242, 110, 20, 255),
        tail_col=(246, 118, 24, 255), outline=(26, 18, 16, 240), dorsal=0.19, anal=0.15,
        marks=[("band", 0.28, 0.038, (252, 252, 250, 255)),
               ("band", 0.56, 0.046, (252, 252, 250, 255)),
               ("band", 0.86, 0.028, (252, 252, 250, 255))],
    ),
    "bluetang": dict(  # "Dory" — Paracanthurus hepatus
        depth=0.56, a=0.80, b=0.80, tail="fork",
        body=(34, 100, 214, 255), fin=(24, 46, 96, 255),
        tail_col=(252, 208, 46, 255), outline=(12, 22, 52, 240), dorsal=0.12, anal=0.11,
        marks=[("palette", (18, 24, 44, 255))],
    ),
    "yellowtang": dict(  # Zebrasoma flavescens
        depth=0.62, a=0.70, b=0.95, tail="fork",
        body=(255, 214, 42, 255), fin=(252, 204, 26, 255),
        tail_col=(254, 208, 34, 255), outline=(146, 100, 10, 225), dorsal=0.30, anal=0.27,
        marks=[("snout", 0.13, (255, 242, 198, 255))],
    ),
}


def place_fish(scene, kind, length, cx, cy, flip=False, tilt=0.0, haze=0.20):
    """Composite a fish into the scene with a bit of underwater grading."""
    f = draw_fish(kind, length, flip=flip)
    if tilt:
        f = f.rotate(tilt, resample=Image.BICUBIC, expand=True)
    arr = np.asarray(f, dtype=np.float64)
    rgb, alpha = arr[:, :, :3], arr[:, :, 3:4]
    # Water between viewer and fish washes colour towards the ambient blue.
    rgb = rgb * (1 - haze) + np.array([46, 132, 172], dtype=np.float64)[None, None, :] * haze
    f = Image.fromarray(
        np.clip(np.concatenate([rgb, alpha], axis=2), 0, 255).astype(np.uint8), "RGBA")
    out = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    out.paste(f, (int(cx * SS - f.width / 2), int(cy * SS - f.height / 2)), f)
    return Image.alpha_composite(scene, out)


def reef_layer(color, bed_y, rocks, corals, domes, blur):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, hw, ht in rocks:
        rock_ridge(d, cx * W, hw * W, ht * H, bed_y, color)
    for cx, ht, fg in domes:  # brain-coral domes
        d.ellipse([(cx - ht * 0.9) * W, bed_y - ht * H * 1.15,
                   (cx + ht * 0.9) * W, bed_y + ht * H], fill=color)
    for cx, ht, fg in corals:
        finger_coral(d, cx * W, bed_y - ht * H * 0.15, ht * H, color, fingers=fg)
    return layer.filter(ImageFilter.GaussianBlur(blur))




# ------------------------------------------------------------- water scene --


def procedural_scene():
    """The reef-aquarium backdrop, generated from scratch."""

    xs = np.arange(W, dtype=np.float64)
    ys = np.arange(H, dtype=np.float64)
    xx, yy = np.meshgrid(xs, ys)
    u, v = xx / W, yy / H

    # Depth gradient: lit aqua just under the surface fading to deep reef blue.
    base = vertical_gradient([
        (0.00, (86, 210, 214)),
        (0.05, (48, 174, 194)),
        (0.18, (26, 132, 170)),
        (0.42, (17, 93, 138)),
        (0.70, (12, 68, 110)),
        (1.00, (9, 50, 90)),
    ])
    img = np.repeat(base[:, None, :], W, axis=1)

    # Light pools slightly left of centre, where the ray fan originates.
    glow = np.exp(-(((u - 0.40) / 0.46) ** 2)) * np.exp(-((v / 0.55) ** 2))
    img *= (1.0 + 0.13 * glow)[:, :, None]

    # --- water surface, seen from below -----------------------------------------

    SURF_Y = 0.115 * H
    surface = (
        SURF_Y
        + 0.020 * H * np.sin(xs / W * 2 * math.pi * 2.4 + 0.6)
        + 0.011 * H * np.sin(xs / W * 2 * math.pi * 5.1 + 2.1)
        + 0.006 * H * np.sin(xs / W * 2 * math.pi * 9.3 + 4.4)
    )
    surf2d = np.tile(surface, (H, 1))

    # Everything above the interface is the bright, mirror-like underside.
    above = smoothstep((surf2d - yy) / (10.0 * SS))
    depth_in_air = np.clip((surf2d - yy) / SURF_Y, 0.0, 1.0)
    sheet = 0.30 + 0.62 * depth_in_air
    # Rippled streaks along the sheet.
    streak = 0.5 + 0.5 * np.sin(xx / W * 2 * math.pi * 7.0 + np.sin(yy / H * 30.0) * 0.8)
    sheet = sheet * (0.72 + 0.36 * streak)
    sheet_col = np.array([132, 226, 232], dtype=np.float64)
    a = (above * np.clip(sheet, 0, 1))[:, :, None]
    img = img * (1 - a) + sheet_col[None, None, :] * a

    # The interface itself: a bright specular line with a soft bloom.
    line = np.exp(-(((yy - surf2d) / (2.2 * SS)) ** 2))
    bloom = np.exp(-(((yy - surf2d) / (14.0 * SS)) ** 2))
    crest = 0.55 + 0.45 * np.sin(xs / W * 2 * math.pi * 5.1 + 2.1)
    img += (line * 175 + bloom * 46) [:, :, None] * (crest[None, :, None]) * np.array(
        [0.92, 1.0, 1.0]
    )[None, None, :]

    # --- god rays ----------------------------------------------------------------

    ox, oy = 0.38 * W, -0.62 * H
    ang = np.arctan2(xx - ox, yy - oy)
    spec = [
        (-0.52, 0.026, 0.60), (-0.41, 0.013, 0.38), (-0.29, 0.038, 0.92),
        (-0.18, 0.011, 0.44), (-0.06, 0.032, 1.00), (0.03, 0.009, 0.34),
        (0.12, 0.024, 0.78), (0.23, 0.015, 0.50), (0.32, 0.043, 0.95),
        (0.44, 0.010, 0.36), (0.54, 0.028, 0.70), (0.66, 0.017, 0.48),
        (0.77, 0.036, 0.62), (0.89, 0.012, 0.32),
    ]
    soft = np.zeros((H, W), dtype=np.float64)
    core = np.zeros((H, W), dtype=np.float64)
    for a0, wdt, amp in spec:
        soft += amp * np.exp(-(((ang - a0) / wdt) ** 2))
        core += amp * np.exp(-(((ang - a0) / (wdt * 0.34)) ** 2))

    # Depth falloff — the shafts thin out but still reach the sand.
    depth = np.clip((yy - surf2d) / H, 0.0, 1.0)
    fall = 0.28 + 0.72 * np.exp(-1.9 * depth)
    start = smoothstep((yy - surf2d) / (16.0 * SS))          # begin at the surface
    into_sand = 1.0 - 0.18 * smoothstep((v - 0.86) / 0.14)   # soften into the bed
    soft = blur_array(soft * fall * start * into_sand, 6.0 * SS)
    core = blur_array(core * fall * start * into_sand, 2.0 * SS)
    ray_col = np.array([150, 234, 242], dtype=np.float64)
    img += (soft * 0.50 + core * 0.34)[:, :, None] * ray_col[None, None, :]

    # --- caustics ----------------------------------------------------------------

    # Caustics rippling across the underside of the surface, fading fast with depth.
    vol = caustic_field(u * 26.0, v * 16.0, 1.0, 0.9)
    img += (vol * np.exp(-6.5 * depth) * 40.0)[:, :, None] * np.array(
        [0.72, 1.0, 1.0]
    )[None, None, :]

    # --- sand bed ----------------------------------------------------------------

    sand_y = (
        0.855 * H
        + 0.018 * H * np.sin(xs / W * 2 * math.pi * 1.3 + 1.1)
        + 0.009 * H * np.sin(xs / W * 2 * math.pi * 3.7 + 0.2)
    )
    sand2d = np.tile(sand_y, (H, 1))
    in_sand = smoothstep((yy - sand2d) / (7.0 * SS))
    # 0 at the bed line (far away), 1 low in the frame (close to the viewer).
    sand_near = np.clip((yy - sand2d) / (0.13 * H), 0.0, 1.0)
    sand_col = (
        np.array([214, 197, 160], dtype=np.float64)[None, None, :]
        * (0.80 + 0.20 * sand_near)[:, :, None]
    )
    # Fine ripples, and a tight caustic net rather than broad marbling.
    ripple = 0.5 + 0.5 * np.sin(
        xx / W * 2 * math.pi * 30.0 + np.sin(yy / H * 2 * math.pi * 7.0) * 1.5
    )
    sand_col *= (0.95 + 0.09 * ripple)[:, :, None]
    sand_caustic = caustic_field(u * 88.0, v * 210.0, 1.0, 2.4)
    sand_col += (sand_caustic * 30.0)[:, :, None] * np.array([1.0, 0.97, 0.84])[None, None, :]
    # The ray fan lands here — that is where the shafts pay off.
    sand_col += ((soft * 0.26 + core * 0.18))[:, :, None] * np.array(
        [235, 238, 216], dtype=np.float64
    )[None, None, :]
    # Distance haze: the far edge of the bed dissolves into the water column.
    k = (0.14 + 0.52 * (1.0 - sand_near))[:, :, None]
    sand_col = sand_col * (1 - k) + img * k
    m = in_sand[:, :, None]
    img = img * (1 - m) + sand_col * m
    # Contact shadow just under the bed line.
    img *= (1.0 - 0.20 * np.exp(-(((yy - sand2d) / (5.0 * SS)) ** 2)))[:, :, None]

    # --- depth haze + vignette ---------------------------------------------------

    haze = smoothstep((v - 0.52) / 0.48) * 0.15
    img = img * (1 - haze[:, :, None]) + np.array(
        [22, 92, 126], dtype=np.float64
    )[None, None, :] * haze[:, :, None]

    vig = 1.0 - 0.18 * smoothstep((np.sqrt(((u - 0.5) * 1.6) ** 2 + ((v - 0.46) * 1.15) ** 2) - 0.44) / 0.56)
    img *= vig[:, :, None]

    scene = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

    scene = scene.convert("RGBA")

    # Far reef line — hazier and lighter, sits back in the water column.
    far = reef_layer(
        (11, 58, 88, 175), 0.862 * H,
        rocks=[(0.07, 0.11, 0.080), (0.91, 0.12, 0.088)],
        corals=[(0.20, 0.062, 5), (0.74, 0.056, 5)],
        domes=[],
        blur=3.4 * SS,
    )
    scene = Image.alpha_composite(scene, far)

    # Near reef — darker silhouette, weighted to the edges so a crop costs nothing.
    # The middle stays open so the sand and the light pool on it read clearly.
    near = reef_layer(
        (4, 30, 48, 246), 0.965 * H,
        rocks=[(-0.02, 0.15, 0.130), (0.12, 0.09, 0.062), (0.79, 0.10, 0.062),
               (1.00, 0.17, 0.140)],
        corals=[(0.035, 0.155, 6), (0.125, 0.092, 5), (0.935, 0.150, 6),
                (0.995, 0.108, 5), (0.235, 0.044, 4), (0.745, 0.040, 4)],
        domes=[(0.19, 0.030, 0), (0.85, 0.028, 0)],
        blur=1.8 * SS,
    )
    scene = Image.alpha_composite(scene, near)

    # Three reef fish, placed in the open water the layout leaves free: below
    # the tagline, left of the card, and high above the wordmark.
    scene = place_fish(scene, "bluetang", 128, 456, 392, tilt=-4, haze=0.14)
    scene = place_fish(scene, "clownfish", 96, 306, 418, tilt=3, haze=0.10)
    scene = place_fish(scene, "yellowtang", 78, 528, 86, flip=True, tilt=6, haze=0.13)

    # Marine snow + bubbles.
    fx_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx_layer)
    for _ in range(220):
        px, py = rng.uniform(0, W), rng.uniform(0.1 * H, H)
        r = rng.uniform(0.6, 2.4) * SS
        al = int(rng.uniform(20, 70))
        fd.ellipse([px - r, py - r, px + r, py + r], fill=(210, 245, 250, al))
    fx_layer = fx_layer.filter(ImageFilter.GaussianBlur(0.7 * SS))

    bub = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bub)
    for _ in range(46):
        px, py = rng.uniform(0, W), rng.uniform(0.12 * H, 1.0 * H)
        r = rng.uniform(2.5, 11.0) * SS
        al = int(rng.uniform(30, 92) * (0.45 + 0.55 * (1 - py / H)))
        bd.ellipse([px - r, py - r, px + r, py + r], outline=(205, 246, 252, al),
                   width=max(1, int(1.3 * SS)))
        hr = r * 0.30
        bd.ellipse([px - r * 0.38 - hr, py - r * 0.38 - hr,
                    px - r * 0.38 + hr, py - r * 0.38 + hr],
                   fill=(230, 252, 255, min(255, al + 45)))
    bub = bub.filter(ImageFilter.GaussianBlur(0.5 * SS))

    scene = Image.alpha_composite(scene, fx_layer)
    scene = Image.alpha_composite(scene, bub)

    return scene


def photo_scene(path):
    """Cover-fit an externally supplied background (e.g. a generated reef photo).

    The image is scaled to cover 1024x500, then given the same legibility
    treatment the procedural scene gets: a cool grade, a depth vignette and a
    darkened lower third, so the wordmark and the card still read over it.
    """
    src = Image.open(path).convert("RGB")
    sw, sh = src.size
    scale = max(W / sw, H / sh)
    src = src.resize((max(W, int(sw * scale)), max(H, int(sh * scale))), Image.LANCZOS)
    sw, sh = src.size
    src = src.crop(((sw - W) // 2, (sh - H) // 2, (sw - W) // 2 + W, (sh - H) // 2 + H))

    arr = np.asarray(src, dtype=np.float64)
    yy2, xx2 = np.mgrid[0:H, 0:W]
    u2, v2 = xx2 / W, yy2 / H
    # Nudge towards the brand teal so a stock photo still looks like ReefTracker.
    arr = arr * 0.88 + np.array(TEAL, dtype=np.float64)[None, None, :] * 0.12
    vig = 1.0 - 0.26 * smoothstep(
        (np.sqrt(((u2 - 0.5) * 1.6) ** 2 + ((v2 - 0.46) * 1.15) ** 2) - 0.44) / 0.56
    )
    arr *= vig[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


BG = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--bg=")), None)
scene = photo_scene(BG) if BG else procedural_scene()

# ------------------------------------------------------------- foreground --

# Legibility scrim behind the wordmark: a soft dark ellipse, nothing hard-edged.
scrim = Image.new("L", (W, H), 0)
ImageDraw.Draw(scrim).ellipse(
    [SAFE_X0 - 0.10 * W, 0.20 * H, SAFE_X0 + 0.44 * W, 0.90 * H], fill=118
)
scrim = scrim.filter(ImageFilter.GaussianBlur(60 * SS))
scene = Image.composite(Image.new("RGBA", (W, H), (3, 26, 42, 255)), scene, scrim)

card_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(card_layer)

# --- frosted chart card ------------------------------------------------------

CX0, CY0, CX1, CY1 = 572 * SS, 116 * SS, 912 * SS, 388 * SS
RAD = 24 * SS
cmask = rounded_mask((W, H), (CX0, CY0, CX1, CY1), RAD)
frost = scene.filter(ImageFilter.GaussianBlur(16 * SS))
scene = Image.composite(frost, scene, cmask)

cd.rounded_rectangle([CX0, CY0, CX1, CY1], radius=RAD, fill=(255, 255, 255, 30))
cd.rounded_rectangle([CX0, CY0, CX1, CY1], radius=RAD,
                     outline=(255, 255, 255, 96), width=max(1, int(1.6 * SS)))

# Plot area inside the card.
PX0, PY0 = CX0 + 26 * SS, CY0 + 56 * SS
PX1, PY1 = CX1 - 26 * SS, CY1 - 62 * SS

# Faint grid, behind everything else in the plot.
for i in range(1, 5):
    gx = PX0 + (PX1 - PX0) * i / 5
    cd.line([(gx, PY0), (gx, PY1)], fill=(255, 255, 255, 20), width=max(1, int(SS)))

# The healthy band — the product's whole promise, "stay in range".
BY0, BY1 = PY0 + (PY1 - PY0) * 0.32, PY0 + (PY1 - PY0) * 0.68
cd.rounded_rectangle([PX0, BY0, PX1, BY1], radius=8 * SS,
                     fill=(HEALTHY_LT[0], HEALTHY_LT[1], HEALTHY_LT[2], 84))
for by in (BY0, BY1):
    cd.line([(PX0, by), (PX1, by)], fill=(HEALTHY_LT + (150,)),
            width=max(1, int(1.4 * SS)))

# Trend line that dips out of range and is brought back in.
series = [0.60, 0.52, 0.44, 0.30, 0.41, 0.49, 0.47, 0.55, 0.51, 0.53]
pts = [
    (PX0 + (PX1 - PX0) * i / (len(series) - 1), PY1 - (PY1 - PY0) * s)
    for i, s in enumerate(series)
]

glow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow_layer).line(pts, fill=(190, 255, 235, 190),
                                width=int(9 * SS), joint="curve")
glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(7 * SS))
card_layer = Image.alpha_composite(card_layer, glow_layer)
cd = ImageDraw.Draw(card_layer)

cd.line(pts, fill=(255, 255, 255, 248), width=int(3.4 * SS), joint="curve")
for i, (px, py) in enumerate(pts):
    r = 5.2 * SS
    inside = BY0 <= py <= BY1
    fill = (255, 255, 255, 255) if inside else (255, 122, 89, 255)
    cd.ellipse([px - r, py - r, px + r, py + r], fill=fill,
               outline=(255, 255, 255, 235), width=max(1, int(1.6 * SS)))

# Card caption.
f_cap = ImageFont.truetype(FONT_SMALL, int(17 * SS))
f_val = ImageFont.truetype(FONT_BODY, int(20 * SS))
cd.text((PX0, CY0 + 22 * SS), "Alkalinity", font=f_cap, fill=(226, 246, 250, 230))
val = "8.3 dKH"
vw = cd.textlength(val, font=f_val)
cd.text((PX1 - vw, CY0 + 20 * SS), val, font=f_val, fill=(HEALTHY_LT + (255,)))

# Status chip under the plot, starting just past the out-of-range point so it
# reads as a comment on the recovery rather than on the whole series.
chip = "back in range"
chw = cd.textlength(chip, font=f_cap)
out_x = max(px for px, py in pts if not (BY0 <= py <= BY1))
chx = min(out_x + 10 * SS, PX1 - chw - 22 * SS)
chy = PY1 + 18 * SS
cd.rounded_rectangle(
    [chx, chy - 4 * SS, chx + chw + 22 * SS, chy + 24 * SS],
    radius=14 * SS, fill=(HEALTHY_LT[0], HEALTHY_LT[1], HEALTHY_LT[2], 54),
    outline=(HEALTHY_LT + (110,)), width=max(1, int(1.2 * SS)),
)
cd.text((chx + 11 * SS, chy + 1 * SS), chip, font=f_cap, fill=(226, 250, 238, 235))

scene = Image.alpha_composite(scene, card_layer)

# --- wordmark ----------------------------------------------------------------

text_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(text_layer)

TX = 118 * SS
TITLE = "ReefTracker"
# Shrink to fit the gap between the left margin and the card — never collide.
max_title_w = CX0 - 46 * SS - TX
size = 76 * SS
while size > 40 * SS:
    f_title = ImageFont.truetype(FONT_TITLE, int(size))
    title_w = td.textlength(TITLE, font=f_title)
    if title_w <= max_title_w:
        break
    size -= 1 * SS
f_tag = ImageFont.truetype(FONT_BODY, int(29 * SS))

td.text((TX, 170 * SS), TITLE, font=f_title, fill=(255, 255, 255, 255))

# Accent rule under the wordmark, in the healthy-green brand colour.
UY = 262 * SS
rule = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(rule)
steps = 120
for i in range(steps):
    t = i / (steps - 1)
    c = tuple(int(HEALTHY[k] + (HEALTHY_LT[k] - HEALTHY[k]) * t) for k in range(3))
    x0 = TX + title_w * i / steps
    x1 = TX + title_w * (i + 1) / steps + 1
    rd.rectangle([x0, UY, x1, UY + 7 * SS], fill=c + (255,))
rule_mask = rounded_mask((W, H), (TX, UY, TX + title_w, UY + 7 * SS), 3.5 * SS)
rule.putalpha(Image.composite(rule.getchannel("A"), Image.new("L", (W, H), 0), rule_mask))
text_layer = Image.alpha_composite(text_layer, rule)
td = ImageDraw.Draw(text_layer)

td.text((TX, 292 * SS), "Track your reef.", font=f_tag, fill=(226, 246, 250, 248))
td.text((TX, 330 * SS), "Stay in range.", font=f_tag, fill=(226, 246, 250, 248))

# Soft drop shadow so the type holds up over the moving water behind it.
shadow = text_layer.getchannel("A").filter(ImageFilter.GaussianBlur(7 * SS))
sh = Image.new("RGBA", (W, H), (2, 20, 34, 0))
sh.putalpha(shadow.point(lambda p: int(p * 0.62)))
sh = sh.transform(sh.size, Image.AFFINE, (1, 0, 0, 0, 1, -3 * SS))

scene = Image.alpha_composite(scene, sh)
scene = Image.alpha_composite(scene, text_layer)

# ----------------------------------------------------------------- output --

final = scene.convert("RGB").resize((OUT_W, OUT_H), Image.LANCZOS)
final.save(OUT, "PNG", optimize=True)
print(f"wrote {OUT} {final.size}")

if "--preview" in sys.argv:
    import tempfile

    d = tempfile.gettempdir()
    cw = OUT_H * 303 / 170
    x0 = int((OUT_W - cw) / 2)
    crop = final.crop((x0, 0, x0 + int(cw), OUT_H)).resize((303, 170), Image.LANCZOS)
    crop.resize((909, 510), Image.NEAREST).save(
        os.path.join(d, "_preview-303x170.png"))
    guides = final.copy()
    g = ImageDraw.Draw(guides)
    g.rectangle([x0, 0, x0 + int(cw) - 1, OUT_H - 1], outline=(255, 0, 0), width=2)
    g.rectangle([SAFE_X0 // SS, 0, SAFE_X1 // SS, OUT_H - 1],
                outline=(255, 220, 0), width=2)
    guides.save(os.path.join(d, "_preview-guides.png"))
    print(f"wrote crop previews to {d} (red = 16:9 crop, yellow = safe box)")
