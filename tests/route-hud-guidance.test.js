const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("route HUD switches between compact current actions and full Tab details", () => {
  const hud = read("scripts/ui/hud.lua");
  assert.match(hud, /Input\.IsButtonPressed\(Keyboard\.KEY_TAB,\s*0\)/);
  assert.match(hud, /local expanded = routeDetailsHeld\(\)/);
  assert.match(hud, /if expanded then[\s\S]*?routeProgress[\s\S]*?routeMembers/);
  assert.match(hud, /if expanded and #evaluation\.next > 0 then/);
  assert.match(hud, /if route and not expanded then[\s\S]*?route\.current/,
    "individually tracked completion routes should also collapse to their current action");
});

test("route warnings and contextual hints render outside the Tab-only details", () => {
  const hud = read("scripts/ui/hud.lua");
  assert.match(hud, /evaluation\.departureWarnings/);
  assert.match(hud, /evaluation\.contextHints/);
  const expanded = hud.indexOf("if expanded then");
  const warnings = hud.indexOf("evaluation.departureWarnings");
  assert.ok(expanded >= 0 && warnings > expanded,
    "warnings must be appended after the optional expanded details");
  assert.match(hud, /HUD_WARNING/);
  assert.match(hud, /HUD_OPPORTUNITY/);
});

test("grid scanning distinguishes ordinary exits from Void portals", () => {
  const routes = read("scripts/core/routes.lua");
  assert.match(routes, /local function scanTrapdoors\(context, room\)/);
  assert.match(routes, /variant == 1 or varData == 1/);
  assert.match(routes, /variant == 0 and varData ~= 1[\s\S]*?context\.normalTrapdoor = true/);
  assert.match(routes, /normalTrapdoor=false/);
});

test("route guidance defines structured floor-exit obligations without parsing copy", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /local function departureWarnings\(route, options, result\)/);
  assert.match(planner, /context\.normalTrapdoor/);
  assert.match(planner, /route\.family == "mother"[\s\S]*?knife1[\s\S]*?knife2/);
  assert.match(planner, /route\.family == "chest"[\s\S]*?polaroid/);
  assert.match(planner, /route\.family == "dark_room"[\s\S]*?negative/);
  assert.match(planner, /route\.family == "beast"[\s\S]*?dads_note/);
  assert.match(planner, /BOSS_RUSH/);
  assert.match(planner, /HUSH[\s\S]*?DELIRIUM/);
  assert.match(planner, /sharp_key[\s\S]*?soul_cain[\s\S]*?cracked_orb/,
    "Mother warnings should honor the reliable flesh-door bypasses");
  assert.doesNotMatch(planner, /departureWarnings[\s\S]*?string\.find/);
});

test("Mega Satan guidance is phase-specific and suppressed by reliable gate access", () => {
  const planner = read("scripts/core/route_recommendations.lua");
  assert.match(planner, /local function megaSatanHints\(route, options\)/);
  assert.match(planner, /MEGA_SATAN/);
  for (const aid of ["dads_key", "jail_free", "mr_me", "sharp_key", "soul_cain", "cracked_orb"]) {
    assert.match(planner, new RegExp(aid));
  }
  assert.match(planner, /context\.roomType == ROOM_ANGEL/);
  assert.match(planner, /context\.aids\.key1[\s\S]*?context\.heldAids\.key1/);
  assert.match(planner, /context\.angelAlive/);
  assert.match(planner, /context\.angelStatue/);
  assert.match(planner, /context\.roomType == ROOM_SACRIFICE[\s\S]*?9\/11/);
  assert.match(planner, /options\.tracked == true/,
    "scene hints must not persist for an untracked recommendation");
});

test("live route context exposes Angel Room phases used by Mega Satan hints", () => {
  const routes = read("scripts/core/routes.lua");
  assert.match(routes, /ENTITY_URIEL/);
  assert.match(routes, /ENTITY_GABRIEL/);
  assert.match(routes, /GRID_STATUE/);
  assert.match(routes, /context\.angelAlive = true/);
  assert.match(routes, /context\.angelStatue = true/);
  assert.match(routes, /GetNumBombs/);
  assert.match(routes, /context\.hasBomb = true/);
});

test("HUD controls explain that Tab reveals route details in both languages", () => {
  const text = read("scripts/ui/text.lua");
  assert.match(text, /controls = "F3：选择目标\s*\|\s*按住 Tab 查看路线详情\s*\|\s*F4：隐藏"/);
  assert.match(text, /controls = "F3: goals\s*\|\s*Hold Tab for route details\s*\|\s*F4: hide"/);
});
