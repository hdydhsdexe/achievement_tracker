const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("routes are modeled by six endpoints and migrate legacy families", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  for (const endpoint of ["mother", "lamb", "blue_baby", "beast", "greed", "greedier"]) {
    assert.match(planner, new RegExp(`${endpoint}\\s*=\\s*\\{`));
  }
  assert.match(planner, /LEGACY_ENDPOINTS[\s\S]*?chest\s*=\s*"blue_baby"/);
  assert.match(planner, /dark_room\s*=\s*"lamb"/);
  assert.match(planner, /optionalBosses/);
  assert.match(planner, /confirmedThrough/);
});

test("manual listing always exposes current-mode endpoints, including zero-goal navigation", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /NORMAL_ENDPOINT_ORDER\s*=\s*\{\s*"mother",\s*"lamb",\s*"blue_baby",\s*"beast"\s*\}/);
  assert.match(planner, /options\.greedier[\s\S]*?"greedier"[\s\S]*?"greed"/);
  assert.doesNotMatch(planner, /if #available > 0 or #unavailable > 0 then/);
  assert.match(planner, /score\.total > 0/);
});

test("optional bosses are stable, compatibility checked, and included in route members", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  for (const mark of ["BOSS_RUSH", "HUSH", "DELIRIUM", "MEGA_SATAN"]) {
    assert.match(planner, new RegExp(mark));
  }
  assert.match(planner, /function RouteRecommendations\.optionalBossEntries/);
  assert.match(planner, /function RouteRecommendations\.toggleOptionalBoss/);
  assert.match(planner, /function RouteRecommendations\.fullProcess/);
  assert.match(planner, /conditionalMemberIds/);
  assert.match(planner, /sortedOptionalBosses/);
});

test("F3 route filter expands optional boss children and paginates full process", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /entryKind="route_option"/);
  assert.match(menu, /RouteRecommendations\.optionalBossEntries/);
  assert.match(menu, /RouteRecommendations\.toggleOptionalBoss/);
  assert.match(menu, /RouteRecommendations\.fullProcess/);
  assert.match(menu, /KEY_PAGE_UP/);
  assert.match(menu, /KEY_PAGE_DOWN/);
  assert.doesNotMatch(menu, /KEY_PAGEUP|KEY_PAGEDOWN/);
  assert.match(menu,
    /local function triggered\(key\)[\s\S]*?type\(key\) == "number"[\s\S]*?Input\.IsButtonTriggered/);
  assert.match(menu, /detailPage/);
  assert.match(menu, /not active and goal\.option\.selected/);
});

test("route HUD supports pending extensions, confirmation, and structured remedies", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  const main = read("main.lua");
  const hud = read("scripts/ui/hud.lua");
  assert.match(planner, /function RouteRecommendations\.extension/);
  assert.match(planner, /function RouteRecommendations\.confirmExtension/);
  assert.match(planner, /function RouteRecommendations\.remedies/);
  assert.match(main, /pendingRouteExtension/);
  assert.match(main, /RouteRecommendations\.confirmExtension/);
  const quick = main.match(/local function updateQuickTrack\([\s\S]*?\nend/)?.[0] ?? "";
  assert.ok(quick.indexOf("sceneOpportunities") < quick.indexOf("pendingRouteExtension"));
  assert.match(hud, /routeMissedRemedies/);
  assert.match(hud, /routeExtensionPrompt/);
  assert.match(planner, /primaryMark and markFailed\(result, primaryMark\)/);
});

test("empty achievement membership does not discard a navigation route", () => {
  const tracker = read("scripts/core/tracker.lua");
  assert.doesNotMatch(tracker, /if #routeMembers == 0 then state\.route = nil end/);
  assert.match(tracker, /state\.route\.memberIds = routeMembers/);
  assert.match(tracker, /function Tracker\.sameRoute/);
});

test("stable prefixes use the catalog's permanent progression unlock IDs", () => {
  const routes = read("scripts/core/routes.lua");
  assert.match(routes, /deepPathsUnlocked=persistentUnlocked\(34\)/);
  assert.match(routes, /polaroidUnlocked=persistentUnlocked\(57\)/);
  assert.match(routes, /negativeUnlocked=persistentUnlocked\(78\)/);
  assert.match(routes, /strangeDoorUnlocked=persistentUnlocked\(635\)/);
  const planner = read("scripts/core/route_recommendations.lua");
  assert.doesNotMatch(planner,
    /secretExitUnlocked ~= false or context\.secretExitDoor\s*\n?\s*or .*r_key/);
  assert.match(planner, /context\.strangeDoorUnlocked ~= false and "BEAST"/);
  assert.match(planner, /context\.aids and context\.aids\.negative and "LAMB" or "SATAN"/);
  assert.match(planner, /context\.aids and context\.aids\.polaroid and "BLUE_BABY" or "ISAAC"/);
});
