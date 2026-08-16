const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("mod has valid entry metadata and registers gameplay callbacks", () => {
  const metadata = read("metadata.xml");
  const main = read("main.lua");
  assert.match(metadata, /<name>Achievement Tracker<\/name>/);
  assert.match(main, /RegisterMod\("Achievement Tracker", 1\)/);
  for (const callback of ["MC_POST_GAME_STARTED", "MC_POST_UPDATE", "MC_POST_RENDER", "MC_POST_PICKUP_UPDATE", "MC_PRE_GAME_EXIT"]) {
    assert.match(main, new RegExp(callback));
  }
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
  assert.match(menu, /PAGE_SIZE = COLUMNS \* ROWS/);
  assert.match(menu, /Keyboard\.KEY_LEFT/);
  assert.match(menu, /Keyboard\.KEY_RIGHT/);
  assert.match(menu, /column \* columnWidth/);
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
  for (const kind of ["collectible", "trinket", "card", "character", "area", "challenge", "feature", "other"]) {
    assert.match(rewards, new RegExp(`\\b${kind}\\b`));
  }
  assert.doesNotMatch(unlocks, /local rewards\s*=\s*{/);
  assert.match(unlocks, /Rewards\.config/);
  assert.match(goals, /trackingMetadata/);
  assert.match(goals, /goal\.reward\s*=\s*Rewards\.display\(goal\)/);
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
  assert.match(rewards, /return \{ kind=kind, id=id \}/);
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
  assert.match(icons, /if reward\.kind == "character" then entry = characterSprite\(reward\) end/);
  assert.match(icons, /if not entry then entry = fallbackSprite\(reward\) end/);
  assert.match(icons, /entry\.overlay:Render\(Vector\(x, y\)\)/);
  assert.match(actor, /Animation Name="RewardPortrait"[\s\S]*?Width="144" Height="144"/);
  assert.match(actor, /Animation Name="RewardPortraitTall"[\s\S]*?Width="144" Height="166"/);
  const renderBody = icons.match(/function RewardIcons\.render[\s\S]*?\nend/)[0];
  assert.doesNotMatch(renderBody, /LoadGraphics|characterSprite/,
    "portrait loading must stay behind the cache rather than run every render call");
});

test("F3 visual menu filters rewards and renders condition-to-reward details", () => {
  const menu = read("scripts/ui/menu.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(menu, /local FILTERS\s*=\s*{\s*"all",\s*"collectible",\s*"trinket",\s*"card",\s*"other"\s*}/);
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
  assert.match(menu, /panelX = math\.floor\(\(screenWidth - panelWidth\) \/ 2\)/);
  assert.match(menu, /panelY = math\.floor\(\(screenHeight - panelHeight\) \/ 2\)/);
  assert.match(menu, /RewardIcons\.renderPaper\(panelX, panelY, panelWidth, panelHeight\)/);
  assert.doesNotMatch(menu, /screenWidth - 122/);
  assert.match(text, /function Text\.width/);
  assert.match(text, /function Text\.ellipsize/);
  assert.match(text, /local FONT_NATIVE_PIXELS = 16/);
  assert.match(text, /function Text\.scaleForPixels/);
  assert.match(text, /function Text\.snapScale/);
  assert.match(text, /Text\.pixel\(x\)/);
  assert.match(text, /Text\.pixel\(y\)/);
  assert.match(menu, /local MENU_MIN_BODY_PIXELS = 8/);
  assert.match(menu, /local MENU_MAX_BODY_PIXELS = 11/);
  assert.match(menu, /title=Text\.scaleForPixels\(bodyPixels \+ 1\)/);
  assert.match(menu, /body=Text\.scaleForPixels\(bodyPixels\)/);
  assert.match(menu, /label=Text\.scaleForPixels\(math\.max\(8, bodyPixels - 1\)\)/);
  assert.match(menu, /small=Text\.scaleForPixels\(math\.max\(7, bodyPixels - 2\)\)/);
  assert.doesNotMatch(menu, /menuScale \* 0\.(?:64|68|72|76|82|84|88|9)/);
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

test("HUD renders localized completion conditions with a scalable Unicode font", () => {
  const hud = read("scripts/ui/hud.lua");
  const text = read("scripts/ui/text.lua");
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.match(text, /DrawStringScaledUTF8/);
  assert.match(hud, /text\.detail/);
  assert.doesNotMatch(hud, /"- "\s*\.\.\s*text\.name/);
  assert.match(hud, /fontScale/);
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

test("renderer always uses the bundled LanaPixel font without fallbacks", () => {
  const text = read("scripts/ui/text.lua");
  assert.match(text, /bundledFont:Load\(modPath \..*achievement_lanapixel\.fnt/);
  assert.match(text, /bundledFont:DrawStringScaledUTF8/);
  assert.doesNotMatch(text, /terminus8|achievement_zh|fallback|IsLoaded/);
  assert.match(text, /function Text\.resolveLanguage/);
});

test("Chinese rendering is self-contained and does not reference EID", () => {
  const text = read("scripts/ui/text.lua");
  const fontPath = path.join(root, "resources/font/achievement_lanapixel.fnt");
  const licensePath = path.join(root, "resources/font/LANAPIXEL_OFL.txt");
  assert.doesNotMatch(text, /external item descriptions/i);
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.match(text, /GetCurrentModPath/);
  assert.equal(fs.existsSync(fontPath), true, "bundled Chinese .fnt must exist");
  assert.equal(fs.existsSync(licensePath), true, "font license must ship with the mod");
  const pages = fs.readdirSync(path.join(root, "resources/font")).filter((file) => /^achievement_lanapixel_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "font must include at least one texture page");
});

test("bundled LanaPixel assets are complete", () => {
  const text = read("scripts/ui/text.lua");
  const fontDir = path.join(root, "resources/font");
  assert.match(text, /resources\/font\/achievement_lanapixel\.fnt/);
  assert.doesNotMatch(text, /resources\/font\/achievement_zh\.fnt/);
  assert.equal(fs.existsSync(path.join(fontDir, "achievement_lanapixel.fnt")), true);
  assert.equal(fs.existsSync(path.join(fontDir, "LANAPIXEL_OFL.txt")), true);
  const pages = fs.readdirSync(fontDir).filter((file) => /^achievement_lanapixel_\d+\.png$/.test(file));
  assert.ok(pages.length > 0, "LanaPixel font must include a texture page");
});

test("Mod Config Menu exposes language, font scale, and X/Y position settings", () => {
  const mcm = read("scripts/integrations/mcm.lua");
  assert.match(mcm, /Language/);
  assert.match(mcm, /Font size/);
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
  assert.match(storage, /fontScale/);
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

test("vanilla unlock inference uses reward availability and sorts completed goals last", () => {
  const unlocks = read("scripts/core/unlocks.lua");
  const menu = read("scripts/ui/menu.lua");
  const achievements = read("scripts/data/achievements_301_400.lua");
  assert.match(unlocks, /IsAvailable/);
  assert.match(unlocks, /pcall\(rewardAvailable/);
  assert.match(achievements, /a\(326,[^\n]+reward\("card",28\)/);
  assert.match(achievements, /a\(361,[^\n]+reward\("card",52\)/);
  assert.match(achievements, /a\(386,[^\n]+reward\("collectible",538\)/);
  assert.match(menu, /local currentPending, convertiblePending, otherCharacterPending, completed/);
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
  for (const callback of ["MC_POST_PLAYER_INIT", "MC_POST_NEW_LEVEL", "MC_POST_NPC_INIT"]) {
    assert.match(main, new RegExp(callback));
  }
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

test("F3 tracking mode ranks current-character goals and dims other-character goals", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /require\("scripts\.core\.character_relevance"\)/);
  assert.match(menu, /local currentPending, convertiblePending, otherCharacterPending, completed/);
  assert.match(menu, /CharacterRelevance\.classify\(goal, context\)/);
  assert.match(menu, /for _, bucket in ipairs\(\{ currentPending, convertiblePending, otherCharacterPending, completed \}\)/);
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
  assert.match(menu, /state\.menu\.offset = math\.floor\(\(state\.menu\.cursor - 1\) \/ PAGE_SIZE\) \* PAGE_SIZE \+ 1/);
  assert.match(text, /availableAfterTransformation\s*=\s*"转换后可完成"/);
  assert.match(text, /availableAfterTransformation\s*=\s*"available after transformation"/);
});
