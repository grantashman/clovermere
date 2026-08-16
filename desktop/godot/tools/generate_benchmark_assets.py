from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "benchmark"
OUT.mkdir(parents=True, exist_ok=True)

P = {
    "ink": "#1b2c26",
    "deep": "#263a32",
    "shadow": "#152820",
    "grass": "#5c954f",
    "grass_light": "#91b961",
    "leaf_dark": "#21453a",
    "leaf": "#356a47",
    "leaf_light": "#6f9b58",
    "wall": "#b87955",
    "wall_light": "#d49a6a",
    "wall_shadow": "#875342",
    "roof": "#3c4f45",
    "roof_light": "#61715b",
    "roof_dark": "#263a32",
    "timber": "#704936",
    "wood": "#a76645",
    "wood_light": "#c48959",
    "brass": "#e0bb6c",
    "glass": "#9bcbb9",
    "glass_light": "#d1e4bd",
    "skin": "#d49a73",
    "hair": "#4c342d",
    "coat": "#6f875b",
    "coat_blue": "#526f78",
    "stone": "#73766d",
    "stone_light": "#a7a78d",
    "stone_dark": "#4b5a53",
    "ore": "#91b59e",
    "herb": "#a9c987",
    "petal": "#d7b46f",
}


def canvas(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def save(image: Image.Image, name: str) -> None:
    image.save(OUT / name)


def cottage() -> None:
    image, draw = canvas((128, 96))
    draw.polygon([(8, 78), (119, 78), (126, 86), (116, 92), (15, 92), (2, 86)], fill=P["shadow"])
    draw.rectangle((8, 34, 119, 85), fill=P["ink"])
    draw.rectangle((11, 36, 116, 84), fill=P["wall_shadow"])
    draw.rectangle((15, 39, 112, 82), fill=P["wall"])
    draw.rectangle((19, 43, 108, 79), fill=P["wall_light"])
    draw.rectangle((19, 43, 108, 46), fill="#e0a875")

    draw.polygon([(3, 35), (63, 4), (124, 35), (118, 51), (10, 51)], fill=P["roof_dark"])
    draw.polygon([(10, 33), (63, 8), (117, 33), (112, 43), (15, 43)], fill=P["roof"])
    draw.polygon([(18, 32), (63, 12), (108, 32), (104, 37), (20, 37)], fill=P["roof_light"])
    for x in range(25, 106, 13):
        top = int(12 + abs(x - 63) * 0.44)
        draw.line((x, top + 2, x, 38), fill=P["roof_dark"], width=2)
    draw.line((10, 43, 117, 43), fill=P["timber"], width=3)

    draw.rectangle((17, 43, 21, 80), fill=P["timber"])
    draw.rectangle((107, 43, 111, 80), fill=P["timber"])
    draw.rectangle((18, 60, 110, 64), fill=P["timber"])
    draw.rectangle((36, 43, 40, 80), fill=P["timber"])
    draw.rectangle((88, 43, 92, 80), fill=P["timber"])

    for x in (27, 91):
        draw.rectangle((x - 2, 53 - 2, x + 16, 71), fill=P["timber"])
        draw.rectangle((x, 53, x + 14, 69), fill=P["glass"])
        draw.rectangle((x + 2, 55, x + 6, 59), fill=P["glass_light"])
        draw.rectangle((x + 7, 53, x + 9, 69), fill=P["timber"])
        draw.rectangle((x, 60, x + 14, 62), fill=P["timber"])

    draw.rectangle((57, 61, 71, 84), fill=P["timber"])
    draw.rectangle((60, 64, 68, 84), fill=P["wood"])
    draw.rectangle((61, 66, 63, 82), fill=P["wood_light"])
    draw.rectangle((67, 73, 69, 75), fill=P["brass"])
    draw.rectangle((53, 84, 75, 88), fill=P["timber"])
    draw.rectangle((56, 88, 72, 91), fill=P["wood_light"])
    draw.rectangle((103, 12, 112, 34), fill=P["timber"])
    draw.rectangle((105, 9, 110, 15), fill=P["stone_light"])
    draw.rectangle((105, 15, 112, 20), fill=P["stone_dark"])
    draw.rectangle((4, 84, 26, 89), fill=P["grass_dark"] if "grass_dark" in P else P["leaf_dark"])
    draw.rectangle((103, 84, 124, 89), fill=P["leaf_dark"])
    save(image, "cottage.png")


def workshop() -> None:
    image, draw = canvas((144, 112))
    draw.polygon([(5, 91), (135, 91), (143, 101), (132, 108), (13, 108), (0, 101)], fill=P["shadow"])
    draw.rectangle((8, 39, 135, 98), fill=P["ink"])
    draw.rectangle((12, 42, 131, 96), fill=P["wall_shadow"])
    draw.rectangle((16, 45, 127, 93), fill=P["wall"])
    draw.rectangle((20, 48, 123, 90), fill=P["wall_light"])

    draw.polygon([(2, 40), (73, 5), (139, 35), (133, 54), (10, 54)], fill=P["roof_dark"])
    draw.polygon([(10, 38), (73, 10), (131, 34), (126, 46), (15, 46)], fill=P["roof"])
    draw.polygon([(19, 36), (73, 14), (119, 34), (114, 40), (21, 40)], fill=P["roof_light"])
    for x in range(26, 125, 14):
        top = int(14 + abs(x - 73) * 0.38)
        draw.line((x, top + 2, x, 43), fill=P["roof_dark"], width=2)
    draw.line((10, 46, 130, 46), fill=P["timber"], width=4)

    for x in (17, 123):
        draw.rectangle((x, 46, x + 4, 92), fill=P["timber"])
    draw.rectangle((18, 64, 126, 68), fill=P["timber"])
    draw.rectangle((43, 46, 47, 92), fill=P["timber"])
    draw.rectangle((98, 46, 102, 92), fill=P["timber"])

    draw.rectangle((27, 54, 46, 71), fill=P["timber"])
    draw.rectangle((30, 57, 43, 68), fill=P["glass"])
    draw.rectangle((35, 57, 37, 68), fill=P["timber"])
    draw.rectangle((30, 62, 43, 64), fill=P["timber"])
    draw.rectangle((105, 53, 121, 72), fill=P["timber"])
    draw.rectangle((108, 56, 118, 69), fill=P["brass"])
    draw.rectangle((113, 56, 115, 69), fill=P["timber"])
    draw.rectangle((108, 62, 118, 64), fill=P["timber"])

    draw.rectangle((61, 65, 79, 96), fill=P["timber"])
    draw.rectangle((65, 68, 75, 96), fill=P["wood"])
    draw.rectangle((66, 71, 68, 93), fill=P["wood_light"])
    draw.rectangle((76, 80, 78, 82), fill=P["brass"])
    draw.rectangle((56, 96, 84, 100), fill=P["timber"])
    draw.rectangle((59, 100, 81, 103), fill=P["wood_light"])

    # Covered workbench and material rack.
    draw.rectangle((20, 83, 53, 93), fill=P["timber"])
    draw.rectangle((23, 78, 50, 84), fill=P["wood_light"])
    draw.rectangle((25, 84, 29, 93), fill=P["wood"])
    draw.rectangle((44, 84, 48, 93), fill=P["wood"])
    draw.rectangle((25, 76, 30, 81), fill=P["stone_light"])
    draw.rectangle((34, 76, 39, 81), fill=P["stone"])
    draw.rectangle((43, 76, 48, 81), fill=P["ore"])

    # Small hanging workshop sign.
    draw.rectangle((113, 19, 121, 35), fill=P["timber"])
    draw.rectangle((111, 17, 123, 21), fill=P["wood_light"])
    draw.rectangle((115, 22, 119, 30), fill=P["brass"])
    draw.rectangle((116, 24, 118, 28), fill=P["deep"])
    save(image, "workshop.png")


def tree() -> None:
    image, draw = canvas((48, 64))
    draw.polygon([(8, 56), (38, 54), (45, 59), (38, 63), (7, 62), (2, 59)], fill=P["shadow"])
    draw.rectangle((20, 27, 29, 57), fill=P["timber"])
    draw.rectangle((23, 29, 28, 55), fill=P["wood"])
    draw.polygon([(5, 32), (8, 16), (18, 12), (24, 3), (37, 8), (45, 22), (40, 37), (28, 41), (14, 38)], fill=P["leaf_dark"])
    draw.polygon([(10, 28), (12, 17), (21, 13), (25, 7), (35, 11), (41, 22), (36, 31), (25, 35), (15, 32)], fill=P["leaf"])
    draw.rectangle((15, 14, 22, 19), fill=P["leaf_light"])
    draw.rectangle((29, 9, 35, 14), fill=P["leaf_light"])
    draw.rectangle((8, 26, 14, 30), fill=P["leaf_light"])
    draw.rectangle((28, 27, 35, 33), fill=P["leaf_dark"])
    draw.rectangle((15, 34, 22, 39), fill=P["leaf_dark"])
    save(image, "tree.png")


def stone() -> None:
    image, draw = canvas((40, 32))
    draw.polygon([(2, 24), (7, 14), (16, 8), (28, 6), (37, 14), (35, 27), (26, 31), (9, 29)], fill=P["shadow"])
    draw.polygon([(4, 22), (9, 13), (17, 9), (28, 8), (35, 15), (32, 25), (24, 28), (10, 27)], fill=P["stone_dark"])
    draw.polygon([(10, 20), (13, 14), (20, 11), (27, 12), (30, 18), (25, 23), (14, 24)], fill=P["stone"])
    draw.polygon([(14, 14), (20, 11), (27, 12), (23, 16), (17, 17)], fill=P["stone_light"])
    draw.rectangle((7, 24, 18, 26), fill=P["stone_dark"])
    save(image, "stone.png")


def herb() -> None:
    image, draw = canvas((32, 24))
    draw.polygon([(2, 20), (10, 18), (22, 18), (29, 21), (23, 23), (7, 23)], fill=P["shadow"])
    for x, top in ((7, 8), (15, 4), (23, 7)):
        draw.line((x, 20, x - 2, top + 5), fill=P["leaf_dark"], width=2)
        draw.rectangle((x - 5, top + 2, x, top + 5), fill=P["herb"])
        draw.rectangle((x - 1, top, x + 4, top + 3), fill=P["petal"])
    draw.rectangle((13, 14, 18, 20), fill=P["herb"])
    save(image, "herb.png")


def person(name: str, coat: str, hair: str, accent: str) -> None:
    image, draw = canvas((32, 48))
    draw.polygon([(3, 40), (11, 37), (23, 37), (30, 41), (24, 45), (8, 45)], fill=P["shadow"])
    draw.rectangle((9, 25, 23, 40), fill=P["ink"])
    draw.rectangle((10, 20, 22, 35), fill=coat)
    draw.rectangle((19, 21, 23, 35), fill=P["deep"])
    draw.rectangle((7, 24, 10, 34), fill=coat)
    draw.rectangle((10, 35, 14, 41), fill=P["timber"])
    draw.rectangle((18, 35, 22, 41), fill=P["timber"])
    draw.rectangle((11, 7, 21, 20), fill=P["skin"])
    draw.rectangle((9, 5, 23, 10), fill=hair)
    draw.rectangle((10, 8, 12, 17), fill=hair)
    draw.rectangle((20, 8, 22, 16), fill=hair)
    draw.rectangle((12, 12, 14, 14), fill=P["ink"])
    draw.rectangle((18, 12, 20, 14), fill=P["ink"])
    draw.rectangle((13, 24, 19, 27), fill=accent)
    if name == "resident":
        draw.line((24, 22, 29, 12), fill=P["timber"], width=2)
        draw.rectangle((27, 10, 31, 12), fill=P["brass"])
    else:
        draw.rectangle((5, 17, 9, 21), fill=P["brass"])
        draw.rectangle((4, 18, 7, 22), fill=P["leaf_light"])
    save(image, f"{name}.png")


def main() -> None:
    cottage()
    workshop()
    tree()
    stone()
    herb()
    person("player", P["coat"], P["hair"], P["brass"])
    person("resident", P["coat_blue"], "#362f2b", "#c47c55")
    print(f"Generated {len(list(OUT.glob('*.png')))} Clovermere benchmark assets in {OUT}")


if __name__ == "__main__":
    main()
