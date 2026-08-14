"""Generate the original 5x16px fallback reward-type atlas."""

from pathlib import Path

from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parents[1] / "resources/gfx/ui/achievement_reward_types.png"
INK = (65, 43, 32, 255)
ACCENT = (151, 92, 31, 255)
PAPER = (219, 194, 154, 255)


def line(draw, points, fill=INK, width=2):
    draw.line(points, fill=fill, width=width)


def character(draw, x):
    draw.ellipse((x + 4, 2, x + 12, 10), fill=PAPER, outline=INK, width=2)
    draw.point((x + 6, 6), fill=INK)
    draw.point((x + 10, 6), fill=INK)
    line(draw, [(x + 3, 15), (x + 5, 11), (x + 11, 11), (x + 13, 15)])


def area(draw, x):
    line(draw, [(x + 2, 14), (x + 5, 7), (x + 8, 11), (x + 11, 4), (x + 14, 14)])
    line(draw, [(x + 1, 14), (x + 15, 14)])
    draw.rectangle((x + 7, 11, x + 9, 14), fill=ACCENT)


def challenge(draw, x):
    draw.ellipse((x + 3, 2, x + 13, 12), fill=PAPER, outline=INK, width=2)
    draw.rectangle((x + 5, 12, x + 7, 15), fill=INK)
    draw.rectangle((x + 9, 12, x + 11, 15), fill=INK)
    draw.rectangle((x + 5, 5, x + 7, 7), fill=ACCENT)
    draw.rectangle((x + 9, 5, x + 11, 7), fill=ACCENT)


def feature(draw, x):
    draw.ellipse((x + 4, 4, x + 12, 12), fill=PAPER, outline=INK, width=2)
    draw.ellipse((x + 7, 7, x + 9, 9), fill=ACCENT)
    for dx, dy in ((7, 1), (7, 13), (1, 7), (13, 7), (3, 3), (11, 3), (3, 11), (11, 11)):
        draw.rectangle((x + dx, dy, x + dx + 2, dy + 2), fill=INK)


def other(draw, x):
    line(draw, [(x + 5, 5), (x + 6, 2), (x + 10, 2), (x + 12, 4), (x + 12, 7), (x + 9, 10)])
    draw.rectangle((x + 7, 9, x + 9, 11), fill=ACCENT)
    draw.rectangle((x + 7, 13, x + 9, 15), fill=INK)


def main():
    image = Image.new("RGBA", (80, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for index, painter in enumerate((character, area, challenge, feature, other)):
        painter(draw, index * 16)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"Generated {OUT} ({image.width}x{image.height})")


if __name__ == "__main__":
    main()
