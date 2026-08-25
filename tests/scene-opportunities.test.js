const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("scene opportunity core covers the approved first batch behind shared gates", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  assert.match(opportunities, /function Opportunities\.evaluate/);
  assert.match(opportunities, /function Opportunities\.signature/);
  assert.match(opportunities, /if not completionAllowed then return \{\} end/);
  assert.match(opportunities, /profileCompleted\[goalId\]/);

  for (const id of [27, 82, 258, 366, 389, 390, 408, 410, 523, 545, 546]) {
    assert.match(opportunities, new RegExp(`achievement_${id}`));
  }
  assert.match(opportunities, /for achievementId = 474, 490 do/);
  assert.match(opportunities, /ENTITY_BABY_PLUM[\s\S]*?908/);
  assert.match(opportunities, /ENTITY_SIREN[\s\S]*?904/);
  assert.match(opportunities, /SIREN_SKULL_VARIANT\s*=\s*1/);
  assert.match(opportunities, /ENTITY_HORNFEL[\s\S]*?906/);
  assert.match(opportunities, /ENTITY_MINECART[\s\S]*?965/);
  assert.match(opportunities, /BATTERY_BUM[\s\S]*?13/);
  assert.match(opportunities, /ROOM_SACRIFICE[\s\S]*?13/);
  assert.match(opportunities, /ROOM_BOSSRUSH[\s\S]*?17/);
});

test("every Chinese HUD opportunity starts with the requested prefix", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const messages = [...opportunities.matchAll(/message\("([^"]+)",\s*"([^"]+)"\)/g)];
  assert.ok(messages.length >= 14, "the first batch should expose its action copy centrally");
  for (const [, zh, en] of messages) {
    assert.match(zh, /^尝试/, `Chinese opportunity must start with 尝试: ${zh}`);
    assert.match(en, /^Try\b/, `English opportunity must start with Try: ${en}`);
  }
});

test("scene opportunities are derived without mutating the tracker", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  assert.doesNotMatch(opportunities, /Tracker\.(?:track|toggle)/);
  assert.doesNotMatch(opportunities, /settings\.tracked\s*=/);
  assert.match(opportunities, /result = uniqueByGoal\(result\)/);
  assert.match(opportunities, /opportunity\.stableOrder = index/);
  assert.match(opportunities, /table\.sort\(result/);
  assert.match(opportunities, /left\.priority ~= right\.priority/);
  assert.match(opportunities, /left\.priority < right\.priority/);
  assert.match(opportunities, /left\.stableOrder < right\.stableOrder/);
});

test("runtime derives opportunities once per evaluation tick and observes room events", () => {
  const main = read("main.lua");
  assert.match(main, /local Opportunities = require\("scripts\.core\.opportunities"\)/);
  assert.match(main, /sceneOpportunities\s*=\s*\{\}/);
  assert.match(main, /Opportunities\.evaluate\(/);
  assert.match(main, /Opportunities\.updateRun\(/);
  assert.match(main, /Opportunities\.observeNpc\(/);
  assert.match(main, /Opportunities\.onNewRoom\(/);
  assert.match(main, /Opportunities\.resetAttempt\(/);
  assert.match(main, /seeds:IsCustomRun\(\)/);
  assert.match(main, /GameInstance:GetVictoryLap\(\)/);
  assert.match(main, /onAchievementUnlocked[\s\S]*?State\.lastEvaluation = -1/);
  assert.match(main, /State\.sceneOpportunities = \{\}/);
});

test("HUD appends one opportunity after tracked blocks", () => {
  const hud = read("scripts/ui/hud.lua");
  assert.match(hud, /local function opportunityBlock/);
  assert.match(hud, /state\.sceneOpportunities\s+and\s+state\.sceneOpportunities\[1\]/);
  assert.match(hud, /table\.insert\(blocks, opportunity\)/);
  assert.match(hud, /HUD_OPPORTUNITY/);
  assert.match(hud, /HUD_FAILED/);
});

test("F3 ranks tracked, scene opportunities, and existing buckets in that order", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local tracked, scenePending, currentPending/);
  assert.match(menu, /sceneGoalIds/);
  assert.match(menu, /bucket, priorityRank = scenePending, 2/);
  assert.match(menu, /bucket, priorityRank = currentPending, 3/);
  assert.match(menu, /\{ tracked, scenePending, currentPending, convertiblePending,/);
  assert.match(menu, /opportunitySignature/);
  assert.match(menu, /sceneOpportunitySignature\(state\)/);
});

test("battery bum arbitration never suggests feeding and killing at once", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const block = opportunities.match(/local function addBatteryBum[\s\S]*?\nend/);
  assert.ok(block);
  assert.match(block[0], /achievement_523/);
  assert.match(block[0], /elseif not completed\(profileCompleted, "achievement_545"\)/);
});

test("tainted and Forgotten opportunities reuse route and run context conservatively", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  assert.match(opportunities, /routeKind == "tainted_unlock"/);
  assert.match(opportunities, /CharacterRelevance\.requiredPlayerTypes/);
  assert.match(opportunities, /Isaac\.GetPlayer\(0\)/);
  assert.match(opportunities, /required\[primaryPlayerType\] == true/);
  assert.match(opportunities, /context\.ascent or context\.stage == STAGE_HOME/);
  assert.match(opportunities, /firstBossDefeatedInTime/);
  assert.match(opportunities, /room:IsClear\(\)/);
  assert.match(opportunities, /GetAliveBossesCount/);
  assert.match(opportunities, /flags:Get\(2\)/);
  assert.match(opportunities, /GetStartingRoomIndex/);
  assert.match(opportunities, /COLLECTIBLE_BROKEN_SHOVEL/);
  assert.match(opportunities, /COLLECTIBLE_MOMS_SHOVEL/);
  assert.match(opportunities, /string\.find\(currentRoomName, "grave"/);
  assert.match(opportunities, /routeEvents\.crackedKeyPrepared/);
  assert.match(opportunities, /not game:IsGreedMode\(\)[\s\S]*?ROOM_BOSS[\s\S]*?ENTITY_BABY_PLUM/);
});
