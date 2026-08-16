local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = {}

CompletionMarks.ORDER = {
  "MOMS_HEART", "ISAAC", "SATAN", "BOSS_RUSH", "BLUE_BABY", "LAMB",
  "MEGA_SATAN", "ULTRA_GREED", "HUSH", "DELIRIUM", "MOTHER", "BEAST"
}

local MARK_LABELS = {
  MOMS_HEART={zh="妈心", en="Mom's Heart"}, ISAAC={zh="以撒", en="Isaac"},
  SATAN={zh="撒但", en="Satan"}, BOSS_RUSH={zh="头目车轮战", en="Boss Rush"},
  BLUE_BABY={zh="???", en="???"}, LAMB={zh="羔羊", en="The Lamb"},
  MEGA_SATAN={zh="超级撒但", en="Mega Satan"},
  ULTRA_GREED={zh="究极贪婪", en="Ultra Greed"}, HUSH={zh="死寂", en="Hush"},
  DELIRIUM={zh="精神错乱", en="Delirium"}, MOTHER={zh="母亲", en="Mother"},
  BEAST={zh="祸兽", en="The Beast"}
}

local PATTERNS = {
  {mark="MOMS_HEART", pattern="Mom's Heart"}, {mark="MOMS_HEART", pattern="It Lives"},
  {mark="BOSS_RUSH", pattern="Boss Rush"}, {mark="MEGA_SATAN", pattern="Mega Satan"},
  {mark="ULTRA_GREED", pattern="Ultra Greedier", difficulty=2},
  {mark="ULTRA_GREED", pattern="Ultra Greed"}, {mark="BLUE_BABY", pattern="???"},
  {mark="DELIRIUM", pattern="Delirium"}, {mark="MOTHER", pattern="Mother"},
  {mark="BEAST", pattern="The Beast"}, {mark="HUSH", pattern="Hush"},
  {mark="ISAAC", pattern="Isaac"}, {mark="SATAN", pattern="Satan"},
  {mark="LAMB", pattern="The Lamb"}
}

local function addRequirement(result, seen, player, mark, difficulty)
  local key = tostring(player or "any") .. ":" .. mark
  if seen[key] then
    seen[key].difficulty = math.max(seen[key].difficulty, difficulty)
    return
  end
  local requirement = { playerType=player, mark=mark, difficulty=difficulty }
  seen[key] = requirement
  table.insert(result, requirement)
end

local function segmentBeforeCharacter(detail, characterName)
  local suffix = " as " .. characterName
  local at = string.find(detail, suffix, 1, true)
  if not at then return nil end
  local startAt = 1
  local previous = string.sub(detail, 1, at - 1):match(".*()[.;]")
  if previous then startAt = previous + 1 end
  return string.sub(detail, startAt, at - 1)
end

local function safeCompletionCondition(detail)
  if type(detail) ~= "string" then return false end
  local lower = string.lower(detail)
  if not string.find(detail, "Defeat ", 1, true)
    and not string.find(detail, "Completion Marks", 1, true) then return false end
  for _, unsafe in ipairs({" times", "without dying", "every character", "challenge #",
      "and unlock", "or defeat Ultra Pride", "Collect "}) do
    if string.find(lower, string.lower(unsafe), 1, true) then return false end
  end
  return true
end

function CompletionMarks.attach(goals)
  for _, goal in ipairs(goals or {}) do
    local detail = goal.en and goal.en.detail
    if safeCompletionCondition(detail) then
      local result, seen = {}, {}
      local players = CharacterRelevance.requiredPlayerTypes(goal)
      local baseDifficulty = string.find(string.lower(detail), "hard mode", 1, true) and 2 or 1
      if string.find(detail, "all Hard mode Completion Marks", 1, true) then
        for player in pairs(players) do
          for _, mark in ipairs(CompletionMarks.ORDER) do
            addRequirement(result, seen, player, mark, 2)
          end
        end
      else
        if next(players) == nil then
          for _, candidate in ipairs(PATTERNS) do
            if string.find(detail, "Defeat " .. candidate.pattern, 1, true) == 1 then
              addRequirement(result, seen, nil, candidate.mark,
                candidate.difficulty or baseDifficulty)
              break
            end
          end
        else
          for player in pairs(players) do
            local name = CharacterRelevance.characterName(player)
            local segment = name and segmentBeforeCharacter(detail, name) or detail
            if segment then
              for _, candidate in ipairs(PATTERNS) do
                local searchable = candidate.mark == "SATAN"
                  and string.gsub(segment, "Mega Satan", "") or segment
                if string.find(searchable, candidate.pattern, 1, true) then
                  addRequirement(result, seen, player, candidate.mark,
                    candidate.difficulty or baseDifficulty)
                end
              end
            end
          end
        end
      end
      if #result > 0 then goal.completionRequirements = result end
    end
  end
end

local function playerMarks(store, player, create)
  local key = tostring(CharacterRelevance.normalize(player))
  if create and type(store[key]) ~= "table" then store[key] = {} end
  return store[key]
end

function CompletionMarks.merge(store, player, mark, value)
  if type(store) ~= "table" or not MARK_LABELS[mark] then return false end
  value = math.max(0, math.min(2, math.floor(tonumber(value) or 0)))
  if value == 0 then return false end
  local marks = playerMarks(store, player, true)
  local old = math.max(0, math.min(2, math.floor(tonumber(marks[mark]) or 0)))
  if value <= old then return false end
  marks[mark] = value
  return true
end

function CompletionMarks.get(store, player, mark)
  local marks = type(store) == "table" and playerMarks(store, player, false)
  return marks and tonumber(marks[mark]) or 0
end

function CompletionMarks.label(mark, language)
  local labels = MARK_LABELS[mark]
  return labels and (labels[language] or labels.en) or tostring(mark)
end

function CompletionMarks.progress(goal, store, currentPlayers)
  local requirements = goal and goal.completionRequirements or {}
  local known, remaining = 0, {}
  for _, requirement in ipairs(requirements) do
    local satisfied = false
    if requirement.playerType ~= nil then
      satisfied = CompletionMarks.get(store, requirement.playerType, requirement.mark)
        >= requirement.difficulty
    else
      for player in pairs(currentPlayers or {}) do
        if CompletionMarks.get(store, player, requirement.mark) >= requirement.difficulty then
          satisfied = true
          break
        end
      end
    end
    if satisfied then known = known + 1 else table.insert(remaining, requirement) end
  end
  return known, #requirements, remaining
end

function CompletionMarks.isSatisfied(goal, store)
  local requirements = goal and goal.completionRequirements or {}
  if #requirements == 0 then return false end
  for _, requirement in ipairs(requirements) do
    if requirement.playerType == nil
      or CompletionMarks.get(store, requirement.playerType, requirement.mark) < requirement.difficulty then
      return false
    end
  end
  return true
end

function CompletionMarks.infer(goals, completed, store)
  local changed = false
  for _, goal in ipairs(goals or {}) do
    if completed and completed[goal.id] and goal.completionRequirements then
      for _, requirement in ipairs(goal.completionRequirements) do
        if requirement.playerType ~= nil then
          changed = CompletionMarks.merge(store, requirement.playerType, requirement.mark,
            requirement.difficulty) or changed
        end
      end
    end
  end
  return changed
end

local REPENTOGON_FIELDS = {
  MomsHeart="MOMS_HEART", Isaac="ISAAC", Satan="SATAN", BossRush="BOSS_RUSH",
  BlueBaby="BLUE_BABY", Lamb="LAMB", MegaSatan="MEGA_SATAN",
  UltraGreed="ULTRA_GREED", UltraGreedier="ULTRA_GREED", Hush="HUSH",
  Delirium="DELIRIUM", Mother="MOTHER", Beast="BEAST"
}

function CompletionMarks.syncRepentogon(store, playerTypes)
  if not Isaac or type(Isaac.GetCompletionMarks) ~= "function" then return false end
  local changed = false
  for player in pairs(playerTypes or {}) do
    local ok, marks = pcall(Isaac.GetCompletionMarks, player)
    if ok and type(marks) == "table" then
      for field, mark in pairs(REPENTOGON_FIELDS) do
        changed = CompletionMarks.merge(store, player, mark, marks[field]) or changed
      end
    end
  end
  return changed
end

function CompletionMarks.difficultyValue(game)
  local difficulty = game and game.Difficulty
  if difficulty == (Difficulty and Difficulty.DIFFICULTY_HARD or 1)
    or difficulty == (Difficulty and Difficulty.DIFFICULTY_GREEDIER or 3) then return 2 end
  return 1
end

return CompletionMarks
