const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const root = path.resolve(__dirname, "..");
const fontDir = path.join(root, "resources/font");
const read = (file) => fs.readFileSync(path.join(root, file));
const missingFromLanaPixel = [
  0x2020, 0x221e, 0x2265, 0x55dd, 0x5657, 0x56e4, 0x5f11, 0x67b7, 0x6866,
  0x749e, 0x7578, 0x761f, 0x7622, 0x776b, 0x78fa, 0x79fd, 0x7a96,
  0x7f81, 0x7f94, 0x80ef, 0x83c7, 0x8611, 0x86c6, 0x874e, 0x8757,
  0x8759, 0x8760, 0x87c0, 0x87cb, 0x892a, 0x94f2, 0x9540, 0x954d,
  0x9563, 0x988c, 0x9ab0, 0x9afb, 0x9ecf, 0x9f8a, 0x9f8c
].map((codepoint) => String.fromCodePoint(codepoint));

function parseBmFont(data) {
  assert.equal(data.subarray(0, 4).toString("binary"), "BMF\x03");
  const records = new Map();
  let pages = [];
  let fontSize = 0;
  let smooth = null;
  let lineHeight = 0;
  for (let offset = 4; offset < data.length;) {
    const type = data.readUInt8(offset);
    const size = data.readUInt32LE(offset + 1);
    const start = offset + 5;
    if (type === 1) {
      fontSize = data.readInt16LE(start);
      smooth = (data.readUInt8(start + 2) & 0x80) !== 0;
    }
    if (type === 2) lineHeight = data.readUInt16LE(start);
    if (type === 3) pages = data.subarray(start, start + size).toString("utf8").split("\0").filter(Boolean);
    if (type === 4) {
      assert.equal(size % 20, 0);
      for (let cursor = start; cursor < start + size; cursor += 20) {
        records.set(data.readUInt32LE(cursor), {
          x: data.readUInt16LE(cursor + 4), y: data.readUInt16LE(cursor + 6),
          width: data.readUInt16LE(cursor + 8), height: data.readUInt16LE(cursor + 10),
          xoffset: data.readInt16LE(cursor + 12), yoffset: data.readInt16LE(cursor + 14),
          xadvance: data.readInt16LE(cursor + 16), page: data.readUInt8(cursor + 18)
        });
      }
    }
    offset = start + size;
  }
  return {pages, records, fontSize, smooth, lineHeight};
}

function paeth(left, up, upperLeft) {
  const estimate = left + up - upperLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upperLeftDistance = Math.abs(estimate - upperLeft);
  if (leftDistance <= upDistance && leftDistance <= upperLeftDistance) return left;
  return upDistance <= upperLeftDistance ? up : upperLeft;
}

function decodeRgbaPng(data) {
  assert.equal(data.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
  let width = 0;
  let height = 0;
  const compressed = [];
  for (let offset = 8; offset < data.length;) {
    const size = data.readUInt32BE(offset);
    const type = data.subarray(offset + 4, offset + 8).toString("ascii");
    const payload = data.subarray(offset + 8, offset + 8 + size);
    if (type === "IHDR") {
      width = payload.readUInt32BE(0);
      height = payload.readUInt32BE(4);
      assert.deepEqual([...payload.subarray(8, 13)], [8, 6, 0, 0, 0], "font page must be non-interlaced RGBA8");
    }
    if (type === "IDAT") compressed.push(payload);
    offset += size + 12;
  }
  const raw = zlib.inflateSync(Buffer.concat(compressed));
  const stride = width * 4;
  const pixels = Buffer.alloc(stride * height);
  let source = 0;
  for (let y = 0; y < height; y += 1) {
    const filter = raw[source++];
    for (let x = 0; x < stride; x += 1) {
      const value = raw[source++];
      const left = x >= 4 ? pixels[y * stride + x - 4] : 0;
      const up = y > 0 ? pixels[(y - 1) * stride + x] : 0;
      const upperLeft = y > 0 && x >= 4 ? pixels[(y - 1) * stride + x - 4] : 0;
      const predictor = filter === 0 ? 0 : filter === 1 ? left : filter === 2 ? up
        : filter === 3 ? Math.floor((left + up) / 2) : paeth(left, up, upperLeft);
      assert.ok(filter >= 0 && filter <= 4, `unsupported PNG filter ${filter}`);
      pixels[y * stride + x] = (value + predictor) & 0xff;
    }
  }
  return {width, height, pixels};
}

function glyphPixels(record, page) {
  const result = Buffer.alloc(record.width * record.height * 4);
  for (let row = 0; row < record.height; row += 1) {
    const start = ((record.y + row) * page.width + record.x) * 4;
    page.pixels.copy(result, row * record.width * 4, start, start + record.width * 4);
  }
  return result;
}

function runtimeCharacters() {
  const characters = new Set(Array.from({length: 95}, (_, index) => String.fromCodePoint(index + 32)));
  for (const character of "，。！？：；（）【】《》、…×→←↑↓□") characters.add(character);
  const paths = [path.join(root, "main.lua")];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (entry.name.endsWith(".lua")) paths.push(target);
    }
  };
  visit(path.join(root, "scripts"));
  for (const sourcePath of paths) {
    for (const character of fs.readFileSync(sourcePath, "utf8"))
      if (character.codePointAt(0) >= 128 && !/\s/u.test(character)) characters.add(character);
  }
  return characters;
}

test("shared native font contains real glyphs for every runtime character", () => {
  const {pages, records} = parseBmFont(read("resources/font/achievement_lanapixel_11.fnt"));
  const decodedPages = pages.map((page) => decodeRgbaPng(fs.readFileSync(path.join(fontDir, page))));
  for (const character of runtimeCharacters())
    assert.ok(records.has(character.codePointAt(0)), `missing BMFont record for ${character}`);

  const square = records.get("□".codePointAt(0));
  const squarePixels = glyphPixels(square, decodedPages[square.page]);
  const boxed = missingFromLanaPixel.filter((character) => {
    const record = records.get(character.codePointAt(0));
    assert.ok(record, `missing audited BMFont record for ${character}`);
    return record.width === square.width && record.height === square.height
      && glyphPixels(record, decodedPages[record.page]).equals(squarePixels);
  });
  assert.deepEqual(boxed, [], `runtime glyphs still render as boxes: ${boxed.join("")}`);

  const reference = records.get("羊".codePointAt(0));
  for (const character of missingFromLanaPixel) {
    const record = records.get(character.codePointAt(0));
    assert.equal(record.xadvance, reference.xadvance, `${character} must keep the primary CJK advance`);
    assert.ok(record.yoffset >= reference.yoffset - 2,
      `${character} must not extend above the primary CJK line box`);
    assert.ok(record.yoffset + record.height <= reference.yoffset + reference.height + 2,
      `${character} must not extend below the primary CJK line box`);
  }
});

test("native font generation declares primary and fallback sources without unresolved glyphs", () => {
  const generator = read("tools/generate_font.py").toString("utf8");
  const packageJson = JSON.parse(read("package.json"));
  const sourcePath = path.join(fontDir, "achievement_lanapixel_11.sources.json");
  assert.match(generator, /--fallback-font/);
  assert.match(generator, /--fallback-size/);
  assert.match(generator, /--pixel-base-size/);
  assert.match(generator, /Image\.Resampling\.NEAREST/);
  assert.match(generator, /rendering.*binary-nearest/);
  assert.match(generator, /unresolved/i);
  assert.equal(packageJson.devDependencies["@fontpkg/lana-pixel"], "1.3.0");
  assert.equal(packageJson.devDependencies["@fontpkg/source-han-sans-sc"], "2.5.3");
  assert.equal(fs.existsSync(sourcePath), true, "generated glyph source manifest must exist");
  const sources = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
  assert.deepEqual(sources.primaryFont, {file: "LanaPixel.ttf", designSize: 11,
    outputSize: 11, scale: 1, rendering: "binary-nearest"});
  assert.deepEqual(sources.fallbackFont, {file: "SourceHanSansSC-Regular.otf",
    size: 10, rendering: "antialiased"});
  assert.equal(sources.glyphCount, runtimeCharacters().size);
  assert.deepEqual(sources.unresolvedGlyphs, []);
  assert.deepEqual(sources.fallbackGlyphs.map((entry) => entry.character), missingFromLanaPixel);
});

test("HUD and F3 share hard-edged native 11px glyphs and exact 2x/3x integer atlases", () => {
  const decoded = new Map();
  const parsedFonts = new Map();
  for (const [pixelSize, multiplier] of [[11, 1], [22, 2], [33, 3]]) {
    const name = `achievement_lanapixel_${pixelSize}`;
    const parsed = parseBmFont(read(`resources/font/${name}.fnt`));
    parsedFonts.set(pixelSize, parsed);
    assert.equal(parsed.fontSize, pixelSize);
    assert.equal(parsed.smooth, false, `${name} must disable BMFont smoothing`);
    assert.equal(parsed.lineHeight % multiplier, 0,
      `${name} line height must preserve its integer design grid`);
    for (const character of runtimeCharacters())
      assert.ok(parsed.records.has(character.codePointAt(0)), `${name} missing ${character}`);
    const pages = parsed.pages.map((page) => {
      assert.equal(fs.existsSync(path.join(fontDir, page)), true, `${name} missing page ${page}`);
      return decodeRgbaPng(fs.readFileSync(path.join(fontDir, page)));
    });
    decoded.set(pixelSize, pages);

    const sources = JSON.parse(fs.readFileSync(path.join(fontDir, `${name}.sources.json`), "utf8"));
    assert.deepEqual(sources.primaryFont, {file: "LanaPixel.ttf", designSize: 11,
      outputSize: pixelSize, scale: multiplier, rendering: "binary-nearest"});
    assert.deepEqual(sources.fallbackFont, {file: "SourceHanSansSC-Regular.otf",
      size: 10 * multiplier, rendering: "antialiased"});
    assert.equal(sources.glyphCount, runtimeCharacters().size);
    assert.deepEqual(sources.unresolvedGlyphs, []);
    assert.deepEqual(sources.fallbackGlyphs.map((entry) => entry.character), missingFromLanaPixel);
  }

  const base = parsedFonts.get(11);
  const basePages = decoded.get(11);
  for (const [codepoint, record] of base.records) {
    if (missingFromLanaPixel.includes(String.fromCodePoint(codepoint))) continue;
    const pixels = glyphPixels(record, basePages[record.page]);
    for (let offset = 0; offset < pixels.length; offset += 4) {
      const rgba = [...pixels.subarray(offset, offset + 4)];
      assert.ok(rgba[3] === 0 || (rgba[3] === 255
        && (rgba.slice(0, 3).every((value) => value === 0)
          || rgba.slice(0, 3).every((value) => value === 255))),
      `primary U+${codepoint.toString(16)} contains baked antialiasing`);
    }
  }

  for (const [pixelSize, multiplier] of [[22, 2], [33, 3]]) {
    const target = parsedFonts.get(pixelSize);
    const targetPages = decoded.get(pixelSize);
    assert.equal(target.lineHeight, base.lineHeight * multiplier);
    for (const [codepoint, baseRecord] of base.records) {
      if (missingFromLanaPixel.includes(String.fromCodePoint(codepoint))) continue;
      const targetRecord = target.records.get(codepoint);
      for (const metric of ["width", "height", "xoffset", "yoffset", "xadvance"])
        assert.equal(targetRecord[metric], baseRecord[metric] * multiplier,
          `U+${codepoint.toString(16)} ${metric} must scale ${multiplier}x`);
      const basePixels = glyphPixels(baseRecord, basePages[baseRecord.page]);
      const targetPixels = glyphPixels(targetRecord, targetPages[targetRecord.page]);
      const expected = Buffer.alloc(targetPixels.length);
      for (let y = 0; y < targetRecord.height; y += 1) {
        for (let x = 0; x < targetRecord.width; x += 1) {
          const source = (Math.floor(y / multiplier) * baseRecord.width
            + Math.floor(x / multiplier)) * 4;
          const destination = (y * targetRecord.width + x) * 4;
          basePixels.copy(expected, destination, source, source + 4);
        }
      }
      assert.equal(targetPixels.equals(expected), true,
        `U+${codepoint.toString(16)} must be nearest-neighbor scaled`);
    }
  }

  const fallbackHasAntialiasing = missingFromLanaPixel.some((character) => {
    const record = base.records.get(character.codePointAt(0));
    const pixels = glyphPixels(record, basePages[record.page]);
    for (let offset = 0; offset < pixels.length; offset += 4) {
      const [red, green, blue, alpha] = pixels.subarray(offset, offset + 4);
      if ((alpha > 0 && alpha < 255)
        || (alpha > 0 && !([red, green, blue].every((value) => value === 0)
          || [red, green, blue].every((value) => value === 255)))) return true;
    }
    return false;
  });
  assert.equal(fallbackHasAntialiasing, true,
    "Source Han fallback glyphs must retain antialiasing");

  for (const obsolete of fs.readdirSync(fontDir)
    .filter((file) => /^achievement_lanapixel_(?:8|10|12)(?:[_.]|$)/.test(file)))
    assert.fail(`obsolete F3 font asset still ships: ${obsolete}`);
  for (const obsolete of ["achievement_lanapixel.fnt", "achievement_lanapixel_0.png",
    "achievement_lanapixel.sources.json"])
    assert.equal(fs.existsSync(path.join(fontDir, obsolete)), false,
      `obsolete scaled HUD font asset still ships: ${obsolete}`);
});
