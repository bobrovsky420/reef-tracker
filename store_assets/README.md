# Store assets

| File | Used for |
|------|----------|
| `app-icon-512.png`, `app-icon-dark-512.png` | Play / App Store listing icon |
| `feature-graphic.png` | Play Store feature graphic – **must be exactly 1024×500** |
| `screenshots/` | Store screenshots (see the guide-screenshot harness) |
| `release_notes/<version>/<lang>.txt` | Store "What's new" text, per release |

## Feature graphic

`feature-graphic.png` is generated – do not hand-edit it. Regenerate with:

```powershell
python -m pip install pillow numpy fonttools brotli   # once
python tool\gen_feature_graphic.py --preview
```

`--preview` additionally writes `_preview-303x170.png` and `_preview-guides.png`
into `%TEMP%` so the crop can be checked before committing.

### Wordmark font

The wordmark is **Bricolage Grotesque ExtraBold**, the same face the website
uses. There is no second copy of it: the generator reads
`docs/fonts/BricolageGrotesque-latin.woff2` (the subset the site serves) and
decompresses it to a TTF cached in `%TEMP%`, because FreeType cannot load woff2.
That is what `fonttools` and `brotli` are for. It is a variable font; the
generator pins the axes to `opsz 96, wght 800`.

The wordmark is positioned by its **ink box**, not by the font's own metrics, so
changing the face or its size does not shift it relative to the green accent
rule – the rule is drawn to match the measured ink width.

### The 303×170 crop rule

The store requires a 1024×500 upload (aspect 2.048), but several placements –
the 303×170 listing card most visibly – **cover-crop it to roughly 16:9**. That
slices **66 px off each side**, so anything closer than that to the edge is cut.

The generator therefore keeps every element that must stay readable inside a
safe box of `x ∈ [110, 914]` (66 px of crop plus 44 px of breathing room), and
puts only decoration – rock and coral silhouettes – outside it. The wordmark
auto-shrinks to fit the gap between the left margin and the chart card, so it
can never collide with it if the copy changes.

The three fish (clownfish, blue tang, yellow tang) are drawn from the `FISH`
table in the generator and placed by `place_fish()` into the open water the
layout leaves free. If the copy or the card geometry changes, re-check that they
still sit clear of the type – they are positioned by hand, not solved for.

Verify with `_preview-303x170.png` after any edit.

### Using a different backdrop

The script can layer the wordmark, chart card and safe-area layout over an
external image instead of the procedural reef scene:

```powershell
python tool\gen_feature_graphic.py --bg=path\to\background.png --preview
```

The image is cover-fitted to 1024×500, graded towards the brand teal and given
the same vignette, so the foreground stays legible. Use it if you ever swap in a
photographic or painted reef background – see [Producing a painted backdrop
](#producing-a-painted-backdrop).

### Producing a painted backdrop

Anthropic does not ship an image-generation model – Claude writes code and
vector/SVG art, it does not paint raster images. So there are three routes, in
order of how much they cost you:

1. **The generator above** (current asset). Fully reproducible, version-
   controlled, no licensing questions.
2. **A Claude Artifact.** Ask Claude for a self-contained HTML/CSS/SVG reef
   scene at a 1024×500 aspect, publish it as an artifact and screenshot it at
   2× (2048×1000). This is the same class of output as the Python generator –
   procedural gradients, rays and silhouettes – so only reach for it if you
   prefer iterating in a browser.
3. **A third-party image generator for the backdrop only**, then composite with
   `--bg=`. This is the only route to a photographic or painted look. Claude
   cannot generate the image, but the prompt below is ready to paste into
   Midjourney, DALL·E 3, Adobe Firefly or Stable Diffusion.

> Prompt: *Underwater reef aquarium scene viewed from below the water line,
> wide cinematic 2:1 banner. Rippled water surface across the top with bright
> caustics on its underside; distinct volumetric god rays fanning down from the
> surface all the way to a pale sand bed at the bottom. Deep teal-to-navy depth
> gradient, turquoise near the surface. Dark coral and rock silhouettes only at
> the far left and right edges, open water and clean sand across the middle.
> Fine marine snow and a few small bubbles. Photorealistic, soft focus, no text,
> no logos, no fish in the centre, uncluttered centre-left area.*

Two constraints when using route 3:

- **Keep the middle empty.** The wordmark occupies the left third and the chart
  card the right third; the generator only darkens, it cannot remove clutter.
- **Check the licence.** Store listing artwork is commercial use. Confirm the
  generator's terms allow it, and keep the source image and its provenance with
  the asset.
