"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("catalog assigns exactly the approved 75 long-term milestones", () => {
  const goals = read("scripts/data/goals.lua");
  const table = goals.match(/local longTermMilestones\s*=\s*\{([\s\S]*?)\n\}/)?.[1] ?? "";
  const ids = [...table.matchAll(/\{(\d+),(\d+)\}/g)].map((match) => Number(match[1])).sort((a, b) => a - b);
  const expected = [
    8,10,11,12,26,28,30,32,33,34,36,57,59,61,64,66,68,78,85,
    134,135,136,137,138,139,140,141,142,145,147,148,150,151,152,153,154,
    234,242,243,244,245,246,247,248,249,250,251,275,325,336,341,342,343,
    344,345,346,347,350,353,354,358,362,364,371,375,376,377,380,382,383,
    385,407,409,523,545,
  ];
  assert.equal(ids.length, 75);
  assert.deepEqual(ids, expected);
  assert.equal(new Set(ids).size, ids.length);
  assert.match(goals, /for eventId = 159, 172/);
  assert.match(goals, /for eventId = 385, 403/);
  assert.match(goals, /greedDonationEvents\[#greedDonationEvents \+ 1\] = 212/);
  assert.match(goals, /source\.kind == "completion_mark_count"[\s\S]*?goal\.completionRequirements = nil/,
    "different-character counters must not be rendered as a single-character route");
});

test("resolver honors completion, native, import, observation, and unavailable priority", () => {
  const progress = read("scripts/core/long_term_progress.lua");
  const completed = progress.indexOf("if isCompleted(goal, state)");
  const native = progress.indexOf("local nativeData = persistentGameData()");
  const imported = progress.indexOf("local imported = aggregateEventIds");
  const observed = progress.indexOf("if source.observable and observed > 0");
  const unavailable = progress.indexOf('source="unavailable"');
  assert.ok(completed >= 0 && completed < native && native < imported && imported < observed);
  assert.ok(unavailable >= 0);
  assert.match(progress, /data:GetEventCounter\(eventId\)/);
  assert.match(progress, /math\.min\(value, target\)/);
  assert.match(progress, /snapshot\.values\[eventId \+ 1\]/);
  assert.match(progress, /source\.aggregate ~= "sum"/);
});

test("Chinese and English expose exact, imported, lower-bound, and unavailable wording", () => {
  const progress = read("scripts/core/long_term_progress.lua");
  for (const copy of ["截至导入 ", "已记录 ≥", "进度不可用", "as imported ", "recorded ≥", "progress unavailable"]) {
    assert.ok(progress.includes(copy), `missing progress copy: ${copy}`);
  }
  assert.match(progress, /return language == "zh" and \("（" \.\. ratio \.\. "）"\)/);
});

test("F3 selected detail and tracked HUD share the formatter without a long-term bar", () => {
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  assert.match(menu, /Catalog\.text\(selected, language\)\.detail[\s\S]*?LongTermProgress\.format\(selected, state, language\)/);
  assert.match(hud, /LongTermProgress\.format\(goal, state, language\)/);
  assert.match(hud, /if progress then[\s\S]*?progressText\(progress, target\)/);
  assert.doesNotMatch(hud, /progressText\(longTerm/);
});

test("vanilla observations persist only whitelisted event deltas with run deduplication", () => {
  const progress = read("scripts/core/long_term_progress.lua");
  const main = read("main.lua");
  assert.match(progress, /function LongTermProgress\.canObserve/);
  assert.match(progress, /AchievementUnlocksDisallowed/);
  assert.match(progress, /progressObserved\.eventCounters/);
  assert.match(progress, /longTermObservedPickups\[seed\]/);
  assert.match(progress, /longTermObservedRooms\[key\]/);
  assert.match(main, /MC_USE_CARD/);
  assert.match(main, /MOMS_HEART=1, ISAAC=11, SATAN=13, HUSH=158/);
});

test("counter condition copy uses corrected milestones", () => {
  const greed = read("scripts/data/achievements_201_300.lua");
  const later = read("scripts/data/achievements_301_400.lua");
  assert.match(greed, /a\(242,[^\n]*"Donate 2 Coins/);
  assert.match(greed, /a\(243,[^\n]*"Donate 14 Coins/);
  assert.match(greed, /a\(244,[^\n]*"Donate 33 Coins/);
  assert.match(later, /a\(377,[^\n]*"拾取血块10次。"/);
  assert.match(later, /a\(382,[^\n]*"拾取橡胶胶水5次。"/);
});
