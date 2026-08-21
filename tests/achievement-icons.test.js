const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const generatorPath = path.join(root, "tools", "generate_achievement_icons.mjs");
const iconDir = path.join(root, "resources", "gfx", "ui", "achievement_icons");
const manifestPath = path.join(iconDir, "manifest.json");

let generatorModule;
async function loadGenerator() {
  generatorModule ||= import(pathToFileUrl(generatorPath));
  return generatorModule;
}

function pathToFileUrl(file) {
  return `file:///${file.replace(/\\/g, "/").replace(/^([A-Za-z]):/, "$1:")}`;
}

function png(width, height) {
  const data = Buffer.alloc(24);
  Buffer.from("89504e470d0a1a0a", "hex").copy(data, 0);
  data.writeUInt32BE(13, 8);
  data.write("IHDR", 12, "ascii");
  data.writeUInt32BE(width, 16);
  data.writeUInt32BE(height, 20);
  return data;
}

test("achievement icon generator joins aliases and selects the newest DLC image deterministically", async () => {
  const { buildIconRecords } = await loadGenerator();
  const achievements = [
    { id: "2", alias: "Second" },
    { id: "1", alias: "First" }
  ];
  const images = [
    { achievement: "First", file: "Achievement First old icon.png", dlc: "Afterbirth" },
    { achievement: "First", file: "Achievement First icon.png", dlc: "Repentance" },
    { achievement: "Second", file: "Achievement Second icon.png", dlc: "Rebirth" }
  ];

  assert.deepEqual(buildIconRecords(achievements, images, { expectedCount: 2 }), [
    { id: 1, alias: "First", sourceFile: "Achievement First icon.png", dlc: "Repentance" },
    { id: 2, alias: "Second", sourceFile: "Achievement Second icon.png", dlc: "Rebirth" }
  ]);
});

test("achievement icon generator rejects gaps, duplicate ids, aliases without images, and invalid PNG dimensions", async () => {
  const { buildIconRecords, inspectPng } = await loadGenerator();
  assert.throws(() => buildIconRecords([
    { id: "1", alias: "First" }, { id: "3", alias: "Third" }
  ], [
    { achievement: "First", file: "First.png", dlc: "Rebirth" },
    { achievement: "Third", file: "Third.png", dlc: "Rebirth" }
  ], { expectedCount: 3 }), /missing achievement id 2/i);
  assert.throws(() => buildIconRecords([
    { id: "1", alias: "First" }, { id: "1", alias: "Again" }
  ], [
    { achievement: "First", file: "First.png", dlc: "Rebirth" },
    { achievement: "Again", file: "Again.png", dlc: "Rebirth" }
  ], { expectedCount: 1 }), /duplicate achievement id 1/i);
  assert.throws(() => buildIconRecords([{ id: "1", alias: "First" }], [],
    { expectedCount: 1 }), /no icon image/i);
  assert.throws(() => inspectPng(Buffer.from("not png")), /PNG signature/i);
  assert.throws(() => inspectPng(png(263, 176)), /64x64/i);
  assert.deepEqual(inspectPng(png(64, 64)), { width: 64, height: 64 });
});

test("Cargo pagination follows offsets and preserves every returned row", async () => {
  const { fetchCargoRows } = await loadGenerator();
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(new URL(url).searchParams.get("offset"));
    const offset = Number(new URL(url).searchParams.get("offset"));
    const rows = offset === 0 ? [{ id: "1" }, { id: "2" }] : [{ id: "3" }];
    return { ok: true, json: async () => ({ cargoquery: rows.map((title) => ({ title })) }) };
  };

  const rows = await fetchCargoRows(fetchImpl, "achievement", ["id"], { pageSize: 2 });
  assert.deepEqual(rows, [{ id: "1" }, { id: "2" }, { id: "3" }]);
  assert.deepEqual(calls, ["0", "2"]);
});

test("MediaWiki title normalization does not detach lowercase Cargo filenames", async () => {
  const { resolveImageInfo } = await loadGenerator();
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({
      query: {
        pages: [{
          title: "File:Achievement Backasswards icon.png",
          imageinfo: [{
            width: 64,
            height: 64,
            url: "https://bindingofisaacrebirth.wiki.gg/images/a/aa/example.png",
            descriptionurl: "https://bindingofisaacrebirth.wiki.gg/wiki/File:Example.png"
          }]
        }]
      }
    })
  });

  const [resolved] = await resolveImageInfo(fetchImpl, [{
    id: 336,
    alias: "Backasswards",
    sourceFile: "achievement Backasswards icon.png",
    dlc: "Afterbirth+"
  }]);
  assert.equal(resolved.id, 336);
  assert.match(resolved.downloadUrl, /example\.png$/);
});

test("generator rejects failed Cargo requests and non-square image metadata", async () => {
  const { fetchCargoRows, resolveImageInfo } = await loadGenerator();
  await assert.rejects(fetchCargoRows(async () => ({ ok: false, status: 500 }),
    "achievement", ["id"], { attempts: 1, delay: async () => {} }),
  /Request failed after 1 attempts/);

  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({
      query: {
        pages: [{
          title: "File:Achievement Paper icon.png",
          imageinfo: [{
            width: 263,
            height: 176,
            url: "https://bindingofisaacrebirth.wiki.gg/images/paper.png"
          }]
        }]
      }
    })
  });
  await assert.rejects(resolveImageInfo(fetchImpl, [{
    id: 1, alias: "Paper", sourceFile: "Achievement Paper icon.png", dlc: "Rebirth"
  }]), /must be 64x64/);
});

test("download retries transient failures and validates the downloaded icon", async () => {
  const { fetchIconBuffer } = await loadGenerator();
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    if (calls < 3) return { ok: false, status: 503 };
    return { ok: true, arrayBuffer: async () => png(64, 64) };
  };

  const result = await fetchIconBuffer(fetchImpl, "https://example.invalid/icon.png", {
    attempts: 3, delay: async () => {}
  });
  assert.equal(calls, 3);
  assert.equal(result.length, 24);
});

test("generator completes an offline 641-icon integration run with paged mocked APIs", async () => {
  const { generateAchievementIcons } = await loadGenerator();
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "achievement-icons-test-"));
  const achievements = Array.from({ length: 641 }, (_, index) => ({
    id: String(index + 1), alias: `Icon ${String(index + 1).padStart(3, "0")}`
  }));
  const images = achievements.map((entry) => ({
    achievement: entry.alias,
    file: `Achievement ${entry.alias} icon.png`,
    dlc: "Repentance"
  }));
  const imageData = png(64, 64);

  const fetchImpl = async (url) => {
    const parsed = new URL(url);
    if (parsed.hostname === "bindingofisaacrebirth.wiki.gg"
      && parsed.pathname === "/api.php") {
      const action = parsed.searchParams.get("action");
      if (action === "cargoquery") {
        const source = parsed.searchParams.get("tables") === "achievement"
          ? achievements : images;
        const offset = Number(parsed.searchParams.get("offset"));
        const limit = Number(parsed.searchParams.get("limit"));
        return {
          ok: true,
          json: async () => ({ cargoquery: source.slice(offset, offset + limit)
            .map((title) => ({ title })) })
        };
      }
      const titles = parsed.searchParams.get("titles").split("|");
      return {
        ok: true,
        json: async () => ({
          query: {
            pages: titles.map((title, index) => ({
              title,
              imageinfo: [{
                width: 64,
                height: 64,
                url: `https://bindingofisaacrebirth.wiki.gg/images/mock/${encodeURIComponent(title)}.png`,
                ...(index === 0 ? {} : {
                  descriptionurl: `https://bindingofisaacrebirth.wiki.gg/wiki/${encodeURIComponent(title)}`
                })
              }]
            }))
          }
        })
      };
    }
    if (parsed.pathname.startsWith("/images/mock/")) {
      return { ok: true, arrayBuffer: async () => imageData };
    }
    throw new Error(`Unexpected mocked request: ${url}`);
  };

  try {
    const manifest = await generateAchievementIcons({ fetchImpl, outputDir, concurrency: 5 });
    assert.equal(manifest.icons.length, 641);
    assert.equal(fs.readdirSync(outputDir).length, 642);
    assert.equal(fs.existsSync(path.join(outputDir, "achievement_001.png")), true);
    assert.equal(fs.existsSync(path.join(outputDir, "achievement_641.png")), true);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(outputDir, "manifest.json"), "utf8")),
      manifest);
  } finally {
    fs.rmSync(outputDir, { recursive: true, force: true });
  }
});

test("bundled achievement icon manifest covers exactly ids 1 through 641", () => {
  assert.equal(fs.existsSync(manifestPath), true, "achievement icon manifest must be bundled");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  assert.equal(manifest.source, "https://bindingofisaacrebirth.wiki.gg/");
  assert.equal(manifest.icons.length, 641);
  assert.deepEqual(manifest.icons.map((entry) => entry.id),
    Array.from({ length: 641 }, (_, index) => index + 1));

  for (const entry of manifest.icons) {
    const expectedFile = `achievement_${String(entry.id).padStart(3, "0")}.png`;
    assert.equal(entry.file, expectedFile);
    assert.match(entry.sourceFile, /^Achievement .+ icon\.png$/i);
    assert.match(entry.descriptionUrl, /^https:\/\/bindingofisaacrebirth\.wiki\.gg\/wiki\/File:/);
    assert.match(entry.downloadUrl, /^https:\/\/bindingofisaacrebirth\.wiki\.gg\/images\//);
    assert.match(entry.sha256, /^[a-f0-9]{64}$/);
  }
});

test("every bundled achievement icon is a verified 64x64 PNG matching its manifest hash", async () => {
  const { inspectPng } = await loadGenerator();
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  for (const entry of manifest.icons) {
    const data = fs.readFileSync(path.join(iconDir, entry.file));
    assert.deepEqual(inspectPng(data), { width: 64, height: 64 }, entry.file);
    assert.equal(crypto.createHash("sha256").update(data).digest("hex"), entry.sha256,
      `${entry.file} checksum`);
  }
});

test("F3 prefers achievement ids for both icon sizes while preserving semantic fallbacks", () => {
  const rewards = fs.readFileSync(path.join(root, "scripts/core/rewards.lua"), "utf8");
  const icons = fs.readFileSync(path.join(root, "scripts/ui/reward_icons.lua"), "utf8");
  const menu = fs.readFileSync(path.join(root, "scripts/ui/menu.lua"), "utf8");
  const actor = fs.readFileSync(path.join(root,
    "resources/gfx/ui/achievement_icons.anm2"), "utf8");

  assert.match(rewards, /achievementId=goal\.achievementId/);
  assert.match(icons, /tostring\(reward\.achievementId or ""\)/,
    "cache keys must distinguish achievement ids");
  assert.match(icons, /local function achievementIconEntry/);
  assert.match(icons, /achievement_%03d\.png/);
  assert.match(icons, /gfx\/ui\/achievement_icons\.anm2/);
  assert.match(icons, /ReplaceSpritesheet\(0,/);
  assert.match(icons, /baseSize=64/);
  assert.match(icons, /local entry = achievementIconEntry\(reward\)/,
    "achievement art must be attempted before semantic icons");
  assert.match(icons, /if not entry and \(reward\.kind == "collectible"/,
    "semantic renderers must remain the fallback path");
  assert.match(icons, /if not entry then entry = fallbackSprite\(reward\) end/);
  assert.match(menu, /RewardIcons\.render\(reward,[^\n]+12/);
  assert.match(menu, /RewardIcons\.render\(reward,[^\n]+30/);
  assert.match(actor, /Animation Name="AchievementIcon"/);
  assert.match(actor, /Width="64" Height="64"/);
  assert.doesNotMatch(icons, /https?:\/\//, "Lua runtime must remain offline");
  assert.doesNotMatch(icons, /REPENTOGON|XMLData/,
    "achievement icons must not require REPENTOGON");
});

test("achievement icon provenance and third-party rights ship with the mod", () => {
  const notice = fs.readFileSync(path.join(root, "THIRD_PARTY_NOTICES.md"), "utf8");
  assert.match(notice, /bindingofisaacrebirth\.wiki\.gg/);
  assert.match(notice, /CC BY-SA 4\.0/);
  assert.match(notice, /The Binding of Isaac/i);
  assert.match(notice, /rights holders/i);
});
