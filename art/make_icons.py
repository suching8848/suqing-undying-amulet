from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
ART = PROJECT / "art"
MOD = PROJECT / "Contents" / "mods" / "SuQingUndyingAmulet" / "42"
TEXTURES = MOD / "media" / "textures"


def fit_art(image, size, inset):
    occupied = image.getchannel("A").getbbox()
    icon = image.crop(occupied)
    icon.thumbnail((size - inset * 2, size - inset * 2), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(icon, ((size - icon.width) // 2, (size - icon.height) // 2))
    return canvas


def broken_inventory_icon():
    image = Image.new("RGBA", (32, 32))
    draw = ImageDraw.Draw(image)
    outline = "#241b35"
    silver = "#c1becf"
    shadow = "#7e7a96"
    purple = "#7653a0"
    glow = "#b997e4"

    draw.polygon([(12, 3), (17, 3), (19, 6), (19, 10), (16, 12),
                  (10, 10), (10, 5)], fill=outline)
    draw.line([(12, 8), (12, 5), (16, 5), (17, 8)], fill=shadow, width=2)

    draw.polygon([(13, 9), (21, 12), (17, 15), (16, 14), (12, 20),
                  (8, 16), (5, 17)], fill=outline)
    draw.polygon([(13, 11), (18, 12), (16, 14), (14, 14),
                  (12, 18), (8, 15)], fill=silver)
    draw.polygon([(13, 12), (15, 13), (12, 16), (11, 15)], fill=purple)
    draw.line([(9, 15), (13, 11)], fill="#f0eef8")

    draw.polygon([(24, 13), (29, 19), (18, 30), (11, 25), (13, 23),
                  (16, 24), (20, 17), (22, 18)], fill=outline)
    draw.polygon([(24, 15), (27, 19), (18, 28), (13, 25), (15, 25),
                  (18, 23), (21, 19), (23, 20)], fill=shadow)
    draw.polygon([(24, 17), (25, 19), (18, 26), (16, 25), (21, 20), (23, 21)], fill=purple)
    draw.line([(24, 15), (27, 19), (24, 22)], fill=silver)
    draw.line([(22, 21), (21, 23)], fill=glow)
    draw.point([(17, 19), (16, 20), (10, 22)], fill=glow)
    return image


with Image.open(ART / "amulet-icon-master.png") as master:
    image = master.convert("RGBA")
    fit_art(image, 128, 5).save(MOD / "icon-v020.png")
    fit_art(image, 32, 1).save(TEXTURES / "Item_SQUA_UndyingAmuletV2.png")

broken_inventory_icon().save(TEXTURES / "Item_SQUA_BrokenUndyingAmuletV2.png")
