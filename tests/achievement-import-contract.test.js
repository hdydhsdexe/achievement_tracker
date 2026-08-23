const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("storage schema v8 migrates legacy HUD scaling and preserves native tiers", () => {
  const storage = read("scripts/core/storage.lua");

  assert.match(storage, /schemaVersion\s*=\s*8/);
  assert.doesNotMatch(storage, /schemaVersion\s*=\s*7/);
  assert.match(storage, /hud\s*=\s*\{[^}]*fontPixels\s*=\s*11/);
  assert.match(storage, /f3\s*=\s*\{\s*fontPixels\s*=\s*11\s*\}/);
  assert.match(storage, /local NATIVE_FONT_PIXELS\s*=\s*\{\s*\[11\]=true,\s*\[22\]=true,\s*\[33\]=true\s*\}/);
  assert.match(storage, /local function migrateHudFontPixels/);
  assert.match(storage, /decoded\.schemaVersion\s*==\s*8[\s\S]*?return decoded\.hud\.fontPixels/);
  assert.match(storage, /math\.floor\([^\n]*oldScale[^\n]*\*\s*16[^\n]*\+\s*0\.5\)/);
  assert.match(storage, /oldPixels\s*>=\s*22[^\n]*and\s*22\s*or\s*11/);
  assert.match(storage, /data\.hud\.fontPixels\s*=\s*migrateHudFontPixels\(decoded\)/);
  assert.doesNotMatch(storage, /data\.hud\.fontScale\s*=/);
  assert.match(storage, /local function migrateF3FontPixels/);
  assert.match(storage, /decoded\.schemaVersion\s*>=\s*7[\s\S]*?return decoded\.f3\.fontPixels/,
    "schema 7 F3 native tiers must survive the schema 8 upgrade");
  assert.match(storage, /data\.f3\.fontPixels\s*=\s*migrateF3FontPixels\(decoded\)/);
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
  assert.match(storage, /local function normalizeCompletionMarks\(snapshot\)/);
  assert.match(storage, /completionMarks\s*=\s*normalizeCompletionMarks\(decoded\.completionMarks\)/);
  assert.match(storage, /data\.completionMarks\s*=\s*normalizeCompletionMarks\(data\.completionMarks\)/);
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

test("startup positive evidence requires a unique standard reward key", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const early = read("scripts/data/achievements_1_50.lua");
  const later = read("scripts/data/achievements_101_200.lua");
  const rewardIndex = unlocks.match(/local rewardAchievementIds\s*=\s*\{\}([\s\S]*?)local rewardAchievementCounts/)?.[1] ?? "";

  assert.match(early, /a\(8,[^\n]*,20\)/, "achievement 8 uses collectible 20");
  assert.match(later, /a\(159,[^\n]*reward\("collectible",20\)\)/,
    "achievement 159 shares collectible 20");
  assert.match(unlocks, /local function standardRewardKey\(goal\)/);
  assert.match(unlocks, /reward\.kind\s*~?=\s*"collectible"[\s\S]*?"trinket"[\s\S]*?"card"/);
  assert.match(unlocks, /local rewardId\s*=\s*Rewards\.resolveId\(reward\)/);
  assert.match(unlocks, /rewardAchievementIds\[rewardKey\]\[achievementId\]\s*=\s*true/);
  assert.doesNotMatch(rewardIndex, /achievementCount/,
    "reward uniqueness is catalog-wide, independent of snapshot range");
  assert.match(unlocks, /rewardAchievementCounts\[rewardKey\]\s*==\s*1/);
  assert.match(unlocks, /function Unlocks\.refreshAchievementImport\(goals, achievementImport\)/);
  assert.match(unlocks, /local importedUnlocked, achievementCount\s*=\s*importedAchievements\(achievementImport\)/);
  assert.match(unlocks, /if not importedUnlocked then return false end/);
  assert.match(unlocks, /not importedUnlocked\[achievementId\][\s\S]*?Unlocks\.isCompleted\(goal\)/);
  assert.match(unlocks, /importedUnlocked\[achievementId\]\s*=\s*true/);
  assert.match(unlocks, /table\.sort\(unlockedIds\)/);
  assert.match(unlocks, /achievementImport\.unlockedIds\s*=\s*unlockedIds/);
  assert.match(unlocks, /importCache\[achievementImport\]\s*=\s*nil/);
  assert.doesNotMatch(unlocks, /importedUnlocked\[[^\]]+\]\s*=\s*(?:false|nil)/);
});

test("game startup refreshes imported achievements before scanning and persists at the existing save point", () => {
  const main = read("main.lua");
  const started = main.match(/function AchievementTracker:onGameStarted\(isContinued\)([\s\S]*?)\nend/)?.[1] ?? "";

  const loadIndex = started.indexOf("load()");
  const refreshIndex = started.indexOf("Unlocks.refreshAchievementImport");
  const scanIndex = started.indexOf("State.profileCompleted = Unlocks.scan");
  const saveIndex = started.lastIndexOf("save()");
  assert.ok(loadIndex >= 0 && loadIndex < refreshIndex, "refresh must run after load");
  assert.ok(refreshIndex < scanIndex, "refresh must run before the profile scan");
  assert.ok(scanIndex < saveIndex, "the existing end-of-start save persists additions");
});

test("REPENTOGON exact achievement callback bypasses reward availability and remains monotonic", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const main = read("main.lua");
  const recorder = unlocks.match(/function Unlocks\.recordImportedAchievement\(goals, achievementImport, achievementId\)([\s\S]*?)\nend/)?.[1] ?? "";

  assert.match(unlocks, /function Unlocks\.recordImportedAchievement\(goals, achievementImport, achievementId\)/);
  assert.match(recorder, /isInteger\(achievementId\)[\s\S]*?achievementId\s*<\s*1[\s\S]*?achievementId\s*>=\s*achievementCount/);
  assert.match(recorder, /for _, goal in ipairs\(goals or \{\}\)[\s\S]*?goal\.achievementId\s*==\s*achievementId/);
  assert.match(recorder, /if not catalogContainsAchievement then return false end/);
  assert.match(recorder, /if importedUnlocked\[achievementId\] then return false end/);
  assert.match(recorder, /importedUnlocked\[achievementId\]\s*=\s*true/);
  assert.doesNotMatch(recorder, /isCompleted|standardRewardKey|IsAvailable/);
  assert.match(main, /function AchievementTracker:onAchievementUnlocked\(achievementId\)/);
  assert.match(main, /Unlocks\.recordImportedAchievement\(Catalog\.goals,\s*State\.settings\.achievementImport,\s*achievementId\)/);
  assert.match(main, /onAchievementUnlocked[\s\S]*?State\.profileCompleted\s*=\s*Unlocks\.scan[\s\S]*?save\(\)/);
  assert.match(main, /if ModCallbacks\.MC_POST_ACHIEVEMENT_UNLOCK then[\s\S]*?AddCallback\(ModCallbacks\.MC_POST_ACHIEVEMENT_UNLOCK,\s*AchievementTracker\.onAchievementUnlocked\)/);
});
