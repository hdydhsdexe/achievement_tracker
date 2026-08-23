const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const fontDir = path.join(root, "resources/font");

function parseFont(pixelSize) {
  const name = pixelSize === 16 ? "achievement_lanapixel.fnt"
    : `achievement_lanapixel_${pixelSize}.fnt`;
  const data = fs.readFileSync(path.join(fontDir, name));
  const records = new Map();
  let lineHeight = 0;
  for (let offset = 4; offset < data.length;) {
    const type = data.readUInt8(offset);
    const size = data.readUInt32LE(offset + 1);
    const start = offset + 5;
    if (type === 2) lineHeight = data.readUInt16LE(start);
    if (type === 4) {
      for (let cursor = start; cursor < start + size; cursor += 20)
        records.set(data.readUInt32LE(cursor), data.readInt16LE(cursor + 16));
    }
    offset = start + size;
  }
  return {lineHeight, records};
}

function catalogRows() {
  const rows = [];
  for (const file of fs.readdirSync(path.join(root, "scripts/data"))) {
    if (!/^achievements_\d+_\d+\.lua$/.test(file)) continue;
    const source = fs.readFileSync(path.join(root, "scripts/data", file), "utf8");
    for (const line of source.split(/\r?\n/)) {
      const match = line.match(/^\s*a\((\d+),"([^"]*)","([^"]*)","([^"]*)","([^"]*)"/);
      if (match) rows.push({id: Number(match[1]), zh: match[4], en: match[5]});
    }
  }
  assert.equal(rows.length, 641);
  return rows;
}

function textWidth(value, records) {
  return Array.from(value).reduce((sum, character) => {
    const advance = records.get(character.codePointAt(0));
    assert.notEqual(advance, undefined, `missing glyph ${character}`);
    return sum + advance;
  }, 0);
}

function wrap(value, maxWidth, records) {
  const lines = [];
  let current = [];
  let currentWidth = 0;
  const pushCurrent = () => {
    lines.push(current.join(""));
    current = [];
    currentWidth = 0;
  };

  for (const character of Array.from(value)) {
    if (character === "\n") {
      pushCurrent();
      continue;
    }
    const advance = records.get(character.codePointAt(0));
    assert.notEqual(advance, undefined, `missing glyph ${character}`);
    if (current.length > 0 && currentWidth + advance > maxWidth) {
      let space = -1;
      for (let index = current.length - 1; index >= 0; index -= 1) {
        if (current[index] === " ") {
          space = index;
          break;
        }
      }
      if (space >= 0) {
        lines.push(current.slice(0, space).join(""));
        current = current.slice(space + 1);
        currentWidth = textWidth(current.join(""), records);
      } else {
        pushCurrent();
      }
    }
    if (character !== " " || current.length > 0) {
      current.push(character);
      currentWidth += advance;
    }
  }
  if (current.length > 0 || lines.length === 0) lines.push(current.join(""));
  return lines;
}

test("every catalog condition reflows inside the adaptive F3 detail area", () => {
  const rows = catalogRows();
  const screens = [[320, 180], [408, 270], [480, 270], [640, 360], [854, 480]];

  for (const pixelSize of [8, 10, 12]) {
    const font = parseFont(pixelSize);
    for (const language of ["zh", "en"]) {
      for (const [screenWidth, screenHeight] of screens) {
        let panelWidth = Math.min(340, Math.max(270, Math.floor(screenWidth * 0.64)));
        panelWidth = Math.min(panelWidth, screenWidth - 24);
        const panelHeight = Math.min(250, screenHeight - 12);
        const contentWidth = panelWidth - 24;
        const maxDetailLines = Math.max(...rows.map((row) => {
          const lines = wrap(row[language], contentWidth, font.records);
          for (const line of lines)
            assert.ok(textWidth(line, font.records) <= contentWidth);
          return lines.length;
        }));
        const gridTop = 42;
        const contentBottom = panelHeight - 18;
        const detailHeight = (maxDetailLines + 1) * font.lineHeight;
        const availableGridHeight = contentBottom - gridTop - 4 - detailHeight;
        const gridRows = Math.min(9, Math.floor(availableGridHeight / font.lineHeight));
        assert.ok(gridRows >= 1,
          `${screenWidth}x${screenHeight} ${language} ${pixelSize}px must retain a grid row`);
        const detailBottom = gridTop + gridRows * font.lineHeight + 4 + detailHeight;
        assert.ok(detailBottom <= contentBottom,
          `${screenWidth}x${screenHeight} ${language} ${pixelSize}px detail overlaps footer`);
      }
    }
  }
});

test("the longest bilingual conditions wrap without losing content", () => {
  const rows = catalogRows();
  const cases = [[324, "en"], [235, "zh"]];
  for (const pixelSize of [8, 10, 12]) {
    const font = parseFont(pixelSize);
    for (const [id, language] of cases) {
      const value = rows.find((row) => row.id === id)[language];
      const lines = wrap(value, 246, font.records);
      const recovered = language === "zh" ? lines.join("") : lines.join(" ");
      assert.equal(recovered.replace(/\s+/g, " ").trim(),
        value.replace(/\s+/g, " ").trim());
      assert.ok(lines.every((line) => textWidth(line, font.records) <= 246));
    }
  }
});

test("HUD clamps extreme preferences and fits three long multi-line routes", () => {
  const screenWidth = 640;
  const screenHeight = 360;
  const margin = 8;
  const minimumWidth = 120;
  const x = Math.max(margin,
    Math.min(screenWidth - margin - minimumWidth, 600));
  assert.equal(x, 512);
  const maxWidth = screenWidth - margin - x;
  assert.equal(maxWidth, minimumWidth);

  const font = parseFont(16);
  const routeRows = [
    ["ACHIEVEMENT CONDITIONS", 0, 1],
  ];
  for (const id of [324, 325, 326]) {
    routeRows.push([`- #${id} A deliberately long tracked achievement [1/2]`, 0, 1]);
    routeRows.push(["NOW: complete the current floor and preserve the required route", 8, 0.9]);
    routeRows.push(["NEXT: enter the alternate exit and continue toward the final boss", 8, 0.85]);
  }
  routeRows.push(["F3: goals  |  F4: hide", 0, 0.8]);

  let totalHeight = Infinity;
  let chosenPixels = 8;
  for (let pixelSize = 32; pixelSize >= 8; pixelSize -= 1) {
    let height = 0;
    for (const [value, indent, factor] of routeRows) {
      const rowPixels = Math.max(8, Math.round(pixelSize * factor));
      const lines = wrap(value, (maxWidth - indent) * 16 / rowPixels, font.records);
      height += lines.length * Math.max(8, Math.round(12 * rowPixels / 16));
    }
    totalHeight = height;
    chosenPixels = pixelSize;
    if (height <= screenHeight - margin * 2) break;
  }

  assert.ok(chosenPixels >= 8);
  assert.ok(totalHeight <= screenHeight - margin * 2);
  const y = Math.max(margin,
    Math.min(400, screenHeight - margin - totalHeight));
  assert.ok(y >= margin);
  assert.ok(y + totalHeight <= screenHeight - margin);
});
