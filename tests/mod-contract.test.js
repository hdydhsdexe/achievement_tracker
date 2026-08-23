const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("mod has v0.8.1 Workshop metadata and registers gameplay callbacks", () => {
  const metadata = read("metadata.xml");
  const main = read("main.lua");
  const mcm = read("scripts/integrations/mcm.lua");
  const description = read("docs/workshop/description.bbcode.txt");
  const changeNotes = read("docs/workshop/initial-change-notes.txt");
  assert.match(metadata, /<name>Achievement Tracker \/ 成就条件追踪器<\/name>/);
  assert.match(metadata, /<directory>achievement_tracker<\/directory>/);
  assert.match(metadata, /<id>3788047099<\/id>/);
  assert.match(metadata, /<version>0\.8\.1<\/version>/);
  assert.match(mcm, /Achievement Tracker v0\.8\.1/);
  assert.doesNotMatch(mcm, /Achievement Tracker v0\.2\.0/);
  assert.match(description, /Version 0\.8\.1/);
  assert.match(changeNotes, /v0\.8\.1/);
  assert.match(read("README.md"), /当前版本：\*\*0\.8\.1\*\*/);
  for (const document of [description, changeNotes, read("README.md")]) {
    assert.match(document, /11[^\n]*22[^\n]*33|11\/22\/33/,
      "release copy must describe the shared native integer-multiple HUD/F3 tiers");
    assert.match(document, /HUD[^\n]*(?:11|整数|integer)|(?:11|整数|integer)[^\n]*HUD/i);
    assert.doesNotMatch(document, /native 8\/10\/12|原生 8、10、12|8\/10\/12px/);
    assert.match(document, /line spacing|行间距/i,
      "release copy must describe the adjustable HUD line spacing");
    assert.doesNotMatch(document, /0\.7\.2/,
      "0.8.1 release copy must not retain the previous public version");
  }
  assert.doesNotMatch(metadata + mcm, /0\.7\.2/);
  assert.match(main, /RegisterMod\("Achievement Tracker", 1\)/);
  for (const callback of ["MC_POST_GAME_STARTED", "MC_POST_UPDATE", "MC_POST_RENDER", "MC_POST_PICKUP_UPDATE", "MC_PRE_GAME_EXIT"]) {
    assert.match(main, new RegExp(callback));
  }
});

test("Workshop publication assets satisfy uploader limits", () => {
  const description = read("docs/workshop/description.bbcode.txt");
  const cover = fs.statSync(path.join(root, "docs/workshop/cover.png"));
  assert.ok(description.length < 8000, "Workshop description must stay below 8000 characters");
  assert.ok(cover.size < 1024 * 1024, "Workshop cover must stay below 1 MiB");
  assert.match(description, /Version 0\.8\.1/);
});

test("catalog exposes only achievement-backed goals and drops stale tracked ids", () => {
  const catalog = read("scripts/data/goals.lua");
  const main = read("main.lua");
  const storage = read("scripts/core/storage.lua");
  const batches = fs.readdirSync(path.join(root, "scripts/data"))
    .filter((file) => /^achievements_\d+_\d+\.lua$/.test(file));
  assert.equal(batches.length, 8);
  for (const file of batches) assert.match(read(`scripts/data/${file}`), /achievementId=number/);
  assert.doesNotMatch(catalog, /legacyGoals|id="boss_rush"|id="hush"/);
  assert.match(catalog, /function Catalog\.isTrackable\(id\)/);
  assert.match(catalog, /goal\.achievementId ~= nil/);
  assert.match(main, /if Catalog\.isTrackable\(id\) then tracked\[#tracked \+ 1\] = id end/);
  assert.match(storage, /tracked\s*=\s*\{\}/);
});

test("catalog includes HuijiWiki achievement batch 1 through 50", () => {
  const batch = read("scripts/data/achievements_1_50.lua");
  const calls = [...batch.matchAll(/\ba\((\d+),/g)].map((match) => Number(match[1]));
  assert.deepEqual(calls, Array.from({ length: 50 }, (_, index) => index + 1));
  assert.match(batch, /Source: https:\/\/isaac\.huijiwiki\.com\/wiki\/成就/);
  assert.match(batch, /achievementId=number/);
});

test("catalog includes HuijiWiki achievement batch 51 through 100", () => {
  const batch = read("scripts/data/achievements_51_100.lua");
  const calls = [...batch.matchAll(/\ba\((\d+),/g)].map((match) => Number(match[1]));
  assert.deepEqual(calls, Array.from({ length: 50 }, (_, index) => index + 51));
  assert.match(batch, /reward\("trinket",35\)/);
  assert.match(batch, /reward\("card",32\)/);
  assert.match(batch, /achievement_86=\{kind="stage_type"/);
});

test("catalog includes every HuijiWiki achievement through 641", () => {
  const files = fs.readdirSync(path.join(root, "scripts/data"))
    .filter((file) => /^achievements_\d+_\d+\.lua$/.test(file));
  const calls = files.flatMap((file) =>
    [...read(`scripts/data/${file}`).matchAll(/\ba\((\d+),/g)].map((match) => Number(match[1]))
  ).sort((left, right) => left - right);
  assert.deepEqual(calls, Array.from({ length: 641 }, (_, index) => index + 1));
  const later = files.filter((file) => !/^(achievements_1_50|achievements_51_100)\.lua$/.test(file))
    .map((file) => read(`scripts/data/${file}`)).join("\n");
  assert.match(later, /reward\("collectible",\d+\)/);
  assert.match(later, /reward\("trinket",\d+\)/);
  assert.match(later, /reward\("card",\d+\)/);
  assert.match(later, /a\(474,[\s\S]*?observe\("player",21\)/);
  assert.match(later, /a\(490,[\s\S]*?observe\("player",37\)/);
});

test("tracking core enforces uniqueness and a configurable maximum", () => {
  const tracker = read("scripts/core/tracker.lua");
  assert.match(tracker, /function Tracker\.track/);
  assert.match(tracker, /#state\.ids\s*>=\s*state\.max/);
  assert.match(tracker, /Tracker\.contains/);
});

test("warning core supports deadline, lost eligibility, and warning deduplication", () => {
  const evaluator = read("scripts/core/evaluator.lua");
  assert.match(evaluator, /snapshot\.eligible\s*==\s*false/);
  assert.match(evaluator, /goal\.deadline/);
  assert.match(evaluator, /state\.emitted/);
  assert.match(evaluator, /function Evaluator\.reset/);
});

test("restricted pickup detection waits for the pickup collect animation", () => {
  const sensors = read("scripts/core/sensors.lua");
  assert.match(sensors, /sprite:IsPlaying\("Collect"\)/);
  assert.match(sensors, /local seed = tostring\(pickup\.InitSeed\)/);
  assert.doesNotMatch(sensors, /local seed = pickup\.InitSeed\s*\n/);
  assert.match(sensors, /PICKUP_HEART/);
  assert.match(sensors, /PICKUP_COIN/);
  assert.match(sensors, /PICKUP_BOMB/);
});

test("menu and HUD are usable without optional Mod Config Menu", () => {
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  const mcm = read("scripts/integrations/mcm.lua");
  assert.match(menu, /Input\.IsButtonTriggered/);
  assert.match(menu, /Tracker\.toggle/);
  assert.match(hud, /Text\.draw/);
  assert.match(mcm, /ModConfigMenu\s*==\s*nil/);
});

test("F3 menu uses a paged three-column tile grid", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local COLUMNS = 3/);
  assert.match(menu, /pageSize=rows \* COLUMNS/);
  assert.match(menu, /layout\.pageSize/);
  assert.match(menu, /layout\.rows/);
  assert.doesNotMatch(menu, /local PAGE_SIZE/);
  assert.match(menu, /Keyboard\.KEY_LEFT/);
  assert.match(menu, /Keyboard\.KEY_RIGHT/);
  assert.match(menu, /column \* columnWidth/);
});

test("F3 navigation repeats held arrows after a real-time delay without wrapping", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local HOLD_DELAY_MS = 300/);
  assert.match(menu, /local HOLD_REPEAT_MS = 90/);
  assert.match(menu, /Input\.IsButtonPressed\(key, 0\)/);
  assert.match(menu, /Isaac\.GetTime\(\)/);
  assert.match(menu, /repeatKeys/);
  assert.match(menu, /state\.menu\.repeatKeys = \{\}/);
  assert.match(menu, /math\.max\(1, state\.menu\.cursor - 1\)/);
  assert.match(menu, /math\.min\(count, state\.menu\.cursor \+ COLUMNS\)/);
  assert.doesNotMatch(menu, /state\.menu\.cursor\s*%\s*count/,
    "held navigation must clamp at the list boundaries rather than wrap");
});

test("F3 mouse hover selects visible tiles and a left-click edge toggles tracking", () => {
  const main = read("main.lua");
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local function fitMenuLayout\(state\)/);
  assert.match(menu, /Input\.GetMousePosition\(false\)/);
  assert.match(menu, /Input\.IsMouseBtnPressed\(Mouse\.MOUSE_BUTTON_LEFT\)/);
  assert.match(menu, /local clicked = mouseDown and not state\.menu\.mouseDown/);
  assert.match(menu, /local function mouseGoalIndex/);
  assert.match(menu, /state\.menu\.offset \+ row \* COLUMNS \+ column/);
  assert.match(menu, /local function toggleGoal/);
  assert.match(menu, /refreshGoals\(state, context, true\)/);
  assert.match(menu, /SHOOT_KEYS\[buttonAction\]/);
  assert.match(menu, /mouseInsidePanel\(Input\.GetMousePosition\(false\), fitMenuLayout\(state\)\)/);
  assert.match(main, /InputHook\.GET_ACTION_VALUE/,
    "blocked mouse shooting must return the correct value for analog input hooks");
});

test("F3 untracking keeps the current list position until the next refresh", () => {
  const menu = read("scripts/ui/menu.lua");
  const toggle = menu.match(/local function toggleGoal[\s\S]*?\nend\n\nlocal function typedSearchCharacter/);
  assert.ok(toggle, "toggleGoal must remain the shared keyboard and mouse tracking path");
  assert.match(toggle[0], /local wasTracked = Tracker\.contains\(state\.tracker, goal\.id\)/);
  assert.match(toggle[0], /Tracker\.toggle\(state\.tracker, goal\.id\)/);
  assert.match(toggle[0], /state\.settings\.tracked = state\.tracker\.ids[\s\S]*?save\(\)/,
    "both tracking directions must persist immediately");
  assert.match(toggle[0], /if not wasTracked then refreshGoals\(state, context, true\) end/,
    "only newly tracked goals should trigger an immediate reorder");
  assert.equal((toggle[0].match(/refreshGoals\(/g) || []).length, 1,
    "untracking must not have a second unconditional refresh path");
  assert.doesNotMatch(toggle[0], /state\.menu\.(?:cursor|offset)\s*=/,
    "untracking must leave the current selection and page untouched");
  assert.match(menu, /if queryChanged then[\s\S]*?refreshGoals\(state, context, false\)/);
  assert.match(menu, /Keyboard\.KEY_TAB[\s\S]*?refreshGoals\(state, context, false\)/);
  assert.match(menu, /Keyboard\.KEY_F3[\s\S]*?refreshGoals\(state, nil, false\)/);
  assert.match(menu, /toggleGoal\(state, goals\[activatedIndex\], save, context\)/,
    "keyboard and mouse activation must share the delayed-untracking behavior");
});

test("F3 consumes only controller-zero gameplay actions owned by menu keys", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local SHOOT_KEYS = \{/);
  for (const [action, key] of [
    ["ACTION_SHOOTLEFT", "KEY_LEFT"], ["ACTION_SHOOTRIGHT", "KEY_RIGHT"],
    ["ACTION_SHOOTUP", "KEY_UP"], ["ACTION_SHOOTDOWN", "KEY_DOWN"]
  ]) {
    assert.match(menu, new RegExp(`\\[ButtonAction\\.${action}\\]\\s*=\\s*Keyboard\\.${key}`));
  }
  assert.match(menu, /Input\.IsButtonPressed\(shootKey, 0\)/,
    "held arrow navigation must not leak into shooting");
  assert.match(menu, /buttonAction == ButtonAction\.ACTION_ITEM[\s\S]*?Keyboard\.KEY_SPACE/,
    "Space tracking must not use the active item");
  assert.match(menu, /if not player or player\.ControllerIndex ~= 0 then return false end/,
    "other controllers and nil or non-player input queries must remain untouched");
  assert.match(menu, /local keyboardIndex = keyboardActivated and state\.menu\.cursor/);
  assert.match(menu, /local activatedIndex = mouseIndex or keyboardIndex/,
    "mouse movement alone must not retarget a simultaneous keyboard activation");
});

test("tracker HUD visualizes failed, completed, and counter progress states", () => {
  const menu = read("scripts/ui/menu.lua");
  const hud = read("scripts/ui/hud.lua");
  const goals = read("scripts/data/goals.lua");
  const sensors = read("scripts/core/sensors.lua");
  assert.doesNotMatch(menu, /failedGoals/);
  assert.match(menu, /Text\.ellipsize/);
  assert.match(hud, /failedGoals/);
  assert.match(hud, /completedGoals/);
  assert.doesNotMatch(hud, /Isaac\.DrawLine/);
  assert.match(hud, /string\.rep\("#"/);
  assert.match(hud, /Sensors\.progress/);
  assert.match(goals, /achievement_330 = \{ progressKey="items", target=50 \}/);
  assert.match(goals, /achievement_386 = \{ progressKey="gulp", target=5 \}/);
  assert.match(sensors, /PILLEFFECT_GULP/);
  assert.match(sensors, /completedGoals\.achievement_386/);
});

test("reward metadata is normalized once for completion detection and display", () => {
  const rewards = read("scripts/core/rewards.lua");
  const unlocks = read("scripts/core/unlocks.lua");
  const goals = read("scripts/data/goals.lua");
  assert.match(rewards, /function Rewards\.resolveId/);
  assert.match(rewards, /function Rewards\.config/);
  assert.match(rewards, /function Rewards\.display/);
  for (const kind of ["collectible", "trinket", "card", "pickup", "slot", "grid",
    "character", "monster", "area", "challenge", "feature", "other"]) {
    assert.match(rewards, new RegExp(`\\b${kind}\\b`));
  }
  assert.doesNotMatch(unlocks, /local rewards\s*=\s*{/);
  assert.match(unlocks, /Rewards\.config/);
  assert.match(goals, /trackingMetadata/);
  assert.match(goals, /goal\.reward\s*=\s*Rewards\.display\(goal\)/);
});

test("F3 maps achievement-unlocked world entities to semantic reward metadata", () => {
  const goals = read("scripts/data/goals.lua");
  const rewards = read("scripts/core/rewards.lua");
  const expected = [
    [33, "pickup", "variant=10, subtype=8"],
    [224, "pickup", "variant=10, subtype=7"],
    [226, "pickup", "variant=40, subtype=4"],
    [240, "pickup", "variant=20, subtype=6"],
    [242, "pickup", "variant=20, subtype=5"],
    [328, "pickup", "variant=10, subtype=9"],
    [333, "pickup", "variant=30, subtype=4"],
    [391, "pickup", "variant=10, subtype=11"],
    [411, "pickup", "variant=10, subtype=12"],
    [601, "pickup", "variant=57, subtype=0"],
    [603, "pickup", "variant=70, subtype=14"],
    [604, "pickup", "variant=69, subtype=2"],
    [606, "pickup", "variant=70, subtype=2049"],
    [609, "pickup", "variant=56, subtype=0"],
    [611, "pickup", "variant=58, subtype=0"],
    [613, "pickup", "variant=20, subtype=7"],
    [615, "pickup", "variant=90, subtype=4"],
    [605, "grid", "gridType=14, variant=11"],
    [612, "grid", "gridType=27, variant=0"],
    [607, "slot", "variant=16"],
    [608, "slot", "variant=15"],
    [614, "slot", "variant=18"],
    [616, "slot", "variant=17"]
  ];
  assert.match(goals, /local rewardOverrides\s*=\s*\{/);
  for (const [achievementId, kind, fields] of expected) {
    const fieldPattern = fields.replace(/([.*+?^${}()|[\]\\])/g, "\\$1").replace(/, /g, ",\\s*");
    assert.match(goals, new RegExp(
      `achievement_${achievementId}\\s*=\\s*\\{kind="${kind}",\\s*${fieldPattern}\\s*\\}`),
      `achievement ${achievementId} must expose ${kind} metadata`);
  }
  assert.match(goals, /local override = rewardOverrides\[goal\.id\]/);
  assert.match(goals, /if override then goal\.reward = override end/);
  assert.match(rewards, /variant=reward\.variant/);
  assert.match(rewards, /subtype=reward\.subtype/);
  assert.match(rewards, /gridType=reward\.gridType/);
  assert.match(rewards, /pickup="pickup"/);
  assert.match(rewards, /slot="world"/);
  assert.match(rewards, /grid="world"/);
});

test("F3 world entity icons use native game actors with static frames and fallback", () => {
  const icons = read("scripts/ui/reward_icons.lua");
  const expectedResources = [
    "005.018_heart (halfsoul).anm2", "005.017_goldheart.anm2",
    "005.020_scared heart.anm2", "005.01a_bone heart.anm2",
    "005.01b_rotten heart.anm2", "005.025_sticky nickel.anm2",
    "005.026_lucky penny.anm2", "005.027_golden penny.anm2",
    "005.034_chargedkey.anm2", "005.043_golden bomb.anm2",
    "005.057_mega chest.anm2", "005.084_pill gold-gold.anm2",
    "005.069_black sack.anm2", "005.071_horse pill blue-blue.anm2",
    "005.056_wooden chest.anm2", "005.058_haunted chest.anm2",
    "005.090_golden battery.anm2", "006.015_hell game.anm2",
    "006.016_crane game.anm2", "006.017_confessional.anm2",
    "006.018_rotten beggar.anm2", "grid/grid_poop.anm2",
    "grid/grid_rock.anm2"
  ];
  for (const resource of expectedResources) {
    assert.match(icons, new RegExp(resource.replace(/([.*+?^${}()|[\]\\])/g, "\\$1")),
      `${resource} must be loaded from the active game resources`);
  }
  assert.match(icons, /local nativePickupResources\s*=\s*\{/);
  assert.match(icons, /local nativeSlotResources\s*=\s*\{/);
  assert.match(icons, /local nativeGridResources\s*=\s*\{/);
  assert.match(icons, /grid_poop_charming\.png/);
  assert.match(icons, /animation="State1", frame=5/);
  assert.match(icons, /animation="foolsgold", frame=0/);
  assert.match(icons, /animation="Idle", frame=0/);
  assert.match(icons, /resource\.spritesheet[\s\S]*?ReplaceSpritesheet\(0, resource\.spritesheet\)/);
  assert.match(icons, /validFrame\(sprite, resource\.animation, resource\.frame\)/);
  assert.match(icons, /reward\.kind == "pickup"/);
  assert.match(icons, /reward\.kind == "slot"/);
  assert.match(icons, /reward\.kind == "grid"/);
  assert.match(icons, /offsetX|offsetY/,
    "large native actors need explicit centering metadata");
  assert.match(icons, /if not entry then entry = fallbackSprite\(reward\) end/);
  for (const copiedAsset of [
    "005.017_goldheart.anm2", "006.016_crane game.anm2",
    "grid_poop_charming.png", "grid_rock.anm2"
  ]) {
    assert.equal(fs.existsSync(path.join(root, "resources/gfx", copiedAsset)), false,
      `${copiedAsset} must not be bundled by the mod`);
  }
});

test("F3 exposes every semantic reward group as a single-level filter", () => {
  const goals = read("scripts/data/goals.lua");
  const rewards = read("scripts/core/rewards.lua");
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  for (const [kind, labelCount] of [["pickup", 4], ["slot", 2], ["grid", 2]]) {
    assert.match(goals, new RegExp(`${kind}="[^"]+"`));
    assert.equal((text.match(new RegExp(`${kind}="`, "g")) || []).length, labelCount,
      `${kind} must have Chinese and English labels`);
  }
  assert.match(menu, /local FILTERS = \{ "all", "collectible", "trinket", "card",\s*\n\s*"character", "monster", "area", "challenge", "pickup", "world",\s*\n\s*"feature", "other" \}/);
  for (const [filter, labelCount] of [
    ["character", 4], ["monster", 4], ["area", 4], ["challenge", 4],
    ["pickup", 4], ["world", 2], ["feature", 4]
  ]) {
    assert.equal((text.match(new RegExp(`${filter}="`, "g")) || []).length, labelCount,
      `${filter} must have Chinese and English filter labels`);
  }
  for (const [kind, filter] of [
    ["collectible", "collectible"], ["trinket", "trinket"], ["card", "card"],
    ["pickup", "pickup"], ["slot", "world"], ["grid", "world"],
    ["character", "character"], ["monster", "monster"], ["area", "area"],
    ["challenge", "challenge"], ["feature", "feature"], ["other", "other"]
  ]) assert.match(rewards, new RegExp(`${kind}="${filter}"`));
  for (const aliases of [
    /collectible="[^"]*item[^"]*道具/, /trinket="[^"]*饰品/,
    /card="[^"]*卡牌/, /character="[^"]*人物/,
    /monster="[^"]*monster[^"]*怪物/, /area="[^"]*location[^"]*地点/,
    /challenge="[^"]*挑战/, /pickup="[^"]*掉落物/,
    /slot="[^"]*scenery[^"]*机器与场景/, /grid="[^"]*scenery[^"]*机器与场景/,
    /feature="[^"]*mechanic[^"]*机制/, /other="[^"]*其他/
  ]) assert.match(goals, aliases);
  assert.match(menu, /string\.format\(labels\.filterStatus, name, active, #FILTERS\)/);
});

test("non-standard achievement rewards use explicit semantic metadata", () => {
  const goals = read("scripts/data/goals.lua");
  const rewards = read("scripts/core/rewards.lua");
  const overrides = goals.match(/local rewardOverrides\s*=\s*\{[\s\S]*?\n\}/);
  assert.ok(overrides, "reward overrides must remain a single auditable table");
  for (const [kind, ids] of Object.entries({
    monster: [142, 155, 346, 347, 348],
    area: [234, 320, 342, 343, 344, 345, 406, 407, 412, 413, 414, 635],
    challenge: [157, 158, 160, 163, 166, 265, 266, 269, 270, 272, 273, 274,
      277, 278, 279, 510, 511, 513, 514, 515, 516],
    feature: [151, 152, 153, 154, 178, 191, 243, 246, 247, 275, 323, 337,
      341, 593, 617, 638, 639, 640, 641],
    pickup: [227, 228, 332]
  })) {
    for (const id of ids) assert.match(overrides[0],
      new RegExp(`achievement_${id}\\s*=\\s*\\{kind="${kind}"`),
      `achievement ${id} must be classified as ${kind}`);
  }
  for (const id of [167, 69]) assert.doesNotMatch(overrides[0],
    new RegExp(`achievement_${id}\\s*=`),
    `achievement ${id} must remain in the residual Other group`);
  assert.match(rewards, /observation\.kind == "boss"[\s\S]*?return "monster"/);
  assert.doesNotMatch(rewards, /challenge #/i,
    "completion-condition text must not determine the unlocked reward category");
});

test("all 641 achievements have one audited filter including representative rewards", () => {
  const dataDir = path.join(root, "scripts/data");
  const batches = fs.readdirSync(dataDir)
    .filter((file) => /^achievements_\d+_\d+\.lua$/.test(file));
  const goals = read("scripts/data/goals.lua");
  const overrideBlock = goals.match(/local rewardOverrides\s*=\s*\{([\s\S]*?)\n\}/)[1];
  const overrides = new Map([...overrideBlock.matchAll(
    /achievement_(\d+)\s*=\s*\{kind="([^"]+)"/g
  )].map((match) => [Number(match[1]), match[2]]));
  const observations = new Map();
  const achievements = new Map();

  for (const file of batches) {
    const source = read(`scripts/data/${file}`);
    for (const match of source.matchAll(/achievement_(\d+)\s*=\s*\{kind="([^"]+)"/g))
      observations.set(Number(match[1]), match[2]);
    for (const line of source.split(/\r?\n/)) {
      const row = line.match(/^\s*a\((\d+),/);
      if (!row) continue;
      const id = Number(row[1]);
      const reward = line.match(/reward\("([^"]+)"/);
      const observation = line.match(/observe\("([^"]+)"/);
      achievements.set(id, {
        reward: reward && reward[1] || (/",\s*\d+\s*\),?\s*$/.test(line) ? "collectible" : null),
        observation: observation && observation[1]
      });
    }
  }

  const filterFor = (id) => {
    const row = achievements.get(id);
    const kind = overrides.get(id) || row.reward || row.observation || observations.get(id) || "other";
    return ({slot: "world", grid: "world", player: "character", boss: "monster",
      stage: "area", stage_type: "area"})[kind] || kind;
  };
  const expected = {
    1: "character", 474: "character", 5: "monster", 16: "monster",
    4: "area", 86: "area", 320: "area", 412: "area",
    166: "challenge", 265: "challenge", 510: "challenge", 33: "pickup",
    605: "world", 607: "world", 151: "feature", 337: "feature",
    167: "other", 69: "other"
  };
  for (const [id, filter] of Object.entries(expected))
    assert.equal(filterFor(Number(id)), filter, `achievement ${id} must be ${filter}`);

  assert.equal(achievements.size, 641);
  const counts = {};
  for (const id of achievements.keys()) counts[filterFor(id)] = (counts[filterFor(id)] || 0) + 1;
  assert.deepEqual(counts, {
    character: 33, collectible: 286, area: 16, monster: 12, other: 65,
    pickup: 20, trinket: 99, card: 64, feature: 19, challenge: 21, world: 6
  });
  assert.equal(Object.values(counts).reduce((sum, count) => sum + count, 0), 641);
});

test("reward icon renderer uses vanilla graphics with cached sprites", () => {
  const icons = read("scripts/ui/reward_icons.lua");
  const actor = read("resources/gfx/ui/achievement_tracker_ui.anm2");
  assert.match(icons, /local cache\s*=\s*{/);
  assert.match(icons, /GfxFileName/);
  assert.match(icons, /config\.HudAnim/);
  assert.match(icons, /gfx\/ui\/ui_cardfronts\.anm2/);
  assert.match(icons, /gfx\/ui\/ui_cardspills\.anm2/);
  assert.match(icons, /"CardFronts"/);
  assert.match(icons, /ReplaceSpritesheet/);
  assert.match(icons, /LoadGraphics/);
  assert.match(icons, /function RewardIcons\.render/);
  assert.match(icons, /function RewardIcons\.renderPaper\(panelX, panelY, panelWidth, panelHeight\)/);
  assert.doesNotMatch(icons, /screenWidth \/ 120|screenHeight \/ 68/);
  const renderBody = icons.match(/function RewardIcons\.render[\s\S]*?\nend/)[0];
  assert.doesNotMatch(renderBody, /LoadGraphics/);
  assert.equal(fs.existsSync(path.join(root, "resources/gfx/ui/achievement_tracker_ui.anm2")), true);
  assert.equal(fs.existsSync(path.join(root, "resources/gfx/ui/achievement_reward_types.png")), true);
  assert.equal(fs.existsSync(path.join(root, "resources/gfx/ui/ui_cardfronts.anm2")), false,
    "the mod must read the game's card-front actor instead of bundling it");
  assert.equal(fs.existsSync(path.join(root, "resources/gfx/ui/ui_cardfronts.png")), false,
    "the mod must read the active game's card-front texture instead of copying it");
  assert.equal(fs.existsSync(path.join(root, "resources/gfx/ui/ui_cardspills.png")), false,
    "the mod must read the active game's card-spill texture instead of copying it");
  assert.match(icons, /fallbackFrames/);
  assert.match(icons, /SetFrame\("FallbackIcon"/);
  assert.match(actor, /achievement_reward_types\.png/);
  assert.match(actor, /Animation Name="FallbackIcon" FrameNum="5"/);
  assert.match(actor, /Animation Name="Backdrop"/);
  assert.match(actor, /Animation Name="RewardItem"/);
  assert.match(icons, /ReplaceSpritesheet\(3, config\.GfxFileName\)/);
  assert.match(icons, /SetFrame\("RewardItem", 0\)/);
  assert.match(icons, /validFrame\(sprite, hudAnimation, 0\)/);
  assert.match(icons, /VANILLA_CARD_MAX\s*=\s*Card and Card\.NUM_CARDS and \(Card\.NUM_CARDS - 1\) or 97/);
  assert.match(icons, /reward\.id\s*<=\s*VANILLA_CARD_MAX/);
  assert.doesNotMatch(icons, /sprite:GetDefaultAnimation\(\)/,
    "the default card-front animation is the one-frame Fool animation");
  assert.match(icons, /setCardSpillFrame\(sprite, reward\.id\)/);
  assert.match(icons, /sprite:SetFrame\("CardFronts", 0\)/);
  assert.match(icons, /sprite:SetLayerFrame\(0, frame\)/,
    "card spill faces must select layer frame by Card ID, including Queen of Hearts");
  assert.match(icons, /layerFrame=reward\.id/);
  assert.match(icons, /entry\.sprite:SetLayerFrame\(entry\.layer, entry\.layerFrame\)/);
  assert.match(icons, /sprite:GetAnimation\(\) == animation/);
  assert.match(icons, /sprite:GetFrame\(\) == frame/);
  assert.match(icons, /pcall\(Rewards\.config, reward\)/);
  assert.match(icons, /baseSize=32/);
  assert.match(icons, /baseSize=24/);
  assert.match(icons, /if not entry then entry = fallbackSprite\(reward\) end/);
  assert.match(icons, /if cardFrontSprite ~= nil then return cardFrontSprite or nil end/);
  assert.match(icons, /if cardSpillSprite ~= nil then return cardSpillSprite or nil end/);
  assert.match(icons, /function RewardIcons\.clear\(\)[\s\S]*?cardFrontSprite\s*=\s*nil/);
  assert.match(icons, /function RewardIcons\.clear\(\)[\s\S]*?cardSpillSprite\s*=\s*nil/);
  assert.match(icons, /validFrame\(sprite, "HUD", 0\)/);
  assert.match(icons,
    /local path = nativeCardResources\[reward\.id\][\s\S]*?if path then[\s\S]*?else[\s\S]*?getCardSpillSprite\(\)/,
    "special native actors must be resolved before the shared spill atlas");
  assert.match(icons, /entry\.sprite\.Color = tint or Color\(1, 1, 1, 1\)/);
  for (const [id, resource] of [
    [32, "005.303_rune1.anm2"],
    [41, "005.307_blackrune.anm2"],
    [55, "005.313_rune shard.anm2"],
    [78, "005.300.15_cracked key.anm2"],
    [80, "005.300.17_unus card.anm2"],
    [81, "005.300.18_soul of isaac.anm2"],
    [97, "005.300.34_soul of jacob.anm2"]
  ]) {
    assert.match(icons, new RegExp(`\\[${id}\\].*${resource.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\$&")}`),
      `card id ${id} must resolve to its native HUD actor`);
  }
  const nativeCardIds = [...icons.matchAll(/^\s*\[(\d+)\]="gfx\/005\.[^"]+\.anm2",?$/gm)]
    .map((match) => Number(match[1]));
  assert.deepEqual(nativeCardIds, [
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
    55, 78, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97
  ]);
  assert.match(icons, /if nativeCardSprites\[path\] ~= nil then return nativeCardSprites\[path\] or nil end/);
  assert.match(icons, /function RewardIcons\.clear\(\)[\s\S]*?nativeCardSprites\s*=\s*\{\}/);
  assert.doesNotMatch(icons, /005\.100_collectible\.anm2/);
  assert.match(actor, /Width="263" Height="176"/);
  assert.match(actor, /Animation Name="Backdrop"[\s\S]*?AlphaTint="220"/);
  assert.match(actor, /Animation Name="Paper"[\s\S]*?AlphaTint="255"/);

  const batches = fs.readdirSync(path.join(root, "scripts/data"))
    .filter((file) => /^achievements_\d+_\d+\.lua$/.test(file))
    .map((file) => read(`scripts/data/${file}`)).join("\n");
  const cardIds = [...batches.matchAll(/reward\("card",(\d+)\)/g)]
    .map((match) => Number(match[1]));
  assert.ok(cardIds.length > 0);
  assert.ok(cardIds.every((id) => id >= 1 && id <= 97));
  for (const representative of [27, 32, 51, 56, 80, 97]) {
    assert.ok(cardIds.includes(representative),
      `catalog should exercise card rendering with card id ${representative}`);
  }
});

test("character rewards retain PlayerType ids inferred from achievement observations", () => {
  const rewards = read("scripts/core/rewards.lua");
  const early = read("scripts/data/achievements_1_50.lua");
  const repentance = read("scripts/data/achievements_401_500.lua");
  assert.match(rewards, /kind == "character"[\s\S]*?observation\.values\[1\]/);
  assert.match(rewards, /return \{ kind=kind, id=id, achievementId=goal and goal\.achievementId \}/);
  assert.match(early, /achievement_1=\{kind="player", values=\{1\}\}/);
  assert.match(repentance, /a\(474,[^\n]+observe\("player",21\)/);
});

test("character reward renderer loads cached vanilla portraits with safe fallbacks", () => {
  const icons = read("scripts/ui/reward_icons.lua");
  const actor = read("resources/gfx/ui/achievement_tracker_ui.anm2");
  for (const [playerType, portrait] of [
    [1, "magdalene"], [10, "thelost"], [16, "theforgotten"],
    [19, "jacob"], [21, "isaac_b"], [30, "eden_b"], [37, "jacob_b"]
  ]) {
    assert.match(icons, new RegExp(`\\[${playerType}\\]="playerportrait_${portrait}\\.png"`));
  }
  const batches = fs.readdirSync(path.join(root, "scripts/data"))
    .filter((file) => /^achievements_\d+_\d+\.lua$/.test(file))
    .map((file) => read(`scripts/data/${file}`)).join("\n");
  const observedPlayerTypes = new Set([
    ...[...batches.matchAll(/observe\("player",(\d+)\)/g)].map((match) => Number(match[1])),
    ...[...batches.matchAll(/kind="player",\s*values=\{(\d+)\}/g)].map((match) => Number(match[1]))
  ]);
  const mappedPlayerTypes = new Set(
    [...icons.matchAll(/\[(\d+)\]="playerportrait_/g)].map((match) => Number(match[1]))
  );
  for (const playerType of observedPlayerTypes) {
    assert.ok(mappedPlayerTypes.has(playerType), `missing portrait mapping for PlayerType ${playerType}`);
  }
  assert.match(icons, /local function characterSprite\(reward\)/);
  assert.match(icons, /pcall\(function\(\)/);
  assert.match(icons, /ReplaceSpritesheet\(4, "gfx\/ui\/stage\/" \.\. filename\)/);
  assert.match(icons, /sprite:SetFrame\(tall and "RewardPortraitTall" or "RewardPortrait", 0\)/);
  assert.match(icons, /TALL_CHARACTER_PORTRAITS = \{ \[37\]=true, \[39\]=true \}/);
  assert.match(icons, /local function taintedEdenOverlay\(\)[\s\S]*?edenHead:Load\("gfx\/ui\/stage\/eden_b_head\.anm2", true\)/);
  assert.match(icons, /edenHead:GetDefaultAnimation\(\)/);
  assert.match(icons, /reward\.id == TAINTED_EDEN and taintedEdenOverlay\(\) or nil/);
  assert.match(icons, /if not entry and reward\.kind == "character" then entry = characterSprite\(reward\) end/);
  assert.match(icons, /if not entry then entry = fallbackSprite\(reward\) end/);
  assert.match(icons, /entry\.overlay:Render\(position\)/);
  assert.match(actor, /Animation Name="RewardPortrait"[\s\S]*?Width="144" Height="144"/);
  assert.match(actor, /Animation Name="RewardPortraitTall"[\s\S]*?Width="144" Height="166"/);
  const renderBody = icons.match(/function RewardIcons\.render[\s\S]*?\nend/)[0];
  assert.doesNotMatch(renderBody, /LoadGraphics|characterSprite/,
    "portrait loading must stay behind the cache rather than run every render call");
});

test("F3 visual menu filters rewards and renders condition-to-reward details", () => {
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(menu, /local FILTERS\s*=\s*{\s*"all",\s*"collectible",\s*"trinket",\s*"card",\s*"character",\s*"monster",\s*"area",\s*"challenge",\s*"pickup",\s*"world",\s*"feature",\s*"other"\s*}/);
  assert.match(menu, /Keyboard\.KEY_TAB/);
  assert.match(menu, /filterIndex/);
  assert.match(menu, /RewardIcons\.render/);
  assert.match(menu, /labels\.completionCondition/);
  assert.match(menu, /labels\.unlockReward/);
  assert.match(menu, /labels\.unconfirmed/);
  assert.match(menu, /local INK = KColor/);
  assert.doesNotMatch(menu, /local WHITE = KColor/);
  assert.match(menu, /local DARK_INK = KColor\(1\.00, 0\.94, 0\.78, 1\)/);
  assert.match(menu, /local INK = KColor\(0\.96, 0\.86, 0\.68, 1\)/);
  assert.match(menu, /local MUTED = KColor\(0\.72, 0\.65, 0\.56, 1\)/);
  assert.match(menu, /local STAMP_INK = KColor\(0\.78, 0\.86, 0\.62, 1\)/);
  assert.match(menu, /local DIMMED_INK = KColor\(0\.62, 0\.60, 0\.58, 1\)/);
  assert.match(menu, /local CONVERTIBLE_INK = KColor\(1\.00, 0\.72, 0\.30, 1\)/);
  assert.doesNotMatch(menu, /local (?:GREEN|BLUE|ACCENT) = KColor/);
  assert.match(menu, /Game\(\):IsPaused\(\)/);
  assert.match(menu, /MC_PRE_PAUSE_SCREEN_RENDER/);
  assert.match(menu, /local PANEL_WIDTH_RATIO = 0\.64/);
  assert.match(menu, /local MIN_PANEL_WIDTH = 270/);
  assert.match(menu, /local MAX_PANEL_WIDTH = 340/);
  assert.match(menu, /local BASE_PANEL_HEIGHT = 250/);
  assert.match(menu, /local SCREEN_VERTICAL_MARGIN = 6/);
  assert.match(menu, /local SCREEN_HORIZONTAL_MARGIN = 12/);
  assert.match(menu, /panelX = math\.floor\(\(screenWidth - panelWidth\) \/ 2\)/);
  assert.match(menu, /panelY = math\.floor\(\(screenHeight - panelHeight\) \/ 2\)/);
  assert.match(menu, /RewardIcons\.renderPaper\(panelX, panelY, panelWidth, panelHeight\)/);
  assert.doesNotMatch(menu, /screenWidth - 122/);
  assert.match(text, /Text\.pixel\(x\)/);
  assert.match(text, /Text\.pixel\(y\)/);
  assert.match(text, /local PIXEL_FONT_SIZES = \{ 11, 22, 33 \}/);
  assert.match(text, /drawWithFont\(pixelFonts\[size\],[\s\S]*?1, color, boxWidth, center\)/,
    "F3 native atlases must render at 1:1 scale");
  assert.doesNotMatch(text, /achievement_lanapixel_(?:8|10|12)/);
  assert.match(menu, /local F3_FONT_PIXELS = \{\s*11,\s*22,\s*33\s*\}/);
  assert.match(menu, /local function fitMenuLayout/);
  assert.match(menu, /maximumPanelHeight/);
  assert.match(menu, /maximumPanelWidth/);
  assert.match(menu, /for panelWidth = basePanelWidth \+ 1, maximumPanelWidth/,
    "layout must exhaust vertical growth before widening");
  assert.match(menu, /for tierIndex = requestedIndex, 1, -1/,
    "requested F3 size must act as an upper bound");
  assert.match(menu, /Text\.lineHeightPixels/);
  assert.match(menu, /Text\.wrapPixels/);
  assert.match(menu, /Text\.drawPixels/);
  assert.match(menu, /maxDetailLines/);
  assert.match(menu, /contentBottom/);
  assert.doesNotMatch(menu, /MENU_FONT_PIXELS|Text\.scaleForPixels\(.*f3/);
  assert.doesNotMatch(menu, /Text\.draw\(Catalog\.text\(selected, language\)\.detail/);
});

test("catalog fuzzy search indexes bilingual copy and reward metadata with scores", () => {
  const goals = read("scripts/data/goals.lua");
  assert.match(goals, /local function normalizeSearch/);
  assert.match(goals, /local function subsequenceScore/);
  assert.match(goals, /goal\.zh\.name/);
  assert.match(goals, /goal\.en\.name/);
  assert.match(goals, /goal\.zh\.detail/);
  assert.match(goals, /goal\.en\.detail/);
  assert.match(goals, /reward\.kind/);
  assert.match(goals, /reward\.id/);
  assert.match(goals, /reward\.enum/);
  assert.match(goals, /function Catalog\.search\(query\)/);
  assert.match(goals, /score\s*=\s*totalScore/);
  assert.match(goals, /table\.sort\(results/);
});

test("F3 search uses slash without Ctrl or F and combines with category filtering", () => {
  const menu = read("scripts/ui/menu.lua");
  const labels = read("scripts/ui/text.lua");
  const readme = read("README.md");
  const evidence = read("docs/testing/f3-fuzzy-search.tdd.md");
  assert.match(menu, /local MAX_SEARCH_LENGTH = 48/);
  assert.match(menu, /query="", searchFocused=false/);
  assert.match(menu, /triggered\(Keyboard\.KEY_SLASH\)/);
  assert.doesNotMatch(menu, /Keyboard\.KEY_LEFT_CONTROL|Keyboard\.KEY_RIGHT_CONTROL/);
  assert.doesNotMatch(menu, /triggered\(Keyboard\.KEY_F\)/);
  for (const document of [labels, readme, evidence]) assert.doesNotMatch(document, /Ctrl\+F/);
  for (const key of ["KEY_A", "KEY_Z", "KEY_0", "KEY_9", "KEY_SPACE", "KEY_BACKSPACE", "KEY_DELETE"]) {
    assert.match(menu, new RegExp(`Keyboard\\.${key}`));
  }
  assert.match(menu, /Catalog\.search\(state\.menu\.query\)/);
  assert.match(menu, /matchesFilter\(goal, filter\)/);
  assert.match(menu, /left\.score ~= right\.score/);
  assert.match(menu, /state\.menu\.query = ""/);
});

test("F3 search renders localized status and suppresses only the typing player's actions", () => {
  const main = read("main.lua");
  const menu = read("scripts/ui/menu.lua");
  const labels = read("scripts/ui/text.lua");
  assert.match(main, /Menu\.shouldBlockInput\(State, entity, inputHook, buttonAction\)/);
  assert.match(main, /InputHook\.GET_ACTION_VALUE/);
  assert.match(menu, /function Menu\.shouldBlockInput/);
  assert.match(menu, /player\.ControllerIndex ~= 0/);
  assert.match(menu, /labels\.searchPrompt/);
  assert.match(menu, /labels\.searchResults/);
  assert.match(menu, /labels\.emptySearch/);
  for (const key of ["searchPrompt", "searchResults", "emptySearch", "controlsSearch"]) {
    assert.equal((labels.match(new RegExp(`${key}\\s*=`, "g")) || []).length, 2,
      `${key} must be localized in Chinese and English`);
  }
});

test("REPENTOGON pause support is conditional and never pauses multiplayer", () => {
  const main = read("main.lua");
  const menu = read("scripts/ui/menu.lua");
  assert.match(main, /ModCallbacks\.MC_PRE_UPDATE/);
  assert.match(main, /if ModCallbacks\.MC_PRE_UPDATE then/);
  assert.match(main, /return true/);
  assert.match(main, /ModCallbacks\.MC_PRE_PAUSE_SCREEN_RENDER/);
  assert.match(main, /onPrePauseScreenRender/);
  assert.match(menu, /ButtonAction\.ACTION_PAUSE/);
  assert.match(menu, /ButtonAction\.ACTION_MAP/);
  assert.match(main, /ModCallbacks\.MC_INPUT_ACTION/);
  assert.match(main, /ModCallbacks\.MC_POST_HUD_RENDER/);
  assert.match(main, /if not ModCallbacks\.MC_POST_HUD_RENDER then\s+Menu\.render\(State\)/);
  assert.match(main, /if not State\.menu\.open then\s+Hud\.render\(State\)\s+Hud\.renderWarning\(State\)\s+end/);
  assert.match(menu, /function Menu\.isMultiplayer/);
  assert.match(menu, /ControllerIndex/);
  assert.match(menu, /pauseUnavailable/);
  assert.match(menu, /multiplayerRealtime/);
});

test("HUD renders every row with the shared native LanaPixel tier", () => {
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.doesNotMatch(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.match(text, /DrawStringScaledUTF8/);
  assert.match(hud, /text\.detail/);
  assert.match(hud, /"- "\s*\.\.\s*text\.name/);
  assert.match(hud, /Routes\.evaluate/);
  assert.match(text, /function Text\.wrapPixels/);
  assert.match(hud, /Text\.wrapPixels/);
  assert.match(hud, /Text\.drawPixels/);
  assert.match(hud, /fontPixels/);
  assert.doesNotMatch(hud, /fontScale|actualScale|factor|,\s*0\.(?:8|85|9)\s*\)/);
});

test("HUD preserves position first, then left-shifts and paginates complete target blocks", () => {
  const hud = read("scripts/ui/hud.lua");
  assert.match(hud, /local SCREEN_MARGIN = 8/);
  assert.match(hud, /local MIN_HUD_WIDTH = 120/);
  assert.match(hud, /local HUD_FONT_PIXELS = \{ 11, 22, 33 \}/);
  assert.match(hud, /local PAGE_ROTATION_FRAMES = 150/);
  assert.match(hud, /local function buildBlocks/);
  assert.match(hud, /local function fitLayout/);
  assert.match(hud, /for tierIndex = requestedIndex, 1, -1/);
  assert.match(hud, /for candidateX = x - 1, SCREEN_MARGIN, -1/);
  assert.match(hud, /local function paginateBlocks/);
  assert.match(hud, /local function lineAdvance/);
  assert.match(hud, /local function contentHeight/);
  assert.match(hud, /local function maximumLineCount/);
  assert.match(hud, /lineSpacingPixels/);
  assert.match(hud, /tostring\(layout\.lineSpacingPixels\)/,
    "changing line spacing must reset automatic page rotation");
  assert.match(hud, /pagedLayout\(state, SCREEN_MARGIN, screenWidth,\s*availableHeight, lineSpacingPixels\)/,
    "pagination must start only after the 11px HUD has expanded to the full safe width");
  assert.match(hud, /layoutSignature/);
  assert.match(hud, /Isaac\.GetFrameCount\(\)[\s\S]*?PAGE_ROTATION_FRAMES/);
  assert.match(hud, /screenHeight - SCREEN_MARGIN - totalHeight/);
  assert.match(hud, /Text\.wrapPixels/);
  assert.match(hud, /Text\.pixel/);
  assert.doesNotMatch(hud, /Text\.scaleForPixels|for pixelSize = requestedPixels/);
});

test("HUD uses the ivory palette while retaining bright completion and failure states", () => {
  const hud = read("scripts/ui/hud.lua");
  assert.match(hud, /local HUD_TITLE = KColor\(1\.00, 0\.94, 0\.78, 1\)/);
  assert.match(hud, /local HUD_BODY = KColor\(0\.96, 0\.86, 0\.68, 1\)/);
  assert.match(hud, /local HUD_MUTED = KColor\(0\.72, 0\.65, 0\.56, 1\)/);
  assert.match(hud, /local HUD_COMPLETED = KColor\(0\.60, 1\.00, 0\.65, 1\)/);
  assert.match(hud, /local HUD_FAILED = KColor\(1\.00, 0\.38, 0\.34, 1\)/);
  assert.match(hud, /or HUD_BODY/);
  assert.match(hud, /HUD_FAILED, language/);
});

test("renderer always uses native 11/22/33px LanaPixel atlases at 1:1", () => {
  const text = read("scripts/ui/text.lua");
  assert.doesNotMatch(text, /bundledFont|FONT_NATIVE_PIXELS|scaleForPixels|snapScale/);
  assert.match(text, /achievement_lanapixel_" \..*pixelSize/);
  assert.match(text, /drawWithFont\(pixelFonts\[size\],[\s\S]*?1, color/);
  assert.doesNotMatch(text, /terminus8|achievement_zh|fallback|IsLoaded/);
  assert.match(text, /function Text\.resolveLanguage/);
});

test("Chinese rendering is self-contained and does not reference EID", () => {
  const text = read("scripts/ui/text.lua");
  const fontPath = path.join(root, "resources/font/achievement_lanapixel_11.fnt");
  const licensePath = path.join(root, "resources/font/LANAPIXEL_OFL.txt");
  assert.doesNotMatch(text, /external item descriptions/i);
  assert.match(text, /resources\/font\/achievement_lanapixel_/);
  assert.match(text, /GetCurrentModPath/);
  assert.equal(fs.existsSync(fontPath), true, "bundled Chinese .fnt must exist");
  assert.equal(fs.existsSync(licensePath), true, "font license must ship with the mod");
  const pages = fs.readdirSync(path.join(root, "resources/font"))
    .filter((file) => /^achievement_lanapixel_(?:11|22|33)_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "font must include at least one texture page");
});

test("bundled LanaPixel assets are complete", () => {
  const text = read("scripts/ui/text.lua");
  const fontDir = path.join(root, "resources/font");
  assert.match(text, /resources\/font\/achievement_lanapixel_/);
  assert.doesNotMatch(text, /resources\/font\/achievement_zh\.fnt/);
  assert.equal(fs.existsSync(path.join(fontDir, "achievement_lanapixel.fnt")), false);
  for (const pixels of [11, 22, 33])
    assert.equal(fs.existsSync(path.join(fontDir, `achievement_lanapixel_${pixels}.fnt`)), true);
  assert.equal(fs.existsSync(path.join(fontDir, "LANAPIXEL_OFL.txt")), true);
  const pages = fs.readdirSync(fontDir)
    .filter((file) => /^achievement_lanapixel_(?:11|22|33)_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "LanaPixel font must include a texture page");
});

test("Mod Config Menu exposes HUD line spacing beside native font and position settings", () => {
  const mcm = read("scripts/integrations/mcm.lua");
  assert.match(mcm, /Language/);
  assert.match(mcm, /HUD font size \/ HUD 字体大小/);
  assert.match(mcm, /F3 font size \/ F3 字体大小/);
  assert.match(mcm, /state\.settings\.hud\.fontPixels/);
  assert.match(mcm, /state\.settings\.f3\.fontPixels/);
  assert.match(mcm, /\[1\]=11,\s*\[2\]=22,\s*\[3\]=33/);
  assert.match(mcm, /Small \/ 小/);
  assert.match(mcm, /Standard \/ 标准/);
  assert.match(mcm, /Large \/ 大/);
  assert.match(mcm, /local function addFontSize/);
  assert.match(mcm, /return label \.\. ": " \.\. fontName/,
    "the selectable HUD/F3 rows must display names instead of numeric tier indexes");
  assert.doesNotMatch(mcm, /return "(?:HUD|F3): " \.\. fontName/,
    "font names should not be duplicated on separate read-only rows");
  assert.doesNotMatch(mcm, /tostring\(pixels\).*px/);
  assert.match(mcm, /HUD line spacing \/ HUD 行间距/);
  assert.match(mcm, /state\.settings\.hud\.lineSpacingPixels/);
  assert.match(mcm, /0,\s*8,\s*1,\s*"px"/);
  assert.match(mcm, /HUD X/);
  assert.match(mcm, /HUD Y/);
  assert.match(mcm, /Minimum/);
  assert.match(mcm, /Maximum/);
  assert.match(mcm, /ModifyBy/);
});

test("persistent settings are loaded defensively and saved as JSON", () => {
  const storage = read("scripts/core/storage.lua");
  assert.match(storage, /mod:HasData\(\)/);
  assert.match(storage, /json\.decode/);
  assert.match(storage, /json\.encode/);
  assert.match(storage, /schemaVersion/);
  assert.match(storage, /activeRun/);
  assert.doesNotMatch(storage, /data\.hud\.fontScale\s*=/);
  assert.match(storage, /fontPixels/);
  assert.match(storage, /lineSpacingPixels/);
});

test("failed run state survives quitting and is restored only for the same run", () => {
  const main = read("main.lua");
  const sensors = read("scripts/core/sensors.lua");
  assert.match(main, /GetStartSeed\(\)/);
  assert.match(main, /sameSavedRun/);
  assert.match(main, /function AchievementTracker:onExit\(shouldSave\)[\s\S]*?save\(\)/);
  assert.match(main, /State\.lastEvaluation = -1/);
  assert.match(sensors, /function Sensors\.newRun\(startSeed\)/);
});

test("vanilla unlock inference uses reward availability and sorts untracked completed goals last", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const menu = read("scripts/ui/menu.lua");
  const achievements = read("scripts/data/achievements_301_400.lua");
  assert.match(unlocks, /IsAvailable/);
  assert.match(unlocks, /pcall\(rewardAvailable/);
  assert.match(achievements, /a\(326,[^\n]+reward\("card",28\)/);
  assert.match(achievements, /a\(361,[^\n]+reward\("card",52\)/);
  assert.match(achievements, /a\(386,[^\n]+reward\("collectible",538\)/);
  assert.match(menu, /local tracked, currentPending, convertiblePending, otherCharacterPending, unavailable, completed/);
  assert.match(menu, /state\.profileCompleted/);
});

test("character, boss, and stage observations persist as completion evidence", () => {
  const batch = read("scripts/data/achievements_1_50.lua");
  const unlocks = read("scripts/core/unlocks.lua");
  const storage = read("scripts/core/storage.lua");
  const main = read("main.lua");
  assert.match(batch, /achievement_1=\{kind="player"/);
  assert.match(batch, /achievement_4=\{kind="stage"/);
  assert.match(batch, /achievement_34=\{kind="boss"/);
  assert.match(unlocks, /function Unlocks\.observe/);
  assert.match(storage, /observedCompleted/);
  for (const callback of ["MC_POST_PLAYER_INIT", "MC_POST_NEW_LEVEL", "MC_POST_NPC_DEATH"]) {
    assert.match(main, new RegExp(callback));
  }
});

test("completion-mark routes are parsed, persisted, and evaluated from live context", () => {
  const goals = read("scripts/data/goals.lua");
  const marks = read("scripts/core/completion_marks.lua");
  const routes = read("scripts/core/routes.lua");
  const main = read("main.lua");
  const hud = read("scripts/ui/hud.lua");

  assert.match(goals, /CompletionMarks\.attach\(goals\)/);
  for (const mark of ["MOMS_HEART", "ISAAC", "SATAN", "BOSS_RUSH", "BLUE_BABY", "LAMB",
    "MEGA_SATAN", "ULTRA_GREED", "HUSH", "DELIRIUM", "MOTHER", "BEAST"]) {
    assert.match(marks, new RegExp(`"${mark}"`));
  }
  assert.match(marks, /goal\.completionRequirements\s*=\s*result/);
  assert.match(marks, /function CompletionMarks\.syncRepentogon/);
  assert.match(marks, /Isaac\.GetCompletionMarks/);
  assert.match(marks, /function CompletionMarks\.infer/);
  assert.match(routes, /function Routes\.context/);
  assert.match(routes, /function Routes\.evaluate/);
  assert.match(routes, /Knife Piece 1/);
  assert.match(routes, /Dad's Note/);
  assert.match(routes, /Strange Key/);
  assert.match(routes, /Broken Shovel/);
  assert.match(routes, /context\.aids\[key\]/);
  assert.match(routes, /context\.ascent/);
  assert.match(routes, /mausoleumMomDefeated/);
  assert.match(routes, /fleshHeartDefeated/);
  assert.match(routes, /STAGE\.CHAPTER5 and context\.stageType == WOTL/,
    "Cathedral must use the WOTL stage type");
  assert.match(routes, /STAGE\.CHAPTER5 and context\.stageType == ORIGINAL/,
    "Sheol must use the original stage type");
  assert.match(main, /Routes\.resetAttempt/);
  assert.match(main, /Routes\.observeNpc/);
  assert.match(main, /CompletionMarks\.merge/);
  assert.match(main, /AchievementUnlocksDisallowed/);
  assert.match(hud, /HUD_WARNING/);
  assert.match(hud, /route\.known, route\.required/);
});

test("Boss Rush completion uses the persistent game-state flag across room and floor transitions", () => {
  const main = read("main.lua");
  assert.match(main, /GameInstance:GetStateFlag\(GameStateFlag\.STATE_BOSSRUSH_DONE\)/);
  assert.match(main, /Isaac\.GetChallenge\(\)/);
  assert.doesNotMatch(main, /GameInstance:GetChallenge\(\)/);
  assert.match(main, /function AchievementTracker:onNewRoom\(\)[\s\S]*?syncBossRushCompletion\(\)/);
  assert.match(main, /function AchievementTracker:onNewLevel\(\)[\s\S]*?syncBossRushCompletion\(\)/);
  assert.match(main, /MC_POST_NEW_ROOM/);
});

test("Chest and Dark Room routes prompt for the correct photo after Mom dies", () => {
  const routes = read("scripts/core/routes.lua");
  assert.match(routes, /heldAids=\{\}/);
  assert.match(routes, /run\.routeEvents\.momDefeated = true/);
  assert.match(routes, /context\.routeEvents\.momDefeated and not heldAids\.polaroid/);
  assert.match(routes, /Mom 已击败：拾取全家福。/);
  assert.match(routes, /context\.routeEvents\.momDefeated and not heldAids\.negative/);
  assert.match(routes, /Mom 已击败：拾取底片。/);
});

test("dynamic boss routes provide concrete bilingual exits for every main-path floor", () => {
  const routes = read("scripts/core/routes.lua");
  for (const text of [
    "地下室II/下水道I", "洞穴I/下水道II", "下水道II：进入洞穴II/矿层I",
    "洞穴II/矿层I", "深牢I/矿层II", "深牢II/陵墓I", "陵墓I：进入陵墓II",
    "深牢II：进入子宫I", "陵墓II", "子宫I：进入子宫II",
    "Basement II or Downpour I", "Caves I or Downpour II",
    "Downpour II: enter Caves II/Mines I", "Depths I or Mines II",
    "Depths II or Mausoleum I", "Womb I: enter Womb II"
  ]) {
    assert.match(routes, new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
  assert.doesNotMatch(routes, /沿主线(?:推进|前往)|Follow the main path/);
  assert.match(routes, /persistentData:Unlocked\(407\)/);
  assert.match(routes, /context\.secretExitUnlocked == false/,
    "unknown unlock state must continue to expose possible alternate exits");
  assert.match(routes, /policy == "main"/);
  assert.match(routes, /policy == "alternate"/);
});

test("special routes compose floor exits without losing constraints or Greed progression", () => {
  const routes = read("scripts/core/routes.lua");
  assert.match(routes, /pathResult\(context,[\s\S]*?"main"\)/,
    "Beast must force the last transition into normal Depths II");
  assert.match(routes, /context\.elapsed >= 1200 and "alternate"/,
    "late Boss Rush runs must force the Mausoleum branch at the final fork");
  assert.match(routes, /保持30分钟时限。/);
  assert.match(routes, /优先进入天使房，炸毁雕像并收集两枚钥匙碎片。/);
  for (const floor of ["进入洞穴", "进入深牢", "进入子宫", "进入阴间", "进入商店层", "进入究极贪婪层"]) {
    assert.match(routes, new RegExp(floor));
  }
  assert.match(routes, /isRepentanceFloor\(context\) and context\.stage >= STAGE\.WOMB1/,
    "Corpse must not be treated as a route to Blue Womb");
});

test("challenge runs show only their unlock while F3 marks challenge-only unlocks unavailable elsewhere", () => {
  const goals = read("scripts/data/goals.lua");
  const hud = read("scripts/ui/hud.lua");
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(goals, /local CHALLENGE_ACHIEVEMENT_IDS = \{/);
  assert.match(goals, /goal\.challengeId = challengeId/);
  assert.match(goals, /function Catalog\.challengeGoal/);
  assert.match(goals, /function Catalog\.isCompletable/);
  assert.match(hud, /local challengeId = Isaac\.GetChallenge\(\)/);
  assert.match(hud, /Catalog\.challengeGoal\(challengeId\)/);
  assert.match(hud, /trackedIds = challengeGoal and \{ challengeGoal\.id \} or \{\}/);
  assert.match(menu, /Catalog\.isCompletable\(goal, Isaac\.GetChallenge\(\)\)/);
  assert.match(menu, /not completable and labels\.unavailable/);
  assert.match(text, /unavailable\s*=\s*"不可完成"/);
});

test("character relevance normalizes paired and transformed PlayerType variants", () => {
  const relevance = read("scripts/core/character_relevance.lua");
  for (const [variant, base] of [[11, 8], [12, 3], [17, 16], [20, 19], [38, 29], [39, 37], [40, 35]]) {
    assert.match(relevance, new RegExp(`\\[${variant}\\]\\s*=\\s*${base}\\b`));
  }
  for (const [constant, fallback] of [
    ["PLAYER_LAZARUS2", 11], ["PLAYER_BLACKJUDAS", 12], ["PLAYER_THESOUL", 17],
    ["PLAYER_ESAU", 20], ["PLAYER_LAZARUS2_B", 38], ["PLAYER_JACOB2_B", 39],
    ["PLAYER_THESOUL_B", 40]
  ]) {
    assert.match(relevance, new RegExp(`playerType\\("${constant}",\\s*${fallback}\\)`));
  }
  assert.match(relevance, /function CharacterRelevance\.normalize/);
});

test("character relevance only dims exclusive character completion goals", () => {
  const relevance = read("scripts/core/character_relevance.lua");
  assert.match(relevance, /goal\.en\.detail/);
  assert.match(relevance, /function CharacterRelevance\.requiredPlayerTypes/);
  assert.match(relevance, /function CharacterRelevance\.requiredPlayerType/);
  assert.match(relevance, /function CharacterRelevance\.isRelevant/);
  assert.match(relevance, /game:GetNumPlayers\(\)/);
  assert.match(relevance, /Isaac\.GetPlayer\(index\)/);
  assert.match(relevance, /player:GetPlayerType\(\)/);
  assert.match(relevance, /string\.find\(detail, suffix, searchFrom, true\)/);
  assert.match(relevance, /tail:match\("\^%s\*%\.\?%s\*\$"\)/);
  assert.match(relevance, /hasGeneralAlternative/);
  const requirementParser = relevance.match(/function CharacterRelevance\.requiredPlayerTypes[\s\S]*?\nend\n\nfunction CharacterRelevance\.requiredPlayerType/)[0];
  assert.doesNotMatch(requirementParser, /goal\.observation/,
    "unlock-character observations must not be mistaken for character requirements");
});

test("character relevance overrides malformed merged catalog conditions", () => {
  const relevance = read("scripts/core/character_relevance.lua");
  const early = read("scripts/data/achievements_101_200.lua");
  const later = read("scripts/data/achievements_201_300.lua");
  const cases = [
    ["achievement_172", 8],
    ["achievement_173", 7]
  ];
  for (const [id, playerType] of cases) {
    assert.match(relevance, new RegExp(`${id}\\s*=\\s*\\{\\s*\\[${playerType}\\]\\s*=\\s*true\\s*\\}`));
  }
  assert.match(relevance, /achievement_270\s*=\s*\{\}/);
  assert.match(early, /a\(172,[^\n]+as Azazel[^\n]+as Lazarus/);
  assert.match(early, /a\(173,[^\n]+as Lazarus[^\n]+as Azazel/);
  assert.match(later, /a\(270,[^\n]+as Isaac Defeat Mega Satan/);
});

test("F3 tracking mode ranks completable goals before unavailable challenges and completed goals", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /require\("scripts\.core\.character_relevance"\)/);
  assert.match(menu, /local tracked, currentPending, convertiblePending, otherCharacterPending, unavailable, completed/);
  assert.match(menu, /Tracker\.contains\(state\.tracker, goal\.id\)/);
  assert.match(menu, /Tracker\.contains\(state\.tracker, goal\.id\) and \(completedGoal or completable\)/,
    "tracking must not promote an unfinished unavailable challenge");
  assert.match(menu, /elseif not completedGoal and not completable then[\s\S]*?bucket, priorityRank = unavailable, 5/);
  assert.match(menu, /CharacterRelevance\.classify\(goal, context\)/);
  assert.match(menu, /for _, bucket in ipairs\(\{ tracked, currentPending, convertiblePending, otherCharacterPending, unavailable, completed \}\)/);
  assert.match(menu, /if left\.priorityRank ~= right\.priorityRank then[\s\S]*?left\.priorityRank < right\.priorityRank/,
    "availability priority must outrank fuzzy-search score");
  assert.match(menu, /if left\.score ~= right\.score then return left\.score < right\.score end/);
  assert.match(menu, /trackedOrder\[goal\.id\]/,
    "the non-search tracked group must retain the HUD tracking order");
  assert.match(menu, /local dimmed = not completed and relevance == "other"/);
  assert.match(menu, /local DIMMED_INK = KColor/);
  assert.match(menu, /local DIMMED_TINT = Color/);
  assert.match(menu, /RewardIcons\.render\(reward,[^\n]+dimmed and DIMMED_TINT/);
  assert.match(menu, /Tracker\.toggle/,
    "other-character goals must remain selectable and trackable");
});

test("character context includes every supported transformation source", () => {
  const relevance = read("scripts/core/character_relevance.lua");
  for (const [constant, fallback] of [
    ["COLLECTIBLE_ANKH", 161], ["COLLECTIBLE_JUDAS_SHADOW", 311],
    ["COLLECTIBLE_LAZARUS_RAGS", 332], ["COLLECTIBLE_CLICKER", 482]
  ]) {
    assert.match(relevance, new RegExp(`collectibleType\\("${constant}",\\s*${fallback}\\)`));
  }
  for (const [constant, fallback] of [
    ["TRINKET_BROKEN_ANKH", 28], ["TRINKET_MISSING_POSTER", 23]
  ]) {
    assert.match(relevance, new RegExp(`trinketType\\("${constant}",\\s*${fallback}\\)`));
  }
  assert.match(relevance, /player:HasCollectible\(source\.id\)/);
  assert.match(relevance, /player:HasTrinket\(source\.id\)/,
    "HasTrinket must include held and gulped/smelted trinkets");
  for (const target of [
    "PLAYER_XXX", "PLAYER_JUDAS", "PLAYER_LAZARUS", "PLAYER_THELOST"
  ]) {
    assert.match(relevance, new RegExp(`playerType\\("${target}"`));
  }
  assert.doesNotMatch(relevance, /COLLECTIBLE_ESAU_JR/);
});

test("character context models Clicker pools, unlock filtering, chains, and multiplayer", () => {
  const relevance = read("scripts/core/character_relevance.lua");
  assert.match(relevance, /local NORMAL_CLICKER_TYPES\s*=/);
  assert.match(relevance, /local TAINTED_CLICKER_TYPES\s*=/);
  assert.match(relevance, /function CharacterRelevance\.buildContext\(game, goals\)/);
  assert.match(relevance, /game:GetNumPlayers\(\)/);
  assert.match(relevance, /Isaac\.GetPlayer\(index\)/);
  assert.match(relevance, /goal\.observation\.kind == "player"/);
  assert.match(relevance, /Isaac\.GetPersistentGameData/);
  assert.match(relevance, /persistentData:Unlocked\(achievementId\)/);
  assert.match(relevance, /if not persistentData[\s\S]*?or isCharacterUnlocked/,
    "REPENTOGON filters the Clicker pool through achievement unlock metadata");
  assert.match(relevance, /if not persistentData/,
    "vanilla falls back to the complete same-alignment Clicker pool");
  assert.match(relevance, /while queueIndex <= #reachable/,
    "fixed transformations and Clicker must be closed over as a conversion chain");
  assert.match(relevance, /context\.current/);
  assert.match(relevance, /context\.convertible/);
  assert.match(relevance, /context\.signature/);
});

test("F3 distinguishes convertible goals and refreshes them without moving the selected goal", () => {
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(menu, /local CONVERTIBLE_INK = KColor/);
  assert.match(menu, /local CONVERTIBLE_TINT = Color/);
  assert.match(menu, /relevance == "convertible"/);
  assert.match(menu, /and "~"/);
  assert.match(menu, /labels\.availableAfterTransformation/);
  assert.match(menu, /state\.menu\.relevanceSignature ~= context\.signature/);
  assert.match(menu, /local function completedSignature\(state\)[\s\S]*?isCompleted\(state, goal\)/);
  assert.match(menu, /state\.menu\.completionSignature = completedSignature\(state\)/);
  assert.match(menu, /state\.menu\.completionSignature ~= completionSignature/);
  assert.match(menu, /local selectedGoalId = preserveSelection[\s\S]*?\.id/);
  assert.match(menu, /if goal\.id == selectedGoalId then[\s\S]*?state\.menu\.cursor = index/);
  assert.match(menu, /state\.menu\.offset = math\.floor\(\(state\.menu\.cursor - 1\) \/ layout\.pageSize\) \* layout\.pageSize \+ 1/);
  assert.match(text, /availableAfterTransformation\s*=\s*"转换后可完成"/);
  assert.match(text, /availableAfterTransformation\s*=\s*"available after transformation"/);
});
