const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("tracker removes completed ordinary goals and route members as one operation", () => {
  const tracker = read("scripts/core/tracker.lua");
  assert.match(tracker, /function Tracker\.removeIds\(state, idSet\)/);
  assert.match(tracker, /for _, id in ipairs\(state\.ids\)/);
  assert.match(tracker, /for _, id in ipairs\(state\.route and state\.route\.memberIds or \{\}\)/);
  assert.match(tracker, /state\.route\.memberIds = routeMembers/);
  assert.match(tracker, /if #routeMembers == 0 then state\.route = nil end/);
  assert.match(tracker, /return removed/);
});

test("completion transitions announce every newly completed catalog goal once", () => {
  const main = read("main.lua");
  assert.match(main, /completionBaseline\s*=\s*\{\}/);
  assert.match(main, /completionNotices\s*=\s*\{\}/);
  assert.match(main, /local function initializeCompletionBaseline\(\)/);
  assert.match(main, /local function syncCompletionTransitions\(\)/);
  assert.match(main, /for _, goal in ipairs\(Catalog\.goals\)/);
  assert.match(main, /completed and not State\.completionBaseline\[goal\.id\]/);
  assert.match(main, /table\.insert\(State\.completionNotices, goal\.id\)/);
  assert.match(main, /Tracker\.removeIds\(State\.tracker, newlyCompleted\)/);
  assert.match(main, /State\.completionBaseline\[goal\.id\] = completed or nil/);
});

test("completion notices are room-scoped and rendered before tracked route content", () => {
  const main = read("main.lua");
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(main,
    /function AchievementTracker:onNewRoom\(\)[\s\S]*?State\.completionNotices = \{\}/);
  assert.match(hud, /local function completionNoticeBlocks\(state, language, maxWidth, fontPixels\)/);
  assert.match(hud, /for _, id in ipairs\(state\.completionNotices or \{\}\)/);
  assert.match(hud,
    /string\.format\(labels\.goalCompleted, Catalog\.text\(goal,[\s\S]*?language\)\.name\)/);
  assert.match(hud, /HUD_COMPLETED/);
  assert.match(hud, /completionNoticeBlocks[\s\S]*?routeBlock/,
    "completion notices must be added before route and ordinary tracker blocks");
  assert.match(text, /goalCompleted\s*=\s*"%s已完成"/);
  assert.match(text, /goalCompleted\s*=\s*"%s completed"/);
});

test("F3 completed achievements are read-only and remain in the completed bucket", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu,
    /local function toggleGoal\(state, goal, save, context\)[\s\S]*?if isCompleted\(state, goal\) then return false end/);
  assert.match(menu, /local bucket, priorityRank = completed, 7/);
  assert.match(menu,
    /\{ routeEntries, tracked, scenePending, currentCharacterPending, convertiblePending,[\s\S]*?unavailable, completed \}/);
});

test("non-continued games clear routes and prune every currently impossible target", () => {
  const main = read("main.lua");
  assert.match(main, /local function goalAvailableAtRunStart\(goal, relevanceContext, routeContext\)/);
  assert.match(main, /Catalog\.isCompletable\(goal, Isaac\.GetChallenge\(\)\)/);
  assert.match(main, /CharacterRelevance\.classify\(goal, relevanceContext\)/);
  assert.match(main, /relevance ~= "current" and relevance ~= "general" and relevance ~= "convertible"/);
  assert.match(main, /CompletionMarks\.progress\(goal,[\s\S]*?requirement\.difficulty > difficulty/);
  assert.match(main, /Routes\.evaluate\(goal,[\s\S]*?routeResult\.severity == "failed"/);
  assert.match(main, /local function prepareNewRunTracking[\s\S]*?Tracker\.untrackRoute\(State\.tracker\)/);
  assert.match(main, /if not completionAllowed\(\) and Isaac\.GetChallenge\(\) == 0 then/);
  assert.match(main,
    /if not isContinued then[\s\S]*?prepareNewRunTracking[\s\S]*?RouteRecommendations\.choose/);
});

test("startup silently removes historical completions without replaying notices", () => {
  const main = read("main.lua");
  const initialize = main.match(
    /local function initializeCompletionBaseline\(\)[\s\S]*?\nend\n\nlocal function syncCompletionTransitions/)?.[0] ?? "";
  assert.match(initialize, /Tracker\.removeIds\(State\.tracker, completedIds\)/);
  assert.doesNotMatch(initialize, /completionNotices/,
    "baseline initialization must not enqueue historical completion notices");
});
