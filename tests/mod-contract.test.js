const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("mod has valid entry metadata and registers gameplay callbacks", () => {
  const metadata = read("metadata.xml");
  const main = read("main.lua");
  assert.match(metadata, /<name>Achievement Tracker<\/name>/);
  assert.match(main, /RegisterMod\("Achievement Tracker", 1\)/);
  for (const callback of ["MC_POST_GAME_STARTED", "MC_POST_UPDATE", "MC_POST_RENDER", "MC_POST_PICKUP_UPDATE", "MC_PRE_GAME_EXIT"]) {
    assert.match(main, new RegExp(callback));
  }
});

test("catalog ships at least fifteen selectable goals with localized text", () => {
  const catalog = read("scripts/data/goals.lua");
  const ids = [...catalog.matchAll(/\bid\s*=\s*"([a-z0-9_]+)"/g)].map((match) => match[1]);
  assert.ok(ids.length >= 15, `expected >= 15 goals, received ${ids.length}`);
  assert.equal(new Set(ids).size, ids.length, "goal ids must be unique");
  assert.match(catalog, /zh\s*=\s*{/);
  assert.match(catalog, /en\s*=\s*{/);
});

test("tracking core enforces uniqueness and a configurable maximum", () => {
  const tracker = read("scripts/core/tracker.lua");
  assert.match(tracker, /function Tracker\.track/);
  assert.match(tracker, /#state\.ids\s*>=\s*state\.max/);
  assert.match(tracker, /Tracker\.contains/);
});

test("warning core supports deadline, lost eligibility, and warning deduplication", () => {
  const evaluator = read("scripts/core/evaluator.lua");
  assert.match(evaluator, /snapshot\.eligible\s*==\s*false/);
  assert.match(evaluator, /goal\.deadline/);
  assert.match(evaluator, /state\.emitted/);
  assert.match(evaluator, /function Evaluator\.reset/);
});

test("restricted pickup detection waits for the pickup collect animation", () => {
  const sensors = read("scripts/core/sensors.lua");
  assert.match(sensors, /sprite:IsPlaying\("Collect"\)/);
  assert.match(sensors, /PICKUP_HEART/);
  assert.match(sensors, /PICKUP_COIN/);
  assert.match(sensors, /PICKUP_BOMB/);
});

test("menu and HUD are usable without optional Mod Config Menu", () => {
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  const mcm = read("scripts/integrations/mcm.lua");
  assert.match(menu, /Input\.IsButtonTriggered/);
  assert.match(menu, /Tracker\.toggle/);
  assert.match(hud, /Text\.draw/);
  assert.match(mcm, /ModConfigMenu\s*==\s*nil/);
});

test("HUD renders localized completion conditions with a scalable Unicode font", () => {
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(text, /font\/lanapixel\.fnt/);
  assert.match(text, /DrawStringScaledUTF8/);
  assert.match(hud, /text\.detail/);
  assert.doesNotMatch(hud, /"- "\s*\.\.\s*text\.name/);
  assert.match(hud, /fontScale/);
});

test("Mod Config Menu exposes language, font scale, and X/Y position settings", () => {
  const mcm = read("scripts/integrations/mcm.lua");
  assert.match(mcm, /Language/);
  assert.match(mcm, /Font size/);
  assert.match(mcm, /HUD X/);
  assert.match(mcm, /HUD Y/);
  assert.match(mcm, /Minimum/);
  assert.match(mcm, /Maximum/);
  assert.match(mcm, /ModifyBy/);
});

test("persistent settings are loaded defensively and saved as JSON", () => {
  const storage = read("scripts/core/storage.lua");
  assert.match(storage, /mod:HasData\(\)/);
  assert.match(storage, /json\.decode/);
  assert.match(storage, /json\.encode/);
  assert.match(storage, /schemaVersion/);
  assert.match(storage, /activeRun/);
  assert.match(storage, /fontScale/);
});
