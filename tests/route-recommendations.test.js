const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("route planner defines endpoint routes and optional boss compatibility", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  for (const endpoint of ["mother", "lamb", "blue_baby", "beast", "greed", "greedier"]) {
    assert.match(planner, new RegExp(`${endpoint}\\s*=\\s*\\{`));
  }
  assert.match(planner, /OPTIONAL_ORDER\s*=\s*\{\s*"BOSS_RUSH",\s*"HUSH",\s*"DELIRIUM",\s*"MEGA_SATAN"\s*\}/);
  assert.match(planner, /mark == "MEGA_SATAN"[\s\S]*?endpoint == "lamb" or endpoint == "blue_baby"/);
});

test("route planner selects only fully completable unfinished goals", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /function RouteRecommendations\.choose\(goals, options\)/);
  assert.match(planner, /options\.allowed ~= true then return nil/);
  assert.match(planner, /options\.isCompleted\(goal\)/);
  assert.match(planner, /options\.isTracked\(goal\.id\)/);
  assert.match(planner, /Recommendations\.priority\(goal\) ~= "discouraged"/);
  assert.match(planner, /requirement\.difficulty > options\.difficulty/);
  assert.match(planner, /not marks\[requirement\.mark\]/);
  assert.match(planner, /goal\.routeKind == "tainted_unlock"[\s\S]*?== "beast"/);
  assert.match(planner, /routeResult and routeResult\.severity == "failed"/);
});

test("route planner combines current and general goals with tier-count scoring", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /CharacterRelevance\.classify\(goal, options\.relevanceContext\)/);
  assert.match(planner, /relevance == "current" or relevance == "general"/);
  assert.match(planner, /strong[\s\S]*?recommended[\s\S]*?normal[\s\S]*?discouraged[\s\S]*?total[\s\S]*?earliest/);
  assert.match(planner, /if left\.score\.strong ~= right\.score\.strong/);
  assert.match(planner, /if left\.score\.recommended ~= right\.score\.recommended/);
  assert.match(planner, /if left\.score\.normal ~= right\.score\.normal/);
  assert.match(planner, /if left\.score\.discouraged ~= right\.score\.discouraged/);
  assert.match(planner, /table\.sort\(memberIds/);
});

test("route tracking consumes one slot while exposing every member", () => {
  const tracker = read("scripts/core/tracker.lua");
  const sensors = read("scripts/core/sensors.lua");
  assert.match(tracker, /function Tracker\.slotCount\(state\)/);
  assert.match(tracker, /state\.route and 1 or 0/);
  assert.match(tracker, /function Tracker\.routeContains\(state, id\)/);
  assert.match(tracker, /function Tracker\.containsAny\(state, id\)/);
  assert.match(tracker, /function Tracker\.allIds\(state\)/);
  assert.match(tracker, /function Tracker\.trackRoute\(state, route\)/);
  assert.match(tracker, /function Tracker\.untrackRoute\(state\)/);
  assert.match(sensors, /routeRecommendation=nil, trackedRoute=nil, startRoomPrompt=true/);
  assert.match(sensors, /run\.routeRecommendation/);
  assert.match(sensors, /run\.trackedRoute/);
});

test("new runs clear stale tracking and choose a fresh recommendation while continued runs restore it", () => {
  const main = read("main.lua");
  assert.match(main, /require\("scripts\.core\.route_recommendations"\)/);
  assert.match(main,
    /if not isContinued then[\s\S]*?prepareNewRunTracking[\s\S]*?completionAllowed\(\)[\s\S]*?RouteRecommendations\.choose/);
  assert.match(main, /State\.run\.routeRecommendation = recommendation/);
  assert.match(main, /Tracker\.setRoute\(State\.tracker, State\.run\.trackedRoute\)/);
  assert.match(main, /State\.run\.startRoomPrompt = false/);
  assert.ok(main.indexOf("local function isGoalCompleted") < main.indexOf("function AchievementTracker:onGameStarted"),
    "startup must capture the local completion helper instead of looking up a missing global");
  assert.match(main, /GetStartingRoomIndex\(\)/);
  assert.match(main, /for _, id in ipairs\(Tracker\.allIds\(State\.tracker\)\)/);
  assert.doesNotMatch(main, /schemaVersion\s*=\s*11/);
});

test("HUD merges route members and keeps the one-time start-room prompt", () => {
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(hud, /local function routeBlock\(state, language, maxWidth, fontPixels\)/);
  assert.match(hud, /RouteRecommendations\.combinedEvaluation/);
  assert.match(hud, /route\.memberIds/);
  assert.match(hud, /state\.run\.startRoomPrompt/);
  assert.match(hud, /Tracker\.routeContains/);
  assert.match(hud, /routeProgress/);
  assert.match(text, /routeRecommendation\s*=\s*"推荐路线"/);
  assert.match(text, /trackRecommendedRoute\s*=\s*"按 V 追踪整条路线"/);
  assert.match(text, /trackerFull/);
  assert.match(text, /routeConflict/);
});

test("F3 adds a route filter, virtual route row, and protected route members", () => {
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(menu, /"feature", "route", "other"/);
  assert.match(menu, /local function routeEntry\(candidate/);
  assert.match(menu, /entryKind="route"/);
  assert.match(menu, /local tracked, routeEntries, scenePending/);
  assert.match(menu, /\{ routeEntries, tracked, scenePending/);
  assert.match(menu, /Tracker\.routeContains\(state\.tracker, goal\.id\)/);
  assert.match(menu, /if goal\.entryKind == "route" then[\s\S]*?Tracker\.replaceRoute/);
  assert.match(menu, /labels\.routeMemberLocked/);
  assert.match(text, /route="路线"/);
});

test("V tracks scene opportunities first, then the route and neutral goals", () => {
  const main = read("main.lua");
  assert.match(main, /Keyboard\.KEY_V/);
  assert.match(main, /if State\.menu\.open then return end/);
  const vHandler = main.match(/local function updateQuickTrack\([\s\S]*?\nend/)?.[0] ?? "";
  const scene = vHandler.indexOf("sceneOpportunities");
  const route = vHandler.indexOf("trackRoute");
  const ordinary = vHandler.indexOf("bestOrdinaryGoal");
  assert.ok(scene >= 0 && route > scene && ordinary > route,
    "V must prefer a live scene opportunity, then a route, then one neutral goal");
  assert.match(vHandler, /State\.run\.startRoomPrompt/);
  assert.match(vHandler, /Tracker\.slotCount\(State\.tracker\) >= State\.tracker\.max/);
  assert.match(main, /quickTrackNotice[\s\S]*?untilFrame/);
});

test("tracked route conflicts are allowed but rendered as warnings", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  assert.match(planner, /function RouteRecommendations\.conflicts\(goal, route, options\)/);
  assert.match(planner, /return not routeCompatible/);
  assert.match(menu, /RouteRecommendations\.conflicts/);
  assert.match(menu, /VISUAL_STATES\.conflict/);
  assert.match(hud, /RouteRecommendations\.conflicts[\s\S]*?HUD_FAILED/);
});
