"""Generate the reduced AngelCode BMFont bundled with the Isaac mod."""
from __future__ import annotations
import argparse, json, struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

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

def write_font(output: Path, name: str, size: int, line_height: int, base_height: int,
               pages: list[Image.Image], records: list[tuple[int, ...]],
               sources: dict[str, object]) -> None:
    names = []
    for index, page in enumerate(pages):
        page_name = f"{name}_{index}.png"
        page.save(output / page_name, optimize=True)
        names.append(page_name)
    internal_name = ("AchievementTracker-" + name).encode("ascii", "replace") + b"\0"
    info = struct.pack("<hBBHBBBBBBBB", size,0,1,100,1,1,1,1,1,1,1,1) + internal_name
    common = struct.pack("<HHHHHBBBBB", line_height,base_height,1024,1024,len(pages),0,0,4,4,4)
    page_data = b"".join(page.encode()+b"\0" for page in names)
    chars = b"".join(struct.pack("<IHHHHhhhBB", *record) for record in records)
    (output / f"{name}.fnt").write_bytes(
        b"BMF\x03" + block(1, info) + block(2, common) + block(3, page_data) + block(4, chars))
    (output / f"{name}.sources.json").write_text(
        json.dumps(sources, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def binary_primary_glyph(font: ImageFont.FreeTypeFont, char: str,
                         multiplier: int) -> tuple[Image.Image, int, int, int]:
    bbox = font.getbbox(char)
    border = 3
    width = max(1, bbox[2] - bbox[0] + border * 2)
    height = max(1, bbox[3] - bbox[1] + border * 2)
    fill = Image.new("L", (width, height), 0)
    ImageDraw.Draw(fill).text((border - bbox[0], border - bbox[1]), char,
                              font=font, fill=255)
    fill = fill.point(lambda value: 255 if value >= 128 else 0)
    outline = fill.filter(ImageFilter.MaxFilter(3))
    glyph = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    glyph.paste(Image.new("RGBA", glyph.size, (0, 0, 0, 255)), mask=outline)
    glyph.paste(Image.new("RGBA", glyph.size, (255, 255, 255, 255)), mask=fill)
    if multiplier > 1:
        glyph = glyph.resize((width * multiplier, height * multiplier),
                             Image.Resampling.NEAREST)
    return (glyph, (bbox[0] - border) * multiplier,
            (bbox[1] - border) * multiplier,
            max(1, round(font.getlength(char))) * multiplier)

def antialiased_fallback_glyph(font: ImageFont.FreeTypeFont, char: str, padding: int,
                               stroke_width: int, baseline_shift: int,
                               xadvance: int) -> tuple[Image.Image, int, int, int]:
    bbox = font.getbbox(char, stroke_width=stroke_width)
    width = max(1, bbox[2] - bbox[0] + padding * 2)
    height = max(1, bbox[3] - bbox[1] + padding * 2)
    glyph = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    ImageDraw.Draw(glyph).text((padding - bbox[0], padding - bbox[1]), char,
        font=font, fill=(255,255,255,255), stroke_width=stroke_width,
        stroke_fill=(0,0,0,255))
    return glyph, bbox[0] - padding, bbox[1] - padding + baseline_shift, xadvance

def generate_pixel_font(root: Path, source_font: Path, fallback_font: Path, name: str,
                        size: int, fallback_size: int, pixel_base_size: int) -> None:
    if size % pixel_base_size != 0:
        raise ValueError("Pixel font output size must be an integer multiple of its design base")
    multiplier = size // pixel_base_size
    expected_fallback_size = 10 * multiplier
    if fallback_size != expected_fallback_size:
        raise ValueError(f"Fallback size must be {expected_fallback_size} for {size}px output")
    output = root / "resources" / "font"
    output.mkdir(parents=True, exist_ok=True)
    primary = ImageFont.truetype(str(source_font), size=pixel_base_size)
    fallback = ImageFont.truetype(str(fallback_font), size=fallback_size)
    base_ascent, base_descent = primary.getmetrics()
    fallback_ascent, _ = fallback.getmetrics()
    line_height = (base_ascent + base_descent + 4) * multiplier
    base_height = (base_ascent + 2) * multiplier
    page_size = 1024
    pages = [Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0))]
    records, x, y, row_height = [], 2 * multiplier, 2 * multiplier, 0
    fallback_chars, unresolved, selected = [], [], []
    for char in collect_characters(root):
        if not missing_glyph(primary, char):
            selected.append((char, "primary"))
        elif not missing_glyph(fallback, char):
            selected.append((char, "fallback"))
            fallback_chars.append(char)
        else:
            unresolved.append(char)
    if unresolved:
        details = " ".join(f"{char} (U+{ord(char):04X})" for char in unresolved)
        raise ValueError(f"Unresolved glyphs: {details}")

    cjk_advance = max(1, round(primary.getlength("羊"))) * multiplier
    atlas_gap = 2 * multiplier
    for char, source in selected:
        if source == "primary":
            glyph, xoffset, yoffset, xadvance = binary_primary_glyph(
                primary, char, multiplier)
        else:
            glyph, xoffset, yoffset, xadvance = antialiased_fallback_glyph(
                fallback, char, 2 * multiplier, multiplier,
                base_ascent * multiplier - fallback_ascent, cjk_advance)
        width, height = glyph.size
        if x + width + atlas_gap > page_size:
            x, y, row_height = atlas_gap, y + row_height + atlas_gap, 0
        if y + height + atlas_gap > page_size:
            pages.append(Image.new("RGBA", (page_size, page_size), (255, 255, 255, 0)))
            x, y, row_height = atlas_gap, atlas_gap, 0
        pages[-1].alpha_composite(glyph, (x, y))
        records.append((ord(char), x, y, width, height, xoffset, yoffset,
                        xadvance, len(pages)-1, 15))
        x, row_height = x + width + atlas_gap, max(row_height, height)

    sources = {
        "primaryFont": {"file": source_font.name, "designSize": pixel_base_size,
                        "outputSize": size, "scale": multiplier,
                        "rendering": "binary-nearest"},
        "fallbackFont": {"file": fallback_font.name, "size": fallback_size,
                         "rendering": "antialiased"},
        "glyphCount": len(records),
        "fallbackGlyphs": [
            {"character": char, "codepoint": f"U+{ord(char):04X}"} for char in fallback_chars
        ],
        "unresolvedGlyphs": []
    }
    write_font(output, name, size, line_height, base_height, pages, records, sources)
    print(f"Generated {len(records)} glyphs ({len(fallback_chars)} fallback) "
          f"at {multiplier}x across {len(pages)} page(s)")

def generate(root: Path, source_font: Path, name: str = "achievement_zh", size: int = 16,
             fallback_font: Path | None = None, fallback_size: int = 15,
             pixel_base_size: int | None = None) -> None:
    if pixel_base_size is not None:
        if fallback_font is None:
            raise ValueError("Pixel font generation requires --fallback-font")
        generate_pixel_font(root, source_font, fallback_font, name, size,
                            fallback_size, pixel_base_size)
        return
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
    parser.add_argument("--pixel-base-size", type=int)
    args=parser.parse_args()
    generate(args.root.resolve(), args.font.resolve(), args.name, args.size,
             args.fallback_font.resolve() if args.fallback_font else None, args.fallback_size,
             args.pixel_base_size)
