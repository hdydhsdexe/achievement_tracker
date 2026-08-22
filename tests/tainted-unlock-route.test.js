const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

function functionBody(source, name) {
  const start = source.indexOf(`function ${name}`);
  assert.notEqual(start, -1, `${name} must exist`);
  const next = source.indexOf("\nfunction ", start + 1);
  return source.slice(start, next === -1 ? source.length : next);
}

function localFunctionBody(source, name) {
  const start = source.indexOf(`local function ${name}`);
  assert.notEqual(start, -1, `${name} must exist`);
  const next = source.indexOf("\nlocal function ", start + 1);
  return source.slice(start, next === -1 ? source.length : next);
}

test("generated achievements tag exactly 474 through 490 as tainted unlock routes", () => {
  const generator = read("tools/generate_achievement_catalog.mjs");
  const batch = read("scripts/data/achievements_401_500.lua");
  const taggedIds = [...batch.matchAll(/^\s*a\((\d+),.*"tainted_unlock".*\),$/gm)]
    .map((match) => Number(match[1]));

  assert.deepEqual(taggedIds, Array.from({ length: 17 }, (_, index) => 474 + index));
  assert.match(generator, /tainted_unlock/,
    "regenerating the catalog must retain the dedicated route metadata");
  assert.match(batch, /local function a\([^\n]*routeKind\)/);
  assert.match(batch, /routeKind\s*=\s*routeKind/,
    "the generated row must expose routeKind on the goal object");
});

test("tainted unlock routes bypass completion marks while Beast goals keep their route", () => {
  const routes = read("scripts/core/routes.lua");
  const evaluate = functionBody(routes, "Routes.evaluate");
  const tainted = localFunctionBody(routes, "taintedUnlockRoute");

  const specialIndex = evaluate.indexOf('goal.routeKind == "tainted_unlock"');
  const completionGuardIndex = evaluate.indexOf("not goal.completionRequirements");
  assert.ok(specialIndex >= 0 && specialIndex < completionGuardIndex,
    "the special route must be selected before the completionRequirements guard");
  assert.match(evaluate, /taintedUnlockRoute\(goal,\s*context,\s*language\)/);
  assert.match(evaluate, /requirement\.mark == "BEAST"[\s\S]*?beastRoute\(context,\s*language\)/,
    "normal Beast completion marks must continue to use the Beast route");

  assert.match(tainted, /context\.ascent/);
  assert.match(tainted, /STAGE\.HOME/);
  assert.match(tainted, /隐藏衣柜|hidden closet/);
  assert.match(tainted, /CharacterRelevance\.requiredPlayerTypes\(goal\)/,
    "the required normal character must come from goal metadata/copy, not tainted PlayerType arithmetic");
  assert.match(tainted, /context\.players/,
    "any matching player in a multiplayer team must satisfy the character requirement");
  assert.doesNotMatch(tainted, /Dogma|The Beast|教条|祸兽/,
    "unlocking the closet character must not instruct the player to fight the Beast");
});

test("route context detects Red Key, Cracked Key, and every ground trinket in eligible rooms", () => {
  const routes = read("scripts/core/routes.lua");
  const groundScan = localFunctionBody(routes, "scanGroundTrinkets");

  assert.match(routes, /red_key\s*=\s*\{kind="collectible",\s*id=enum\(CollectibleType,"COLLECTIBLE_RED_KEY",580\)/);
  assert.match(routes, /cracked_key\s*=\s*\{kind="card",\s*id=enum\(Card,"CARD_CRACKED_KEY",78\)/);
  assert.match(routes, /enum\(PickupVariant,"PICKUP_TRINKET",350\)/);
  assert.match(routes, /enum\(RoomType,"ROOM_TREASURE",4\)/);
  assert.match(routes, /enum\(RoomType,"ROOM_BOSS",5\)/);
  assert.match(routes, /GetCurrentRoomIndex\(\)/);
  assert.match(groundScan, /pickup\.Variant/);
  assert.match(groundScan, /pickup\.SubType\s*>\s*0/,
    "the scanner must accept arbitrary real trinkets rather than a named allow-list");
  assert.match(groundScan, /pickup\.InitSeed/,
    "placement tracking needs a stable pickup identity while the player remains in the room");
  assert.doesNotMatch(groundScan, /AID_DEFS/,
    "ordinary trinkets must not be restricted to known route aids");
});

test("trinket preparation persists through routeEvents and commits only after leaving it behind", () => {
  const routes = read("scripts/core/routes.lua");
  const main = read("main.lua");
  const updateRun = functionBody(routes, "Routes.updateRun");
  const observePickup = functionBody(routes, "Routes.observePickup");

  for (const field of ["taintedTrinketPending", "crackedKeyCandidate", "crackedKeyPrepared"]) {
    assert.match(routes, new RegExp(`routeEvents\\.${field}`), `${field} must use the persisted route event store`);
  }
  for (const field of ["stage", "stageType", "roomType", "roomIndex", "pickupSeed"]) {
    assert.match(updateRun, new RegExp(`\\b${field}\\s*=`),
      `prepared-room metadata must retain ${field} for the corresponding Ascent floor`);
  }
  assert.match(updateRun, /crackedKeyCandidate[\s\S]*?roomIndex[\s\S]*?crackedKeyPrepared/,
    "a candidate placement must become prepared only across a room transition");
  assert.match(updateRun, /context\.ascent[\s\S]*?taintedTrinketPending\s*=\s*nil/,
    "the pre-Ascent placement warning must end once the Ascent starts");
  assert.match(updateRun, /candidate and \(context\.ascent[\s\S]*?crackedKeyPrepared\s*=\s*\{/,
    "taking Dad's Note must commit a trinket still left in that room before Ascent routing starts");
  assert.match(routes, /routeEvents\.crackedKeyPrepared[\s\S]*?context\.stage/,
    "the Ascent route must use the recorded floor when directing the player to Cracked Key");
  assert.match(observePickup,
    /not trackTaintedUnlock and not candidate and not prepared[\s\S]*?if collecting[\s\S]*?if not trackTaintedUnlock then return false end/,
    "untracking may block new candidates, but an existing placement must still be revoked when picked up");
  assert.match(main, /goal\.routeKind == "tainted_unlock"/,
    "ordinary ground trinkets must only be tracked while a tainted unlock goal is active");
  assert.match(main, /Routes\.updateRun\(State\.run, routeContext, trackingTaintedUnlock\(\)\)/);
  assert.match(main, /Routes\.observePickup\(State\.run, pickup, GameInstance, trackingTaintedUnlock\(\)\)/);
});

test("tainted trinket reminders use the HUD route warning and never the popup warning channel", () => {
  const routes = read("scripts/core/routes.lua");
  const hud = read("scripts/ui/hud.lua");
  const tainted = localFunctionBody(routes, "taintedUnlockRoute");
  const render = functionBody(hud, "Hud.render");
  const renderWarning = functionBody(hud, "Hud.renderWarning");

  assert.match(tainted, /taintedTrinketPending[\s\S]*?"warning"/,
    "seeing a spare trinket must promote the tracked route to yellow warning severity");
  assert.match(tainted, /red_key|cracked_key/,
    "holding either key source must suppress or resolve the preparation warning");
  assert.match(render, /route\.severity == "warning" and HUD_WARNING/);
  assert.doesNotMatch(renderWarning, /tainted|trinket|cracked|route/i,
    "the existing temporary popup is reserved for evaluator failures/deadlines");
});
