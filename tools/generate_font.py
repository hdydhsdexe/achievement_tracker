"""Generate the reduced AngelCode BMFont bundled with the Isaac mod."""
from __future__ import annotations
import argparse, struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

def collect_characters(root: Path) -> list[str]:
    chars = set(chr(code) for code in range(32, 127))
    chars.update("，。！？：；（）【】《》、…×→←↑↓□")
    for path in [root / "main.lua", *sorted((root / "scripts").rglob("*.lua"))]:
        for char in path.read_text(encoding="utf-8"):
            if ord(char) >= 128 and not char.isspace(): chars.add(char)
    return sorted(chars, key=ord)

def block(kind: int, payload: bytes) -> bytes:
    return struct.pack("<BI", kind, len(payload)) + payload

def generate(root: Path, source_font: Path, name: str = "achievement_zh", size: int = 16) -> None:
    output = root / "resources" / "font"
    output.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(source_font), size=size)
    ascent, descent = font.getmetrics()
    line_height, page_size, padding = ascent + descent + 4, 1024, 2
    pages = [Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0))]
    records, x, y, row_height = [], padding, padding, 0
    for char in collect_characters(root):
        bbox = font.getbbox(char, stroke_width=1)
        width, height = max(1, bbox[2]-bbox[0]+padding*2), max(1, bbox[3]-bbox[1]+padding*2)
        if x + width + padding > page_size: x, y, row_height = padding, y + row_height + padding, 0
        if y + height + padding > page_size:
            pages.append(Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0)))
            x, y, row_height = padding, padding, 0
        ImageDraw.Draw(pages[-1]).text((x+padding-bbox[0], y+padding-bbox[1]), char, font=font,
            fill=(255,255,255,255), stroke_width=1, stroke_fill=(0,0,0,255))
        records.append((ord(char), x, y, width, height, bbox[0]-padding, bbox[1]-padding,
                        max(1, round(font.getlength(char))), len(pages)-1, 15))
        x, row_height = x + width + padding, max(row_height, height)
    names = []
    for index, page in enumerate(pages):
        page_name = f"{name}_{index}.png"; page.save(output/page_name, optimize=True); names.append(page_name)
    internal_name = ("AchievementTracker-" + name).encode("ascii", "replace") + b"\0"
    info = struct.pack("<hBBHBBBBBBBB", size,0,1,100,1,1,1,1,1,1,1,1) + internal_name
    common = struct.pack("<HHHHHBBBBB", line_height,ascent+2,page_size,page_size,len(pages),0,0,4,4,4)
    page_data = b"".join(name.encode()+b"\0" for name in names)
    chars = b"".join(struct.pack("<IHHHHhhhBB", *record) for record in records)
    (output/f"{name}.fnt").write_bytes(b"BMF\x03"+block(1,info)+block(2,common)+block(3,page_data)+block(4,chars))
    print(f"Generated {len(records)} glyphs across {len(pages)} page(s)")

if __name__ == "__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("--font",type=Path,required=True)
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--name", default="achievement_zh")
    parser.add_argument("--size", type=int, default=16)
    args=parser.parse_args()
    generate(args.root.resolve(), args.font.resolve(), args.name, args.size)
