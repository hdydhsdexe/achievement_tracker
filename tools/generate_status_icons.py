"""Generate the five-frame F3 achievement status atlas."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "gfx" / "ui" / "achievement_status_icons.png"
FRAME_SIZE = 7


def outlined(frame: Image.Image, points: set[tuple[int, int]]) -> None:
    for x, y in points:
        for offset_y in (-1, 0, 1):
            for offset_x in (-1, 0, 1):
                target_x, target_y = x + offset_x, y + offset_y
                if 0 <= target_x < FRAME_SIZE and 0 <= target_y < FRAME_SIZE:
                    frame.putpixel((target_x, target_y), (0, 0, 0, 255))
    for point in points:
        frame.putpixel(point, (255, 255, 255, 255))


def main() -> None:
    atlas = Image.new("RGBA", (36, 8), (0, 0, 0, 0))
    shapes = [
        {(1, 3), (2, 4), (3, 3), (4, 2), (5, 1)},
        {(3, 2), (2, 3), (3, 3), (4, 3), (3, 4)},
        {(1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (4, 1),
         (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (2, 5)},
        {(3, 1), (2, 3), (3, 3), (4, 3), (2, 4), (3, 4), (4, 4),
         (2, 5), (4, 5)},
        {(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
         (5, 1), (4, 2), (2, 4), (1, 5)},
    ]
    for index, points in enumerate(shapes):
        frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        outlined(frame, points)
        atlas.alpha_composite(frame, (index * FRAME_SIZE, 0))
    atlas.putpixel((35, 7), (255, 255, 255, 255))
    atlas.save(OUTPUT, optimize=True)


if __name__ == "__main__":
    main()
