const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("route planner exposes every current-mode endpoint with live member status", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /function RouteRecommendations\.list\(goals, options\)/);
  assert.match(planner, /availableMemberIds/);
  assert.match(planner, /unavailableMemberIds/);
  assert.match(planner, /selectable\s*=/);
  assert.match(planner, /recoverable\s*=/);
  assert.match(planner, /failureReason\s*=/);
  assert.match(planner, /if options\.greed then return \{ options\.greedier and "greedier" or "greed" \} end/);
});

test("manual route scores merge current and general goals across four recommendation tiers", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /includeDiscouraged/);
  assert.match(planner, /relevance == "current" or relevance == "general"/);
  assert.match(planner, /strong=0, recommended=0, normal=0, discouraged=0/);
  assert.match(planner, /if left\.score\.strong ~= right\.score\.strong/);
  assert.match(planner, /if left\.score\.recommended ~= right\.score\.recommended/);
  assert.match(planner, /if left\.score\.normal ~= right\.score\.normal/);
  assert.match(planner, /if left\.score\.discouraged ~= right\.score\.discouraged/);
  assert.match(planner,
    /function RouteRecommendations\.choose[\s\S]*?includeDiscouraged=false[\s\S]*?RouteRecommendations\.list/);
});

test("route aids persist for one floor and R Key recovers failed normal routes", () => {
  const routes = read("scripts/core/routes.lua");
  const sensors = read("scripts/core/sensors.lua");
  const main = read("main.lua");
  assert.match(routes, /COLLECTIBLE_R_KEY/);
  assert.match(routes, /function Routes\.beginFloor\(run, stage, stageType, seed\)/);
  assert.match(routes, /run\.routeFloorAids/);
  assert.match(routes, /context\.groundAids/);
  assert.match(routes, /context\.heldAids/);
  assert.match(routes, /context\.aids\.r_key/);
  assert.match(sensors, /routeFloorAids=\{\}/);
  assert.match(sensors, /run\.routeFloorAids = type\(run\.routeFloorAids\)/);
  assert.match(main,
    /Routes\.beginFloor\(State\.run,[\s\S]*?current\.stage, current\.stageType, current\.seed\)/);
});

test("tracker replaces a route in place without consuming another slot", () => {
  const tracker = read("scripts/core/tracker.lua");
  assert.match(tracker, /function Tracker\.replaceRoute\(state, route\)/);
  assert.match(tracker, /if state\.route then[\s\S]*?state\.route = route[\s\S]*?return true/);
  assert.match(tracker, /Tracker\.slotCount\(state\) >= state\.max/);
});

test("F3 renders ranked route rows without duplicating shared member tiles", () => {
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(menu, /RouteRecommendations\.list\(Catalog\.goals/);
  assert.match(menu, /local tracked, routeEntries/);
  assert.match(menu, /if filter == "route" then return false end/);
  assert.match(menu, /candidate\.selectable/);
  assert.match(menu, /local score = selected\.candidate\.score/);
  assert.match(menu, /score\.strong/);
  assert.match(menu, /score\.recommended/);
  assert.match(menu, /score\.normal/);
  assert.match(menu, /score\.discouraged/);
  assert.match(menu, /Tracker\.replaceRoute\(state\.tracker, goal\.route\)/);
  assert.match(menu, /routeOptionUnavailable/);
  assert.match(text, /availableRoute\s*=\s*"可选路线"/);
  assert.match(text, /unavailableRoute\s*=\s*"当前不可选路线"/);
  assert.match(text, /routeUnavailable\s*=\s*"当前路线不可进入"/);
});
