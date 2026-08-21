"""Generate the reduced AngelCode BMFont bundled with the Isaac mod."""
from __future__ import annotations
import argparse, json, struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

MISSING_GLYPH_PROBE = chr(0x10FFFF)
INTENTIONAL_PLACEHOLDER = "□"

def collect_characters(root: Path) -> list[str]:
    chars = set(chr(code) for code in range(32, 127))
    chars.update("，。！？：；（）【】《》、…×→←↑↓□")
    for path in [root / "main.lua", *sorted((root / "scripts").rglob("*.lua"))]:
        for char in path.read_text(encoding="utf-8"):
            if ord(char) >= 128 and not char.isspace(): chars.add(char)
    return sorted(chars, key=ord)

def block(kind: int, payload: bytes) -> bytes:
    return struct.pack("<BI", kind, len(payload)) + payload

def glyph_signature(font: ImageFont.FreeTypeFont, char: str) -> tuple[object, float, bytes]:
    return font.getbbox(char, stroke_width=1), round(font.getlength(char), 4), bytes(font.getmask(char))

def missing_glyph(font: ImageFont.FreeTypeFont, char: str) -> bool:
    if char == INTENTIONAL_PLACEHOLDER: return False
    return glyph_signature(font, char) == glyph_signature(font, MISSING_GLYPH_PROBE)

def generate(root: Path, source_font: Path, name: str = "achievement_zh", size: int = 16,
             fallback_font: Path | None = None, fallback_size: int = 15) -> None:
    output = root / "resources" / "font"
    output.mkdir(parents=True, exist_ok=True)
    primary = ImageFont.truetype(str(source_font), size=size)
    fallback = ImageFont.truetype(str(fallback_font), size=fallback_size) if fallback_font else None
    ascent, descent = primary.getmetrics()
    line_height, page_size, padding = ascent + descent + 4, 1024, 2
    pages = [Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0))]
    records, x, y, row_height = [], padding, padding, 0
    selected = []
    fallback_chars = []
    unresolved = []
    for char in collect_characters(root):
        font, source = primary, "primary"
        if missing_glyph(primary, char):
            if fallback and not missing_glyph(fallback, char):
                font, source = fallback, "fallback"
                fallback_chars.append(char)
            else:
                unresolved.append(char)
                continue
        selected.append((char, font, source))
    if unresolved:
        details = " ".join(f"{char} (U+{ord(char):04X})" for char in unresolved)
        raise ValueError(f"Unresolved glyphs: {details}")

    for char, font, source in selected:
        bbox = font.getbbox(char, stroke_width=1)
        font_ascent, _ = font.getmetrics()
        baseline_shift = ascent - font_ascent if source == "fallback" else 0
        width, height = max(1, bbox[2]-bbox[0]+padding*2), max(1, bbox[3]-bbox[1]+padding*2)
        if x + width + padding > page_size: x, y, row_height = padding, y + row_height + padding, 0
        if y + height + padding > page_size:
            pages.append(Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0)))
            x, y, row_height = padding, padding, 0
        ImageDraw.Draw(pages[-1]).text((x+padding-bbox[0], y+padding-bbox[1]), char, font=font,
            fill=(255,255,255,255), stroke_width=1, stroke_fill=(0,0,0,255))
        records.append((ord(char), x, y, width, height, bbox[0]-padding,
                        bbox[1]-padding+baseline_shift,
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
    sources = {
        "primaryFont": {"file": source_font.name, "size": size},
        "fallbackFont": {"file": fallback_font.name, "size": fallback_size} if fallback_font else None,
        "glyphCount": len(records),
        "fallbackGlyphs": [
            {"character": char, "codepoint": f"U+{ord(char):04X}"} for char in fallback_chars
        ],
        "unresolvedGlyphs": []
    }
    (output/f"{name}.sources.json").write_text(
        json.dumps(sources, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(records)} glyphs ({len(fallback_chars)} fallback) across {len(pages)} page(s)")

if __name__ == "__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("--font",type=Path,required=True)
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--name", default="achievement_zh")
    parser.add_argument("--size", type=int, default=16)
    parser.add_argument("--fallback-font", type=Path)
    parser.add_argument("--fallback-size", type=int, default=15)
    args=parser.parse_args()
    generate(args.root.resolve(), args.font.resolve(), args.name, args.size,
             args.fallback_font.resolve() if args.fallback_font else None, args.fallback_size)
