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

test("F3 ranks route choices, tracked goals, scene opportunities, and existing buckets in that order", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /local tracked, routeEntries, scenePending, currentCharacterPending/);
  assert.match(menu, /sceneGoalIds/);
  assert.match(menu, /bucket, priorityRank = scenePending, 2/);
  assert.match(menu, /bucket, priorityRank = currentCharacterPending, 3/);
  assert.match(menu, /\{ routeEntries, tracked, scenePending, currentCharacterPending, convertiblePending,/);
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

test("second-batch copy remains centralized and bilingual action copy keeps its prefixes", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const copy = opportunities.match(/local COPY\s*=\s*\{([\s\S]*?)\n\}/)?.[1] ?? "";
  const requiredKeys = [
    "bandageGirl", "meatBoy", "angelStatue", "angelFight", "keyPiece",
    "shopSpend", "goldenRazor", "bed", "victoryLap", "lilSpewer",
  ];
  for (const key of requiredKeys) {
    assert.match(copy, new RegExp(`\\b${key}\\s*=\\s*message\\(`), `missing COPY.${key}`);
  }

  const messages = [...copy.matchAll(/message\("([^"]+)",\s*"([^"]+)"\)/g)];
  assert.ok(messages.length >= 24, "first- and second-batch action copy must stay in COPY");
  for (const [, zh, en] of messages) {
    assert.match(zh, /^尝试/, `Chinese opportunity must start with 尝试: ${zh}`);
    assert.match(en, /^Try\b/, `English opportunity must start with Try: ${en}`);
  }
});

test("Golden Razor records 99 coins for the current attempt, withdraws at zero, and resets on R Key", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const main = read("main.lua");

  assert.match(opportunities, /goldenRazorReached99/);
  assert.match(opportunities, /GetNumCoins\(\)\s*>=\s*99[\s\S]*?goldenRazorReached99\s*=\s*true/,
    "the run marker must be captured before the player's balance falls");
  assert.match(opportunities, /goldenRazorReached99[\s\S]*?GetNumCoins\(\)\s*>\s*0[\s\S]*?achievement_583/,
    "the opportunity is actionable only after 99 and before reaching zero");
  assert.match(opportunities, /GetNumCoins\(\)\s*==\s*0[\s\S]*?goldenRazorReached99\s*=\s*nil/,
    "the prompt and marker must be withdrawn once the balance reaches zero");
  assert.match(opportunities, /COLLECTIBLE_R_KEY/);
  assert.match(opportunities, /function Opportunities\.onUseItem[\s\S]*?COLLECTIBLE_R_KEY[\s\S]*?goldenRazorReached99\s*=\s*nil/);
  assert.match(main, /MC_USE_ITEM/);
  assert.match(main, /Opportunities\.onUseItem\(/);
  assert.ok(main.indexOf("Opportunities.updateRun(State.run, GameInstance)")
    < main.indexOf("if second == State.lastEvaluation then return end"),
  "the 99-coin marker must be sampled every frame, not only once per second");
});

test("angel-room opportunity follows statue, live angel, and dropped key-piece phases for both goals", () => {
  const opportunities = read("scripts/core/opportunities.lua");

  for (const token of [
    "ROOM_ANGEL", "ENTITY_URIEL", "ENTITY_GABRIEL",
    "COLLECTIBLE_KEY_PIECE_1", "COLLECTIBLE_KEY_PIECE_2",
  ]) {
    assert.match(opportunities, new RegExp(`\\b${token}\\b`), `missing angel phase token ${token}`);
  }
  assert.match(opportunities, /local function addAngelRoom[\s\S]*?COPY\.keyPiece[\s\S]*?COPY\.angelFight[\s\S]*?COPY\.angelStatue/,
    "the furthest actionable phase must win when entity snapshots overlap");
  assert.match(opportunities, /achievement_58/);
  assert.match(opportunities, /achievement_370/);
  assert.match(opportunities, /addPairedGoals\([\s\S]*?achievement_58[\s\S]*?achievement_370/,
    "Dad's Key and Filigree Feather must both be promoted without duplicate HUD copy");
  assert.match(opportunities, /HasGoldenBomb\(\)/,
    "a golden bomb is sufficient to make the intact statue actionable");
});

test("bed opportunities pair first-use and ten-use goals from the same bed encounter", () => {
  const opportunities = read("scripts/core/opportunities.lua");

  assert.match(opportunities, /BED/);
  assert.match(opportunities, /local function (?:addBed|findUsableBed)/,
    "bed detection should be isolated because vanilla exposes it as a special pickup");
  assert.match(opportunities, /addPairedGoals\([\s\S]*?achievement_359[\s\S]*?achievement_385/,
    "Wooden Cross and Blanket must share the bed opportunity");
  assert.match(opportunities, /not completed\(profileCompleted, "achievement_359"\)/);
  assert.match(opportunities, /not completed\(profileCompleted, "achievement_385"\)/);
});

test("level-three familiar opportunities require a matching pedestal or a usable Potato Peeler", () => {
  const opportunities = read("scripts/core/opportunities.lua");

  for (const token of [
    "FAMILIAR_BANDAGE_GIRL", "FAMILIAR_MEATBOY", "COLLECTIBLE_BALL_OF_BANDAGES",
    "COLLECTIBLE_CUBE_OF_MEAT", "COLLECTIBLE_POTATO_PEELER",
  ]) {
    assert.match(opportunities, new RegExp(`\\b${token}\\b`), `missing familiar opportunity token ${token}`);
  }
  assert.match(opportunities, /local function addSuperFamiliar[\s\S]*?SubType\s*==\s*COLLECTIBLE_BALL_OF_BANDAGES[\s\S]*?achievement_19/);
  assert.match(opportunities, /local function addSuperFamiliar[\s\S]*?SubType\s*==\s*COLLECTIBLE_CUBE_OF_MEAT[\s\S]*?achievement_144/);
  assert.match(opportunities, /COLLECTIBLE_POTATO_PEELER[\s\S]*?GetMaxHearts\(\)\s*>=\s*2/,
    "Potato Peeler is only actionable when a red-heart container can be spent");
  assert.match(opportunities, /GetCollectibleEffectNum\(collectible\)/,
    "Potato Peeler's persistent Cube of Meat effects must count toward level three");
});

test("victory-lap exception is narrow and maps the current Lamb choice to one milestone", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const main = read("main.lua");

  assert.match(opportunities, /local function victoryLapGoalId/);
  assert.match(opportunities, /\[0\]\s*=\s*"achievement_321"/);
  assert.match(opportunities, /\[1\]\s*=\s*"achievement_321"/);
  assert.match(opportunities, /\[2\]\s*=\s*"achievement_360"/);
  assert.match(opportunities, /\[3\]\s*=\s*"achievement_337"/);
  assert.match(opportunities, /ROOM_BOSS[\s\S]*?STAGE_DARK_ROOM[\s\S]*?IsClear\(\)/,
    "lap goals must appear only at the cleared Lamb decision, not throughout a lap");
  assert.match(opportunities, /victoryLapGoalId[\s\S]*?result\[#result \+ 1\]/);
  assert.match(main, /completionAllowed[\s\S]*?achievement_321[\s\S]*?achievement_360[\s\S]*?achievement_337/,
    "only the three lap milestones may bypass the ordinary victory-lap suppression");
});

test("Member Card uses a per-shop-room purchase ledger and counts positive-price goods once", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const main = read("main.lua");

  assert.match(opportunities, /shopPurchases/);
  assert.match(opportunities, /shopRoomKey/);
  assert.match(opportunities, /function Opportunities\.observePickup/);
  assert.match(opportunities, /ROOM_SHOP/);
  assert.match(opportunities, /pickup\.Price\s*>\s*0/,
    "free pickups and non-coin prices must not advance the shop ledger");
  assert.match(opportunities, /pickup\.InitSeed/);
  assert.match(opportunities, /tostring\(pickup\.InitSeed\)/,
    "large InitSeed values must remain JSON object keys instead of sparse array indexes");
  assert.match(opportunities, /pickup\.Index/,
    "copied shop pickups that share InitSeed must still have distinct purchase identities");
  assert.match(opportunities, /IsPlaying\("Collect"\)/);
  assert.match(opportunities, /shopPurchases\[seed\]/,
    "the same collecting animation must not be charged twice");
  assert.match(opportunities, /shopSpent\s*=\s*[\s\S]*?\+\s*pickup\.Price/);
  assert.match(opportunities, /40\s*-\s*events\.shopSpent/,
    "the prompt should show the remaining spend in this shop");
  assert.match(opportunities, /function Opportunities\.onNewRoom[\s\S]*?shopRoomKey[\s\S]*?shopSpent\s*=\s*0/,
    "changing rooms starts a new single-shop ledger");
  assert.match(main, /Opportunities\.observePickup\(/);
});

test("Lil Spewer only advertises a lethal self-explosion source and is explicitly dangerous", () => {
  const opportunities = read("scripts/core/opportunities.lua");

  for (const token of [
    "COLLECTIBLE_IPECAC", "COLLECTIBLE_BOBS_ROTTEN_HEAD", "PILLEFFECT_HORF",
    "COLLECTIBLE_PYROMANIAC",
  ]) {
    assert.match(opportunities, new RegExp(`\\b${token}\\b`), `missing Lil Spewer token ${token}`);
  }
  assert.match(opportunities, /PILLEFFECT_HORF[\s\S]*?44/);
  assert.match(opportunities, /local function addLilSpewer[\s\S]*?not explosionImmune\(player\)/);
  assert.match(opportunities, /achievement_384[\s\S]*?(?:danger\s*=\s*true|COPY\.lilSpewer\s*,\s*\d+\s*,\s*true)/,
    "self-kill guidance must render through the dangerous opportunity style");
  assert.match(opportunities, /COLLECTIBLE_HOLY_MANTLE[\s\S]*?GetCollectibleEffectNum/,
    "an active one-hit shield must suppress lethal self-damage guidance");
  assert.match(opportunities, /COLLECTIBLE_IPECAC[\s\S]*?COLLECTIBLE_BOBS_ROTTEN_HEAD[\s\S]*?PILLEFFECT_HORF/,
    "Ipecac, Bob's Rotten Head, and Horf pill are the only approved sources");
});

test("second-batch aggregation deduplicates goals and never writes the user's tracker", () => {
  const opportunities = read("scripts/core/opportunities.lua");

  assert.match(opportunities, /result\s*=\s*uniqueByGoal\(result\)/);
  assert.match(opportunities, /seen\[opportunity\.goalId\]/);
  assert.doesNotMatch(opportunities, /Tracker\.(?:track|toggle|untrack)/);
  assert.doesNotMatch(opportunities, /settings\.tracked\s*=/);
});

test("third-batch copy and evaluation cover all seven restored achievement opportunities", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const copy = opportunities.match(/local COPY\s*=\s*\{([\s\S]*?)\r?\n\}/)?.[1] ?? "";
  for (const key of [
    "zip", "itsTheKey", "zipAndKey", "uBrokeIt", "hugeGrowth", "marbles",
    "rottenPenny", "momsChest",
  ]) {
    assert.match(copy, new RegExp(`\\b${key}\\s*=\\s*message\\(`), `missing COPY.${key}`);
  }
  for (const id of [326, 327, 330, 361, 386, 388, 415]) {
    assert.match(opportunities, new RegExp(`achievement_${id}`), `missing achievement_${id}`);
  }
  assert.match(opportunities, /local zipState = addZip\(result, game, profileCompleted\)/);
  for (const call of ["addItsTheKey", "addFinalItem", "addGrowth", "addMarbles",
    "addBlueFlies", "addMomsChest"]) {
    assert.match(opportunities, new RegExp(`${call}\\(result, game`), `missing ${call} evaluation`);
  }
});

test("Dark Room timing and restricted-pickup goals merge without losing either F3 goal", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const zip = opportunities.match(/local function addZip[\s\S]*?\r?\nend\r?\n\r?\nlocal function addItsTheKey/)?.[0] ?? "";
  const key = opportunities.match(/local function addItsTheKey[\s\S]*?\r?\nend\r?\n\r?\nlocal function pedestalAffordable/)?.[0] ?? "";

  assert.match(zip, /STAGE_DARK_ROOM/);
  assert.match(zip, /STAGE_ORIGINAL/);
  assert.match(zip, /game\.TimeCounter < 20 \* 60 \* 30/);
  assert.match(zip, /math\.ceil\(remainingFrames \/ 30\)/);
  assert.match(zip, /make\("achievement_326", copy, 1\)/);

  assert.match(key, /ROOM_BOSS/);
  assert.match(key, /ENTITY_LAMB/);
  for (const pickup of ["heart", "coin", "bomb"])
    assert.match(key, new RegExp(`not disqualified\\.${pickup}`));
  assert.match(key, /zipState\.opportunity\.message = copy/);
  assert.match(key, /addPairedGoals\(result, profileCompleted, "achievement_326", "achievement_327", copy, 1\)/);
});

test("item, growth, and Gulp opportunities require an actionable final step", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const affordability = opportunities.match(/local function pedestalAffordable[\s\S]*?\r?\nend\r?\n\r?\nlocal function addFinalItem/)?.[0] ?? "";
  const finalItem = opportunities.match(/local function addFinalItem[\s\S]*?\r?\nend\r?\n\r?\nlocal function addGrowth/)?.[0] ?? "";
  const growth = opportunities.match(/local function addGrowth[\s\S]*?\r?\nend\r?\n\r?\nlocal function addMarbles/)?.[0] ?? "";
  const marbles = opportunities.match(/local function addMarbles[\s\S]*?\r?\nend\r?\n\r?\nlocal function addBlueFlies/)?.[0] ?? "";

  assert.match(affordability, /GetNumCoins\(\) >= price/);
  for (const price of ["PRICE_ONE_HEART", "PRICE_TWO_HEARTS", "PRICE_THREE_SOULHEARTS",
    "PRICE_ONE_HEART_AND_TWO_SOULHEARTS"]) assert.match(affordability, new RegExp(price));
  assert.match(finalItem, /run\.progress\.items == 49/);
  assert.match(finalItem, /config\.Type == ITEM_PASSIVE or config\.Type == ITEM_FAMILIAR/);
  assert.match(finalItem, /pedestalAffordable\(pickup, player\)/);
  assert.match(growth, /run\.progress\.growth == 4/);
  for (const source of ["PILLEFFECT_ONE_MAKES_YOU_LARGER", "CARD_STRENGTH",
    "COLLECTIBLE_PLACEBO", "COLLECTIBLE_BLANK_CARD", "COLLECTIBLE_MAGIC_MUSHROOM"])
    assert.match(growth, new RegExp(source));
  assert.match(marbles, /run\.progress\.gulp == 4/);
  assert.match(marbles, /heldPillSlot\(player, game, PILLEFFECT_GULP, true\)/);
});

test("restored run sensors persist counters, deduplicate callbacks, and trigger reevaluation", () => {
  const sensors = read("scripts/core/sensors.lua");
  const main = read("main.lua");

  assert.match(sensors, /progress=\{ items=0, growth=0, gulp=0 \}, progressUseKeys=\{\}/);
  assert.match(sensors, /run\.progressUseKeys = run\.progressUseKeys or \{\}/);
  assert.match(sensors, /run\.progress\.growth = tonumber\(run\.progress\.growth\) or 0/);
  assert.match(sensors, /if run\.progressUseKeys\[progressKey\] == useKey then return false end/);
  assert.match(sensors, /table\.concat\(\{ tostring\(frameCount or Isaac\.GetFrameCount\(\)\)/);
  for (const handler of ["onUsePill", "onUseCard", "onUseItem", "observeBlueFlies"])
    assert.match(sensors, new RegExp(`function Sensors\\.${handler}`));
  assert.match(sensors, /pickup\.SubType == COLLECTIBLE_MAGIC_MUSHROOM/);
  assert.match(sensors, /completedGoals\.achievement_361 = true/);
  assert.match(sensors, /completedGoals\.achievement_386 = true/);
  assert.match(sensors, /completedGoals\.achievement_388 = true/);

  assert.match(main, /Sensors\.onUseItem\(State\.run, collectible, player, Isaac\.GetFrameCount\(\)\)/);
  assert.match(main, /Sensors\.onUsePill\(State\.run, pillEffect, player, Isaac\.GetFrameCount\(\)\)/);
  assert.match(main, /Sensors\.onUseCard\(State\.run, card, player, Isaac\.GetFrameCount\(\)\)/);
  assert.match(main, /for index = 0, GameInstance:GetNumPlayers\(\) - 1 do[\s\S]*?Sensors\.observeBlueFlies/);
  assert.match(main, /if Sensors\.onPickupUpdate[\s\S]*?State\.lastEvaluation = -1[\s\S]*?save\(\)/);
});

test("Blue Fly and Mom's Chest opportunities require an unfinished actionable source", () => {
  const opportunities = read("scripts/core/opportunities.lua");
  const sensors = read("scripts/core/sensors.lua");
  const flies = opportunities.match(/local function addBlueFlies[\s\S]*?\r?\nend\r?\n\r?\nlocal function addMomsChest/)?.[0] ?? "";
  const chest = opportunities.match(/local function addMomsChest[\s\S]*?\r?\nend\r?\n\r?\nfunction Opportunities\.observePickup/)?.[0] ?? "";

  assert.match(flies, /COLLECTIBLE_GUPPYS_HEAD/);
  assert.match(flies, /GetNumBlueFlies\(\) >= 18/);
  assert.match(flies, /COLLECTIBLE_JAR_OF_FLIES/);
  assert.match(flies, /GetNumBlueFlies\(\) \+ player:GetJarFlies\(\) >= 20/);
  assert.match(sensors, /GetNumBlueFlies\(\) >= 20[\s\S]*?achievement_388 = true/);

  assert.match(chest, /STAGE_HOME/);
  assert.match(chest, /PICKUP_MOMSCHEST/);
  assert.match(chest, /sprite:IsPlaying\("Open"\)/);
  assert.match(chest, /sprite:IsFinished\("Open"\)/);
  assert.match(chest, /make\("achievement_415", COPY\.momsChest, 1\)/);
});
