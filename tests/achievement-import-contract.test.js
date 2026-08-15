const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("storage schema v4 validates and normalizes imported achievement snapshots", () => {
  const storage = read("scripts/core/storage.lua");

  assert.match(storage, /schemaVersion\s*=\s*4/);
  assert.match(storage, /MAX_ACHIEVEMENT_COUNT\s*=\s*16384/);
  assert.match(storage, /MAX_MOD_SAVE_DATA_BYTES\s*=\s*4\s*\*\s*1024\s*\*\s*1024/);
  assert.match(storage, /achievementImport\s*=\s*nil/);
  assert.match(storage, /local function normalizeAchievementImport\(snapshot\)/);
  assert.match(storage, /snapshot\.formatVersion\s*~=\s*1/);
  assert.match(storage, /isInteger\(snapshot\.saveSlot\)[\s\S]*?snapshot\.saveSlot\s*<\s*1[\s\S]*?snapshot\.saveSlot\s*>\s*3/);
  assert.match(storage, /isInteger\(snapshot\.achievementCount\)[\s\S]*?snapshot\.achievementCount\s*<=\s*0[\s\S]*?snapshot\.achievementCount\s*>\s*MAX_ACHIEVEMENT_COUNT/);
  assert.match(storage, /type\(snapshot\.unlockedIds\)\s*~=\s*"table"/);
  assert.match(storage, /id\s*<\s*1[\s\S]*?id\s*>=\s*snapshot\.achievementCount/);
  assert.doesNotMatch(storage, /id\s*<\s*0/);
  assert.match(storage, /table\.sort\(normalizedIds\)/);
  assert.match(storage, /#raw\s*>\s*MAX_MOD_SAVE_DATA_BYTES/);
  assert.match(storage, /achievementImport\s*=\s*normalizeAchievementImport\(decoded\.achievementImport\)/);
  assert.match(storage, /data\.achievementImport\s*=\s*normalizeAchievementImport\(data\.achievementImport\)/);
});

test("unlock scan treats an in-range imported achievement id as authoritative", () => {
  const unlocks = read("scripts/core/unlocks.lua");

  assert.match(unlocks, /function Unlocks\.scan\(goals, observedCompleted, achievementImport\)/);
  assert.match(unlocks, /local function importedAchievements\(snapshot\)/);
  assert.match(unlocks, /MAX_ACHIEVEMENT_COUNT\s*=\s*16384/);
  assert.match(unlocks, /importCache\[snapshot\]/);
  assert.match(unlocks, /snapshot\.formatVersion\s*~=\s*1/);
  assert.match(unlocks, /achievementId\s*>=\s*1[\s\S]*?achievementId\s*<\s*achievementCount/);
  assert.match(unlocks, /if importedUnlocked\[achievementId\][\s\S]*?completed\[goal\.id\]\s*=\s*true[\s\S]*?else[\s\S]*?completed\[goal\.id\]\s*=\s*nil/);
  assert.match(unlocks, /elseif Unlocks\.isCompleted\(goal\) then/);
});

test("runtime observations cannot overwrite an in-range imported result", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const main = read("main.lua");

  assert.match(unlocks, /function Unlocks\.observe\(goals, observedCompleted, profileCompleted,\s*kind, value, variant, achievementImport\)/);
  assert.match(unlocks, /local _, achievementCount\s*=\s*importedAchievements\(achievementImport\)/);
  assert.match(unlocks, /local importedAuthoritative\s*=\s*achievementCount[\s\S]*?achievementId\s*>=\s*1[\s\S]*?achievementId\s*<\s*achievementCount/);
  assert.match(unlocks, /if not importedAuthoritative and not observedCompleted\[goal\.id\][\s\S]*?matches\(goal\.observation/);
  assert.ok((main.match(/State\.settings\.achievementImport/g) || []).length >= 5,
    "scan and every observation entry point must receive the loaded snapshot");
});

test("game startup passes the loaded snapshot into the one-time profile scan", () => {
  const main = read("main.lua");

  assert.match(main, /Unlocks\.scan\(Catalog\.goals,\s*State\.settings\.observedCompleted,\s*State\.settings\.achievementImport\)/);
});
