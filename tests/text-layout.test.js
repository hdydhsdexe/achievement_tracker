const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const fontDir = path.join(root, "resources/font");

function parseFont(pixelSize) {
  const name = `achievement_lanapixel_${pixelSize}.fnt`;
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

const F3_PIXEL_TIERS = [11, 22, 33];

function fitF3Layout(requestedPixels, language, screenWidth, screenHeight, rows, fonts) {
  const maximumPanelWidth = screenWidth - 24;
  const maximumPanelHeight = screenHeight - 12;
  let basePanelWidth = Math.min(340,
    Math.max(270, Math.floor(screenWidth * 0.64)));
  basePanelWidth = Math.min(basePanelWidth, maximumPanelWidth);
  const basePanelHeight = Math.min(250, maximumPanelHeight);
  const requestedIndex = F3_PIXEL_TIERS.indexOf(requestedPixels);
  for (let tierIndex = requestedIndex; tierIndex >= 0; tierIndex -= 1) {
    const pixelSize = F3_PIXEL_TIERS[tierIndex];
    const font = fonts.get(pixelSize);
    const gridTop = 10 + font.lineHeight * 2;
    const footerReserve = font.lineHeight + 6;
    const measure = (panelWidth) => {
      const contentWidth = panelWidth - 24;
      const maxDetailLines = Math.max(...rows.map((row) =>
        wrap(row[language], contentWidth, font.records).length));
      const requiredHeight = gridTop + font.lineHeight + 4
        + (maxDetailLines + 1) * font.lineHeight + footerReserve;
      return {contentWidth, maxDetailLines, requiredHeight};
    };

    let panelWidth = basePanelWidth;
    let measured = measure(panelWidth);
    if (measured.requiredHeight > maximumPanelHeight) {
      for (panelWidth = basePanelWidth + 1;
        panelWidth <= maximumPanelWidth; panelWidth += 1) {
        measured = measure(panelWidth);
        if (measured.requiredHeight <= maximumPanelHeight) break;
      }
    }
    if (measured.requiredHeight > maximumPanelHeight
      || panelWidth > maximumPanelWidth) continue;

    const panelHeight = Math.max(basePanelHeight, measured.requiredHeight);
    const contentBottom = panelHeight - footerReserve;
    const detailHeight = (measured.maxDetailLines + 1) * font.lineHeight;
    const gridRows = Math.max(1, Math.min(9,
      Math.floor((contentBottom - gridTop - 4 - detailHeight) / font.lineHeight)));
    return {pixelSize, font, panelWidth, panelHeight, contentBottom,
      contentWidth: measured.contentWidth, maxDetailLines: measured.maxDetailLines,
      gridRows, gridTop, footerReserve};
  }
  throw new Error("11px must fit the supported minimum resolution");
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

test("every catalog condition fits after height-first panel growth and native-tier fallback", () => {
  const rows = catalogRows();
  const screens = [[320, 180], [408, 270], [480, 270], [640, 360],
    [854, 480], [1280, 360]];
  const fonts = new Map(F3_PIXEL_TIERS.map((pixelSize) =>
    [pixelSize, parseFont(pixelSize)]));

  for (const requestedPixels of F3_PIXEL_TIERS) {
    for (const language of ["zh", "en"]) {
      for (const [screenWidth, screenHeight] of screens) {
        const layout = fitF3Layout(requestedPixels, language,
          screenWidth, screenHeight, rows, fonts);
        assert.ok(layout.pixelSize <= requestedPixels);
        assert.ok(layout.panelWidth <= screenWidth - 24);
        assert.ok(layout.panelHeight <= screenHeight - 12);
        for (const row of rows) {
          const lines = wrap(row[language], layout.contentWidth, layout.font.records);
          for (const line of lines)
            assert.ok(textWidth(line, layout.font.records) <= layout.contentWidth);
        }
        assert.ok(layout.gridRows >= 1,
          `${screenWidth}x${screenHeight} ${language} requested ${requestedPixels}px must retain a grid row`);
        const detailHeight = (layout.maxDetailLines + 1) * layout.font.lineHeight;
        const detailBottom = layout.gridTop + layout.gridRows * layout.font.lineHeight
          + 4 + detailHeight;
        assert.ok(detailBottom <= layout.contentBottom,
          `${screenWidth}x${screenHeight} ${language} effective ${layout.pixelSize}px overlaps footer`);
      }
    }
  }

  for (const requestedPixels of [22, 33])
    assert.equal(fitF3Layout(requestedPixels, "en", 320, 180, rows, fonts).pixelSize, 11);
  assert.equal(fitF3Layout(22, "en", 640, 360, rows, fonts).pixelSize, 22);
  assert.equal(fitF3Layout(33, "en", 854, 480, rows, fonts).pixelSize, 33);
  const tallFirst = fitF3Layout(22, "en", 640, 360, rows, fonts);
  assert.ok(tallFirst.panelWidth >= 340, "width may grow only after height is exhausted");
  assert.ok(tallFirst.panelHeight > 250);
});

test("the longest bilingual conditions wrap without losing content", () => {
  const rows = catalogRows();
  const cases = [[324, "en"], [235, "zh"]];
  for (const pixelSize of F3_PIXEL_TIERS) {
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

const HUD_TIERS = [11, 22, 33];

function routeBlocks(font, maxWidth) {
  const wrapped = (value, indent = 0) => wrap(value, maxWidth - indent, font.records);
  const blocks = [];
  for (const id of [324, 325, 326]) {
    blocks.push([
      ...wrapped(`- #${id} A deliberately long tracked achievement [1/2]`),
      ...wrapped("NOW: complete the current floor and preserve the required route", 8),
      ...wrapped("NEXT: enter the alternate exit and continue toward the final boss", 8),
    ]);
  }
  return {
    header: wrapped("ACHIEVEMENT CONDITIONS"),
    footer: wrapped("F3: goals  |  Hold Tab for route details  |  F4: hide  [9/9]"),
    blocks,
  };
}

function paginatedRows(content, availableLines) {
  const fixed = content.header.length + content.footer.length;
  const capacity = Math.max(1, availableLines - fixed);
  const pages = [];
  let page = [];
  let split = false;
  const flush = () => {
    if (page.length > 0) pages.push(page);
    page = [];
  };
  for (const block of content.blocks) {
    if (block.length > capacity) {
      flush();
      split = true;
      for (let offset = 0; offset < block.length; offset += capacity)
        pages.push(block.slice(offset, offset + capacity));
    } else {
      if (page.length + block.length > capacity) flush();
      page.push(...block);
    }
  }
  flush();
  return {pages, split, fixed};
}

function hudHeight(lines, font, lineSpacingPixels) {
  if (lines <= 0) return 0;
  return lines * font.lineHeight + (lines - 1) * lineSpacingPixels;
}

function hudLineCapacity(availableHeight, font, lineSpacingPixels) {
  return Math.max(1, Math.floor((availableHeight + lineSpacingPixels)
    / (font.lineHeight + lineSpacingPixels)));
}

function fitNativeHud(requestedPixels, screenWidth, screenHeight, preferredX, preferredY,
  fonts, lineSpacingPixels = 0) {
  const margin = 8;
  const maximumX = Math.max(margin, screenWidth - margin - 120);
  const preferred = Math.max(margin, Math.min(maximumX, preferredX));
  const availableHeight = screenHeight - margin * 2;
  const requestedIndex = Math.max(0, HUD_TIERS.indexOf(requestedPixels));
  const staticAt = (pixelSize, x) => {
    const font = fonts.get(pixelSize);
    const content = routeBlocks(font, screenWidth - margin - x);
    const lines = content.header.length + content.footer.length
      + content.blocks.reduce((total, block) => total + block.length, 0);
    return {pixelSize, font, x, content, lines, lineSpacingPixels,
      totalHeight: hudHeight(lines, font, lineSpacingPixels)};
  };
  for (let tierIndex = requestedIndex; tierIndex >= 0; tierIndex -= 1) {
    const result = staticAt(HUD_TIERS[tierIndex], preferred);
    if (result.totalHeight <= availableHeight) {
      const y = Math.max(margin, Math.min(preferredY,
        screenHeight - margin - result.totalHeight));
      return {...result, y, pages: [result.content.blocks.flat()], split: false};
    }
  }
  for (let x = preferred - 1; x >= margin; x -= 1) {
    const result = staticAt(11, x);
    if (result.totalHeight <= availableHeight) {
      const y = Math.max(margin, Math.min(preferredY,
        screenHeight - margin - result.totalHeight));
      return {...result, y, pages: [result.content.blocks.flat()], split: false};
    }
  }

  const font = fonts.get(11);
  const availableLines = hudLineCapacity(availableHeight, font, lineSpacingPixels);
  const content = routeBlocks(font, screenWidth - margin * 2);
  const pagination = paginatedRows(content, availableLines);
  const fallback = {pixelSize: 11, font, x: margin, content, lineSpacingPixels,
    ...pagination};
  const pageLines = Math.max(...fallback.pages.map((page) =>
    page.length + fallback.content.header.length + fallback.content.footer.length));
  const totalHeight = hudHeight(pageLines, font, lineSpacingPixels);
  const y = Math.max(margin, Math.min(preferredY,
    screenHeight - margin - totalHeight));
  return {...fallback, y, lines: pageLines, totalHeight};
}

test("HUD native tiers preserve position, then left-shift only at the 11px floor", () => {
  const fonts = new Map(HUD_TIERS.map((pixels) => [pixels, parseFont(pixels)]));
  const shifted = fitNativeHud(33, 640, 360, 600, 400, fonts);
  assert.equal(shifted.pixelSize, 11);
  assert.ok(shifted.x < 512, "the 11px floor must move left only when the saved X cannot fit");
  assert.equal(shifted.pages.length, 1);
  assert.ok(shifted.y >= 8 && shifted.y + shifted.totalHeight <= 352);

  assert.equal(fitNativeHud(22, 854, 480, 18, 82, fonts).pixelSize, 22);
  assert.equal(fitNativeHud(33, 1920, 1080, 18, 82, fonts).pixelSize, 33);
});

test("320x180 HUD pagination preserves every complete target row inside safe bounds", () => {
  const fonts = new Map(HUD_TIERS.map((pixels) => [pixels, parseFont(pixels)]));
  const layout = fitNativeHud(33, 320, 180, 600, 400, fonts);
  assert.equal(layout.pixelSize, 11);
  assert.equal(layout.x, 8, "pagination begins only after using the full safe width");
  assert.ok(layout.pages.length > 1);
  assert.equal(layout.split, false, "left-shifting must avoid splitting a target when possible");
  assert.deepEqual(layout.pages.flat(), layout.content.blocks.flat());
  for (const page of layout.pages) {
    const lines = page.length + layout.content.header.length + layout.content.footer.length;
    const height = hudHeight(lines, layout.font, layout.lineSpacingPixels);
    assert.ok(height <= 164);
  }
  assert.ok(layout.y >= 8 && layout.y + layout.totalHeight <= 172);
});

test("HUD line spacing uses integer gaps in static and paged safe-area calculations", () => {
  const fonts = new Map(HUD_TIERS.map((pixels) => [pixels, parseFont(pixels)]));
  const compact = fitNativeHud(11, 1920, 1080, 18, 82, fonts, 0);
  const spaced = fitNativeHud(11, 1920, 1080, 18, 82, fonts, 8);
  assert.equal(spaced.lines, compact.lines);
  assert.equal(spaced.totalHeight - compact.totalHeight, (spaced.lines - 1) * 8);

  const screens = [[320, 180], [408, 270], [480, 270], [640, 360],
    [854, 480], [1920, 1080]];
  for (const spacing of [0, 4, 8]) {
    for (const requested of HUD_TIERS) {
      for (const [width, height] of screens) {
        const layout = fitNativeHud(requested, width, height, 600, 400, fonts, spacing);
        assert.ok(layout.y >= 8 && layout.y + layout.totalHeight <= height - 8,
          `${width}x${height} ${requested}px +${spacing}px must remain in the safe area`);
        assert.deepEqual(layout.pages.flat(), layout.content.blocks.flat());
      }
    }
  }
});

test("all bilingual warning conditions fit centered at a native tier", () => {
  const fonts = new Map(HUD_TIERS.map((pixels) => [pixels, parseFont(pixels)]));
  const screens = [[320, 180], [408, 270], [480, 270], [640, 360], [854, 480], [1920, 1080]];
  for (const row of catalogRows()) {
    for (const language of ["zh", "en"]) {
      const message = `${row[language]}: condition lost (reason)`;
      for (const spacing of [0, 8]) {
        for (const requested of HUD_TIERS) {
          for (const [width, height] of screens) {
            const effective = [...HUD_TIERS].reverse().find((pixels) => pixels <= requested
              && hudHeight(wrap(message, width - 16, fonts.get(pixels).records).length,
                fonts.get(pixels), spacing) <= height - 16);
            assert.ok(effective,
              `${row.id} ${language} ${spacing}px spacing must fit ${width}x${height}`);
          }
        }
      }
    }
  }
});
