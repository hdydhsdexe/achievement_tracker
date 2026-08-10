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
  assert.match(sensors, /local seed = tostring\(pickup\.InitSeed\)/);
  assert.doesNotMatch(sensors, /local seed = pickup\.InitSeed\s*\n/);
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

test("tracker HUD visualizes failed, completed, and counter progress states", () => {
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  const goals = read("scripts/data/goals.lua");
  const sensors = read("scripts/core/sensors.lua");
  assert.doesNotMatch(menu, /failedGoals/);
  assert.doesNotMatch(menu, /Text\.width/);
  assert.match(hud, /failedGoals/);
  assert.match(hud, /completedGoals/);
  assert.doesNotMatch(hud, /Isaac\.DrawLine/);
  assert.match(hud, /string\.rep\("#"/);
  assert.match(hud, /Sensors\.progress/);
  assert.match(goals, /marbles = \{ key="gulp", target=5 \}/);
  assert.match(goals, /u_broke_it = \{ key="items", target=50 \}/);
  assert.match(sensors, /PILLEFFECT_GULP/);
  assert.match(sensors, /completedGoals\.marbles/);
});

test("HUD renders localized completion conditions with a scalable Unicode font", () => {
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.match(text, /DrawStringScaledUTF8/);
  assert.match(hud, /text\.detail/);
  assert.doesNotMatch(hud, /"- "\s*\.\.\s*text\.name/);
  assert.match(hud, /fontScale/);
});

test("renderer always uses the bundled LanaPixel font without fallbacks", () => {
  const text = read("scripts/ui/text.lua");
  assert.match(text, /bundledFont:Load\(modPath \..*achievement_lanapixel\.fnt/);
  assert.match(text, /bundledFont:DrawStringScaledUTF8/);
  assert.doesNotMatch(text, /terminus8|achievement_zh|fallback|IsLoaded/);
  assert.match(text, /function Text\.resolveLanguage/);
});

test("Chinese rendering is self-contained and does not reference EID", () => {
  const text = read("scripts/ui/text.lua");
  const fontPath = path.join(root, "resources/font/achievement_lanapixel.fnt");
  const licensePath = path.join(root, "resources/font/LANAPIXEL_OFL.txt");
  assert.doesNotMatch(text, /external item descriptions/i);
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.match(text, /GetCurrentModPath/);
  assert.equal(fs.existsSync(fontPath), true, "bundled Chinese .fnt must exist");
  assert.equal(fs.existsSync(licensePath), true, "font license must ship with the mod");
  const pages = fs.readdirSync(path.join(root, "resources/font")).filter((file) => /^achievement_lanapixel_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "font must include at least one texture page");
});

test("bundled LanaPixel assets are complete", () => {
  const text = read("scripts/ui/text.lua");
  const fontDir = path.join(root, "resources/font");
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.doesNotMatch(text, /resources\/font\/achievement_zh\.fnt/);
  assert.equal(fs.existsSync(path.join(fontDir, "achievement_lanapixel.fnt")), true);
  assert.equal(fs.existsSync(path.join(fontDir, "LANAPIXEL_OFL.txt")), true);
  const pages = fs.readdirSync(fontDir).filter((file) => /^achievement_lanapixel_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "LanaPixel font must include a texture page");
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

test("failed run state survives quitting and is restored only for the same run", () => {
  const main = read("main.lua");
  const sensors = read("scripts/core/sensors.lua");
  assert.match(main, /GetStartSeed\(\)/);
  assert.match(main, /sameSavedRun/);
  assert.match(main, /function AchievementTracker:onExit\(shouldSave\)[\s\S]*?save\(\)/);
  assert.match(main, /State\.lastEvaluation = -1/);
  assert.match(sensors, /function Sensors\.newRun\(startSeed\)/);
});

test("vanilla unlock inference uses reward availability and sorts completed goals last", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const menu = read("scripts/ui/menu.lua");
  assert.match(unlocks, /IsAvailable/);
  assert.match(unlocks, /pcall\(rewardAvailable/);
  assert.match(unlocks, /COLLECTIBLE_MARBLES/);
  assert.match(unlocks, /CARD_HUGE_GROWTH/);
  assert.match(unlocks, /TRINKET_BUTTER/);
  assert.match(menu, /local pending, completed/);
  assert.match(menu, /state\.profileCompleted/);
});
