"""Generates the app icon from the foundation's logo.

The mark is lifted out of assets/images/logo.png rather than redrawn, so the
icon carries the organisation's own identity and not an approximation of it.

Two deliberate departures from the logo:

  * the "BE HUMAN" lettering is dropped. It arcs around the outside of the
    mark and is illegible below roughly 200px; at 48dp on a launcher it is a
    grey smudge that makes the whole icon look out of focus.
  * the mark is inverted to white on a brand-blue field. The logo is dark navy
    ink, and the previous icon set it on a near-black square — dark on dark,
    which is why it vanished among the icons either side of it.

The lettering is only dropped from the *icon*. Everywhere the logo appears at
a readable size — the statement header, the splash — it is used whole.
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
LOGO = REPO / "assets/images/logo.png"

# The circular mark inside the logo, measured from the source: the lettering
# sits outside this radius and is excluded by the mask in extract_mark.
CENTRE = (241.0, 289.0)
RADIUS = 202.0  # a few px past the ring, so its outer antialiasing survives

# Brand blues. The light end is AppColors.brand; the dark end is the logo's own
# ink, so the gradient stays inside the identity rather than inventing a
# palette that exists only on the icon.
GRADIENT_TOP = (74, 144, 217)
GRADIENT_BOTTOM = (6, 45, 106)

# How much of the canvas the mark covers. The adaptive figure is much smaller
# because Android masks that canvas to the launcher's shape and may crop the
# outer third: 0.55 of 108dp is 59dp, inside the 66dp circle that is
# guaranteed to survive any mask.
LEGACY_FRACTION = 0.66
ADAPTIVE_FRACTION = 0.55


def extract_mark(size: int) -> Image.Image:
    """The hand-and-globe mark, white, on transparency."""
    source = np.array(Image.open(LOGO).convert("RGBA")).astype(float)
    rgb, alpha = source[..., :3], source[..., 3]

    height, width = alpha.shape
    yy, xx = np.mgrid[0:height, 0:width]
    inside = ((xx - CENTRE[0]) ** 2 + (yy - CENTRE[1]) ** 2) <= RADIUS**2

    # Coverage, not a threshold. The logo is dark ink on white, so how dark a
    # pixel is *is* how much ink covers it; using that as the alpha channel
    # keeps every antialiased edge instead of producing a jagged cut-out.
    luminance = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    coverage = np.clip(1.0 - luminance / 255.0, 0.0, 1.0) * (alpha / 255.0) * inside

    mark = np.zeros((height, width, 4), dtype=np.uint8)
    mark[..., :3] = 255
    mark[..., 3] = (coverage * 255).round().astype(np.uint8)

    image = Image.fromarray(mark, "RGBA")
    return image.crop(image.getbbox()).resize((size, size), Image.LANCZOS)


def gradient(size: int) -> Image.Image:
    """A vertical brand-blue field."""
    top = np.array(GRADIENT_TOP, dtype=float)
    bottom = np.array(GRADIENT_BOTTOM, dtype=float)
    ramp = np.linspace(0.0, 1.0, size)[:, None]
    column = top[None, :] * (1 - ramp) + bottom[None, :] * ramp
    field = np.repeat(column[:, None, :], size, axis=1)
    return Image.fromarray(field.round().astype(np.uint8), "RGB").convert("RGBA")


def icon(size: int, corner_fraction: float | None = None) -> Image.Image:
    """One square icon: the mark centred on the gradient.

    `corner_fraction` rounds the corners for platforms that do not mask the
    icon themselves; None leaves it square for those that do.
    """
    canvas = gradient(size)
    mark_size = round(size * LEGACY_FRACTION)
    offset = (size - mark_size) // 2
    canvas.alpha_composite(extract_mark(mark_size), (offset, offset))

    if corner_fraction is not None:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=round(size * corner_fraction), fill=255
        )
        canvas.putalpha(mask)
    return canvas


def circular(size: int) -> Image.Image:
    """Round variant, for launchers that ask for one."""
    canvas = icon(size)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    canvas.putalpha(mask)
    return canvas


def adaptive_foreground(size: int) -> Image.Image:
    """The mark alone, on the transparent canvas Android composites."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark_size = round(size * ADAPTIVE_FRACTION)
    offset = (size - mark_size) // 2
    canvas.alpha_composite(extract_mark(mark_size), (offset, offset))
    return canvas


# --- Android ---------------------------------------------------------------

LEGACY_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive layers are authored on a 108dp canvas at every density.
ADAPTIVE_DENSITIES = {
    "mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432,
}

res = REPO / "android/app/src/main/res"
for density, size in LEGACY_DENSITIES.items():
    folder = res / f"mipmap-{density}"
    folder.mkdir(parents=True, exist_ok=True)
    # Softened corners: this bitmap is the fallback on Android 7 and older,
    # where nothing masks it.
    icon(size, corner_fraction=0.22).save(folder / "ic_launcher.png")
    circular(size).save(folder / "ic_launcher_round.png")

for density, size in ADAPTIVE_DENSITIES.items():
    folder = res / f"mipmap-{density}"
    adaptive_foreground(size).save(folder / "ic_launcher_foreground.png")
    gradient(size).save(folder / "ic_launcher_background.png")

# --- iOS -------------------------------------------------------------------

# Every size the asset catalogue already lists is regenerated. iOS rounds the
# corners itself and rejects an icon with an alpha channel, so these are square
# and fully opaque.
ios = REPO / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
catalogue = json.loads((ios / "Contents.json").read_text())
for entry in catalogue["images"]:
    if "filename" not in entry:
        continue
    points = float(entry["size"].split("x")[0])
    scale = int(entry["scale"].rstrip("x"))
    pixels = round(points * scale)
    icon(pixels).convert("RGB").save(ios / entry["filename"])

print("Icons written. Rebuild the app to see them:")
print("  flutter clean && flutter build apk --dart-define-from-file=env.json")
