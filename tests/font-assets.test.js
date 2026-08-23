const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const root = path.resolve(__dirname, "..");
const fontDir = path.join(root, "resources/font");
const read = (file) => fs.readFileSync(path.join(root, file));
const missingFromLanaPixel = [
  0x2020, 0x221e, 0x55dd, 0x5657, 0x56e4, 0x5f11, 0x67b7, 0x6866,
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

test("bundled font contains real glyphs for every runtime character", () => {
  const {pages, records} = parseBmFont(read("resources/font/achievement_lanapixel.fnt"));
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

test("font generation declares primary and fallback sources without unresolved glyphs", () => {
  const generator = read("tools/generate_font.py").toString("utf8");
  const packageJson = JSON.parse(read("package.json"));
  const sourcePath = path.join(fontDir, "achievement_lanapixel.sources.json");
  assert.match(generator, /--fallback-font/);
  assert.match(generator, /--fallback-size/);
  assert.match(generator, /unresolved/i);
  assert.equal(packageJson.devDependencies["@fontpkg/lana-pixel"], "1.3.0");
  assert.equal(packageJson.devDependencies["@fontpkg/source-han-sans-sc"], "2.5.3");
  assert.equal(fs.existsSync(sourcePath), true, "generated glyph source manifest must exist");
  const sources = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
  assert.deepEqual(sources.primaryFont, {file: "LanaPixel.ttf", size: 16});
  assert.deepEqual(sources.fallbackFont, {file: "SourceHanSansSC-Regular.otf", size: 15});
  assert.equal(sources.glyphCount, runtimeCharacters().size);
  assert.deepEqual(sources.unresolvedGlyphs, []);
  assert.deepEqual(sources.fallbackGlyphs.map((entry) => entry.character), missingFromLanaPixel);
});

test("F3 ships native unsmoothed 8, 10, and 12 pixel fonts with complete glyph coverage", () => {
  for (const pixelSize of [8, 10, 12]) {
    const name = `achievement_lanapixel_${pixelSize}`;
    const parsed = parseBmFont(read(`resources/font/${name}.fnt`));
    assert.equal(parsed.fontSize, pixelSize);
    assert.equal(parsed.smooth, false, `${name} must disable BMFont smoothing`);
    assert.ok(parsed.lineHeight >= pixelSize, `${name} must expose a usable native line height`);
    for (const character of runtimeCharacters())
      assert.ok(parsed.records.has(character.codePointAt(0)), `${name} missing ${character}`);
    for (const page of parsed.pages)
      assert.equal(fs.existsSync(path.join(fontDir, page)), true, `${name} missing page ${page}`);

    const sources = JSON.parse(fs.readFileSync(path.join(fontDir, `${name}.sources.json`), "utf8"));
    assert.deepEqual(sources.primaryFont, {file: "LanaPixel.ttf", size: pixelSize});
    assert.deepEqual(sources.fallbackFont,
      {file: "SourceHanSansSC-Regular.otf", size: pixelSize - 1});
    assert.equal(sources.glyphCount, runtimeCharacters().size);
    assert.deepEqual(sources.unresolvedGlyphs, []);
  }
});
