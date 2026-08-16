local CharacterRelevance = {}

-- Keep numeric fallbacks for Repentance versions where a newer enum constant
-- is absent, while preferring the game's PlayerType values when available.
local function playerType(name, fallback)
  return PlayerType and PlayerType[name] or fallback
end

local function collectibleType(name, fallback)
  return CollectibleType and CollectibleType[name] or fallback
end

local function trinketType(name, fallback)
  return TrinketType and TrinketType[name] or fallback
end

local NORMALIZED = {
  [11] = 8,  -- Lazarus Risen -> Lazarus
  [12] = 3,  -- Black Judas -> Judas
  [17] = 16, -- The Soul -> The Forgotten
  [20] = 19, -- Esau -> Jacob and Esau
  [38] = 29, -- Tainted Lazarus (dead) -> Tainted Lazarus
  [39] = 37, -- Tainted Jacob (lost) -> Tainted Jacob
  [40] = 35  -- Tainted Soul -> Tainted Forgotten
}

NORMALIZED[playerType("PLAYER_LAZARUS2", 11)] = playerType("PLAYER_LAZARUS", 8)
NORMALIZED[playerType("PLAYER_BLACKJUDAS", 12)] = playerType("PLAYER_JUDAS", 3)
NORMALIZED[playerType("PLAYER_THESOUL", 17)] = playerType("PLAYER_THEFORGOTTEN", 16)
NORMALIZED[playerType("PLAYER_ESAU", 20)] = playerType("PLAYER_JACOB", 19)
NORMALIZED[playerType("PLAYER_LAZARUS2_B", 38)] = playerType("PLAYER_LAZARUS_B", 29)
NORMALIZED[playerType("PLAYER_JACOB2_B", 39)] = playerType("PLAYER_JACOB_B", 37)
NORMALIZED[playerType("PLAYER_THESOUL_B", 40)] = playerType("PLAYER_THEFORGOTTEN_B", 35)

-- English catalog conditions use "as <character>" for completion requirements.
-- Long names come first so tainted and paired characters are matched precisely.
local CHARACTERS = {
  { name="Tainted Magdalene", type=playerType("PLAYER_MAGDALENE_B", 22) },
  { name="Tainted Forgotten", type=playerType("PLAYER_THEFORGOTTEN_B", 35) },
  { name="Tainted Apollyon", type=playerType("PLAYER_APOLLYON_B", 34) },
  { name="Tainted Lazarus", type=playerType("PLAYER_LAZARUS_B", 29) },
  { name="Tainted Bethany", type=playerType("PLAYER_BETHANY_B", 36) },
  { name="Tainted Azazel", type=playerType("PLAYER_AZAZEL_B", 28) },
  { name="Tainted Samson", type=playerType("PLAYER_SAMSON_B", 27) },
  { name="Tainted Lilith", type=playerType("PLAYER_LILITH_B", 32) },
  { name="Tainted Keeper", type=playerType("PLAYER_KEEPER_B", 33) },
  { name="Tainted Jacob", type=playerType("PLAYER_JACOB_B", 37) },
  { name="Tainted Isaac", type=playerType("PLAYER_ISAAC_B", 21) },
  { name="Tainted Judas", type=playerType("PLAYER_JUDAS_B", 24) },
  { name="Tainted Cain", type=playerType("PLAYER_CAIN_B", 23) },
  { name="Tainted Eden", type=playerType("PLAYER_EDEN_B", 30) },
  { name="Tainted Lost", type=playerType("PLAYER_THELOST_B", 31) },
  { name="Tainted Eve", type=playerType("PLAYER_EVE_B", 26) },
  { name="Tainted ???", type=playerType("PLAYER_BLUEBABY_B", 25) },
  { name="Jacob and Esau", type=playerType("PLAYER_JACOB", 19) },
  { name="The Forgotten", type=playerType("PLAYER_THEFORGOTTEN", 16) },
  { name="Magdalene", type=playerType("PLAYER_MAGDALENE", 1) },
  { name="Apollyon", type=playerType("PLAYER_APOLLYON", 15) },
  { name="Lazarus", type=playerType("PLAYER_LAZARUS", 8) },
  { name="Azazel", type=playerType("PLAYER_AZAZEL", 7) },
  { name="Bethany", type=playerType("PLAYER_BETHANY", 18) },
  { name="The Lost", type=playerType("PLAYER_THELOST", 10) },
  { name="Lilith", type=playerType("PLAYER_LILITH", 13) },
  { name="Keeper", type=playerType("PLAYER_KEEPER", 14) },
  { name="Samson", type=playerType("PLAYER_SAMSON", 6) },
  { name="Isaac", type=playerType("PLAYER_ISAAC", 0) },
  { name="Judas", type=playerType("PLAYER_JUDAS", 3) },
  { name="Cain", type=playerType("PLAYER_CAIN", 2) },
  { name="Eden", type=playerType("PLAYER_EDEN", 9) },
  { name="Eve", type=playerType("PLAYER_EVE", 5) },
  { name="???", type=playerType("PLAYER_XXX", 4) }
}

local CHARACTER_NAMES = {}
for _, character in ipairs(CHARACTERS) do
  CHARACTER_NAMES[CharacterRelevance and CharacterRelevance.normalize
    and CharacterRelevance.normalize(character.type) or (NORMALIZED[character.type] or character.type)] = character.name
end

-- HuijiWiki currently ships three merged English conditions. The localized
-- condition is authoritative for these rows, so keep the exceptions explicit
-- until the generated source data is corrected upstream.
local EXPLICIT_REQUIREMENTS = {
  achievement_172 = { [8] = true }, -- Lazarus
  achievement_173 = { [7] = true }, -- Azazel
  achievement_270 = {}              -- I RULE!: any character
}

-- Clicker only chooses another unlocked character from the same normal or
-- tainted roster. Transient forms (risen Lazarus, souls, Esau, etc.) are
-- deliberately omitted because completion marks belong to their base forms.
local NORMAL_CLICKER_TYPES = {
  playerType("PLAYER_ISAAC", 0), playerType("PLAYER_MAGDALENE", 1),
  playerType("PLAYER_CAIN", 2), playerType("PLAYER_JUDAS", 3),
  playerType("PLAYER_XXX", 4), playerType("PLAYER_EVE", 5),
  playerType("PLAYER_SAMSON", 6), playerType("PLAYER_AZAZEL", 7),
  playerType("PLAYER_LAZARUS", 8), playerType("PLAYER_EDEN", 9),
  playerType("PLAYER_THELOST", 10), playerType("PLAYER_LILITH", 13),
  playerType("PLAYER_KEEPER", 14), playerType("PLAYER_APOLLYON", 15),
  playerType("PLAYER_THEFORGOTTEN", 16), playerType("PLAYER_BETHANY", 18),
  playerType("PLAYER_JACOB", 19)
}

local TAINTED_CLICKER_TYPES = {
  playerType("PLAYER_ISAAC_B", 21), playerType("PLAYER_MAGDALENE_B", 22),
  playerType("PLAYER_CAIN_B", 23), playerType("PLAYER_JUDAS_B", 24),
  playerType("PLAYER_BLUEBABY_B", 25), playerType("PLAYER_EVE_B", 26),
  playerType("PLAYER_SAMSON_B", 27), playerType("PLAYER_AZAZEL_B", 28),
  playerType("PLAYER_LAZARUS_B", 29), playerType("PLAYER_EDEN_B", 30),
  playerType("PLAYER_THELOST_B", 31), playerType("PLAYER_LILITH_B", 32),
  playerType("PLAYER_KEEPER_B", 33), playerType("PLAYER_APOLLYON_B", 34),
  playerType("PLAYER_THEFORGOTTEN_B", 35), playerType("PLAYER_BETHANY_B", 36),
  playerType("PLAYER_JACOB_B", 37)
}

local TAINTED_TYPES = {}
for _, value in ipairs(TAINTED_CLICKER_TYPES) do TAINTED_TYPES[value] = true end

local FIXED_TRANSFORMATIONS = {
  { key="ankh", kind="collectible", id=collectibleType("COLLECTIBLE_ANKH", 161),
    target=playerType("PLAYER_XXX", 4) },
  { key="broken_ankh", kind="trinket", id=trinketType("TRINKET_BROKEN_ANKH", 28),
    target=playerType("PLAYER_XXX", 4) },
  { key="judas_shadow", kind="collectible",
    id=collectibleType("COLLECTIBLE_JUDAS_SHADOW", 311),
    target=playerType("PLAYER_JUDAS", 3) },
  { key="lazarus_rags", kind="collectible",
    id=collectibleType("COLLECTIBLE_LAZARUS_RAGS", 332),
    target=playerType("PLAYER_LAZARUS", 8) },
  { key="missing_poster", kind="trinket",
    id=trinketType("TRINKET_MISSING_POSTER", 23),
    target=playerType("PLAYER_THELOST", 10) }
}

local CLICKER = collectibleType("COLLECTIBLE_CLICKER", 482)

-- These are also recoverable from catalog observation metadata. The fallback
-- fills a handful of generated rows whose observations are not yet complete.
local DEFAULT_UNLOCK_ACHIEVEMENTS = {
  [1]=1, [2]=2, [3]=3, [4]=32, [5]=42, [6]=67, [7]=79, [8]=80,
  [9]=81, [10]=82, [13]=199, [14]=251, [15]=340, [16]=390,
  [18]=404, [19]=405,
  [21]=474, [22]=475, [23]=476, [24]=477, [25]=478, [26]=479,
  [27]=480, [28]=481, [29]=482, [30]=483, [31]=484, [32]=485,
  [33]=486, [34]=487, [35]=488, [36]=489, [37]=490
}

function CharacterRelevance.normalize(value)
  return NORMALIZED[value] or value
end

function CharacterRelevance.characterName(value)
  return CHARACTER_NAMES[CharacterRelevance.normalize(value)]
end

function CharacterRelevance.characters()
  return CHARACTERS
end

local requirementCache = setmetatable({}, { __mode="k" })

function CharacterRelevance.requiredPlayerTypes(goal)
  if type(goal) ~= "table" then return {} end
  local explicit = EXPLICIT_REQUIREMENTS[goal.id]
  if explicit ~= nil then return explicit end
  if requirementCache[goal] then return requirementCache[goal] end
  local required = {}
  local detail = goal and goal.en and goal.en.detail
  if type(detail) == "string" then
    for _, character in ipairs(CHARACTERS) do
      local suffix = " as " .. character.name
      local searchFrom = 1
      while true do
        local startAt, endAt = string.find(detail, suffix, searchFrom, true)
        if not startAt then break end
        local tail = string.sub(detail, endAt + 1)
        local terminal = tail:match("^%s*%.?%s*$") ~= nil
        local alternateTail = tail:match("^%s*,%s*or%s+") ~= nil
        local hasGeneralAlternative = alternateTail
          and not string.find(tail, " as ", 1, true)
        if terminal or not hasGeneralAlternative then
          required[CharacterRelevance.normalize(character.type)] = true
        end
        searchFrom = endAt + 1
      end
    end
  end
  requirementCache[goal] = required
  return required
end

function CharacterRelevance.requiredPlayerType(goal)
  return next(CharacterRelevance.requiredPlayerTypes(goal))
end

local function addType(set, value)
  set[CharacterRelevance.normalize(value)] = true
end

local function sortedTypes(set)
  local values = {}
  for value in pairs(set) do table.insert(values, value) end
  table.sort(values)
  for index, value in ipairs(values) do values[index] = tostring(value) end
  return table.concat(values, ",")
end

local unlockCache = setmetatable({}, { __mode="k" })

local function unlockAchievements(goals)
  if type(goals) == "table" and unlockCache[goals] then return unlockCache[goals] end
  local result = {}
  for player, achievement in pairs(DEFAULT_UNLOCK_ACHIEVEMENTS) do
    result[player] = achievement
  end
  for _, goal in ipairs(goals or {}) do
    if goal.observation and goal.observation.kind == "player" and goal.achievementId then
      for _, value in ipairs(goal.observation.values or {}) do
        result[CharacterRelevance.normalize(value)] = goal.achievementId
      end
    end
  end
  if type(goals) == "table" then unlockCache[goals] = result end
  return result
end

local function getPersistentGameData()
  if not Isaac or not Isaac.GetPersistentGameData then return nil end
  local ok, persistentData = pcall(Isaac.GetPersistentGameData)
  if ok and persistentData and persistentData.Unlocked then return persistentData end
  return nil
end

local function isCharacterUnlocked(player, persistentData, achievements, current)
  if current[player] then return true end
  if player == playerType("PLAYER_ISAAC", 0) then return true end
  local achievementId = achievements[player]
  if not achievementId then return false end
  local ok, unlocked = pcall(function()
    return persistentData:Unlocked(achievementId)
  end)
  return ok and unlocked == true
end

local function playerHasSource(player, source)
  if source.kind == "collectible" then return player:HasCollectible(source.id) end
  -- HasTrinket covers held trinkets and permanent Gulp!/Smelter effects.
  return player:HasTrinket(source.id)
end

local function addReachable(reachable, reachableSet, value)
  value = CharacterRelevance.normalize(value)
  if reachableSet[value] then return end
  reachableSet[value] = true
  table.insert(reachable, value)
end

local function addClickerPool(fromType, reachable, reachableSet, persistentData,
    achievements, current, clickerCandidates, expandedPools)
  local pool = TAINTED_TYPES[fromType] and TAINTED_CLICKER_TYPES or NORMAL_CLICKER_TYPES
  if expandedPools[pool] then return end
  expandedPools[pool] = true
  for _, candidate in ipairs(pool) do
    candidate = CharacterRelevance.normalize(candidate)
    if not persistentData
      or isCharacterUnlocked(candidate, persistentData, achievements, current) then
      addType(clickerCandidates, candidate)
      addReachable(reachable, reachableSet, candidate)
    end
  end
end

function CharacterRelevance.buildContext(game, goals)
  local context = { current={}, convertible={}, signature="" }
  if not game then return context end
  local players = {}
  for index = 0, game:GetNumPlayers() - 1 do
    local player = Isaac.GetPlayer(index)
    if player then
      table.insert(players, player)
      addType(context.current, player:GetPlayerType())
    end
  end

  local persistentData = getPersistentGameData()
  local achievements = unlockAchievements(goals)
  local signatureParts = {}
  for index, player in ipairs(players) do
    local currentType = CharacterRelevance.normalize(player:GetPlayerType())
    local reachable, reachableSet = {}, {}
    local fixedTargets, sourceFlags = {}, {}
    addReachable(reachable, reachableSet, currentType)
    for _, source in ipairs(FIXED_TRANSFORMATIONS) do
      local present = playerHasSource(player, source)
      table.insert(sourceFlags, source.key .. "=" .. (present and "1" or "0"))
      if present then table.insert(fixedTargets, source.target) end
    end
    local hasClicker = player:HasCollectible(CLICKER)
    table.insert(sourceFlags, "clicker=" .. (hasClicker and "1" or "0"))
    local clickerCandidates, expandedPools = {}, {}
    local queueIndex = 1
    while queueIndex <= #reachable do
      local fromType = reachable[queueIndex]
      queueIndex = queueIndex + 1
      for _, target in ipairs(fixedTargets) do
        addReachable(reachable, reachableSet, target)
      end
      if hasClicker then
        addClickerPool(fromType, reachable, reachableSet, persistentData,
          achievements, context.current, clickerCandidates, expandedPools)
      end
    end
    for value in pairs(reachableSet) do
      if value ~= currentType then addType(context.convertible, value) end
    end
    table.insert(signatureParts, tostring(index) .. ":" .. tostring(currentType)
      .. ":" .. table.concat(sourceFlags, ",")
      .. ":pool=" .. sortedTypes(clickerCandidates))
  end
  for value in pairs(context.current) do context.convertible[value] = nil end
  context.signature = "current=" .. sortedTypes(context.current)
    .. "|convertible=" .. sortedTypes(context.convertible)
    .. "|players=" .. table.concat(signatureParts, ";")
  return context
end

function CharacterRelevance.classify(goal, context)
  local required = CharacterRelevance.requiredPlayerTypes(goal)
  if next(required) == nil then return "current" end
  context = context or { current={}, convertible={} }
  for player in pairs(required) do
    if context.current[player] then return "current" end
  end
  for player in pairs(required) do
    if context.convertible[player] then return "convertible" end
  end
  return "other"
end

function CharacterRelevance.isRelevant(goal, game)
  return CharacterRelevance.classify(goal,
    CharacterRelevance.buildContext(game)) == "current"
end

return CharacterRelevance
