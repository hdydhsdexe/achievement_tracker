local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = require("scripts.core.completion_marks")
local Recommendations = require("scripts.data.recommendations")
local Routes = require("scripts.core.routes")

local RouteRecommendations = {}

RouteRecommendations.FAMILIES = {
  chest={ key="chest", order=1, marks={
    BOSS_RUSH=true, HUSH=true, MOMS_HEART=true, ISAAC=true,
    BLUE_BABY=true, MEGA_SATAN=true, DELIRIUM=true },
    steps={"BOSS_RUSH","MOMS_HEART","HUSH","ISAAC","BLUE_BABY","MEGA_SATAN","DELIRIUM"} },
  dark_room={ key="dark_room", order=2, marks={
    BOSS_RUSH=true, HUSH=true, MOMS_HEART=true, SATAN=true,
    LAMB=true, MEGA_SATAN=true, DELIRIUM=true },
    steps={"BOSS_RUSH","MOMS_HEART","HUSH","SATAN","LAMB","MEGA_SATAN","DELIRIUM"} },
  mother={ key="mother", order=3, marks={ BOSS_RUSH=true, MOTHER=true },
    steps={"BOSS_RUSH","MOTHER"} },
  beast={ key="beast", order=4, marks={ BOSS_RUSH=true, BEAST=true },
    steps={"BOSS_RUSH","BEAST"} },
  greed={ key="greed", order=5, marks={ ULTRA_GREED=true }, steps={"ULTRA_GREED"} }
}

local FAMILY_ORDER = { "chest", "dark_room", "mother", "beast", "greed" }
local SEVERITY = { completed=0, normal=1, warning=2, failed=3 }

local function enum(source, name, fallback)
  return source and source[name] or fallback
end

local STAGE = {
  BASEMENT2=enum(LevelStage,"STAGE1_2",2), CAVES2=enum(LevelStage,"STAGE2_2",4),
  DEPTHS2=enum(LevelStage,"STAGE3_2",6), WOMB2=enum(LevelStage,"STAGE4_2",8)
}
local REP_A = enum(StageType,"STAGETYPE_REPENTANCE",4)
local REP_B = enum(StageType,"STAGETYPE_REPENTANCE_B",5)
local ROOM_BOSSRUSH = enum(RoomType,"ROOM_BOSSRUSH",17)
local ROOM_ANGEL = enum(RoomType,"ROOM_ANGEL",15)
local ROOM_SACRIFICE = enum(RoomType,"ROOM_SACRIFICE",13)

local LABELS = {
  chest={zh="宝箱层路线", en="Chest route"},
  dark_room={zh="暗室路线", en="Dark Room route"},
  mother={zh="Mother路线", en="Mother route"},
  beast={zh="祸兽/Home路线", en="Beast / Home route"},
  greed={zh="究极贪婪路线", en="Ultra Greed route"}
}

local function copyIds(ids)
  local result = {}
  for _, id in ipairs(ids or {}) do result[#result + 1] = id end
  return result
end

function RouteRecommendations.normalize(route)
  if type(route) ~= "table" or not RouteRecommendations.FAMILIES[route.family]
    or type(route.memberIds) ~= "table" then return nil end
  local priority = Recommendations.SCORE[route.priority] and route.priority or "normal"
  return { family=route.family, memberIds=copyIds(route.memberIds),
    priority=priority }
end

function RouteRecommendations.label(route, language)
  local family = type(route) == "table" and route.family or route
  local labels = LABELS[family]
  return labels and (labels[language] or labels.en) or tostring(family or "")
end

local function remainingRequirements(goal, options)
  local _, _, remaining = CompletionMarks.progress(goal,
    options.completionStore, options.currentPlayers)
  return remaining
end

local function familyCompatible(goal, family, options)
  if goal.routeKind == "tainted_unlock" then return family.key == "beast" end
  local remaining = remainingRequirements(goal, options)
  if #remaining == 0 then return false end
  for _, requirement in ipairs(remaining) do
    if requirement.difficulty > options.difficulty then return false end
    if not family.marks[requirement.mark] then return false end
  end
  return true
end

local function routeAvailable(goal, options)
  if not options.evaluate then return true end
  local routeResult = options.evaluate(goal)
  return not (routeResult and routeResult.severity == "failed")
end

local function newScore()
  return { strong=0, recommended=0, normal=0, total=0, earliest=math.huge }
end

local function scoreGoals(goals, catalogOrder)
  local score = newScore()
  for _, goal in ipairs(goals) do
    local priority = Recommendations.priority(goal)
    score[priority] = (score[priority] or 0) + 1
    score.total = score.total + 1
    score.earliest = math.min(score.earliest, catalogOrder[goal.id] or math.huge)
  end
  return score
end

local function better(left, right)
  if not right then return true end
  if left.score.strong ~= right.score.strong then
    return left.score.strong > right.score.strong
  end
  if left.score.recommended ~= right.score.recommended then
    return left.score.recommended > right.score.recommended
  end
  if left.score.normal ~= right.score.normal then
    return left.score.normal > right.score.normal
  end
  if left.score.total ~= right.score.total then return left.score.total > right.score.total end
  if left.score.earliest ~= right.score.earliest then
    return left.score.earliest < right.score.earliest
  end
  return left.order < right.order
end

function RouteRecommendations.choose(goals, options)
  options = options or {}
  if options.allowed ~= true then return nil end
  options.difficulty = tonumber(options.difficulty) or 1
  options.completionStore = options.completionStore or {}
  options.currentPlayers = options.currentPlayers or {}
  options.isCompleted = options.isCompleted or function() return false end
  options.isTracked = options.isTracked or function() return false end
  local catalogOrder = {}
  for index, goal in ipairs(goals or {}) do catalogOrder[goal.id] = index end
  local bundles, hasCurrentCandidates = {}, false
  for _, familyKey in ipairs(FAMILY_ORDER) do
    local family = RouteRecommendations.FAMILIES[familyKey]
    if (options.greed == true) == (family.key == "greed") then
      local bundle = { family=family.key, order=family.order, current={}, general={} }
      for _, goal in ipairs(goals or {}) do
        if not options.isCompleted(goal) and not options.isTracked(goal.id)
          and Recommendations.priority(goal) ~= "discouraged"
          and familyCompatible(goal, family, options) and routeAvailable(goal, options) then
          local relevance = CharacterRelevance.classify(goal, options.relevanceContext)
          if relevance == "current" then
            bundle.current[#bundle.current + 1] = goal
            hasCurrentCandidates = true
          elseif relevance == "general" then
            bundle.general[#bundle.general + 1] = goal
          end
        end
      end
      bundles[#bundles + 1] = bundle
    end
  end
  local winner
  for _, bundle in ipairs(bundles) do
    local scoring = hasCurrentCandidates and bundle.current or bundle.general
    if #scoring > 0 then
      bundle.score = scoreGoals(scoring, catalogOrder)
      if better(bundle, winner) then winner = bundle end
    end
  end
  if not winner then return nil end
  local memberGoals = {}
  for _, goal in ipairs(hasCurrentCandidates and winner.current or winner.general) do
    memberGoals[#memberGoals + 1] = goal
  end
  if hasCurrentCandidates then
    for _, goal in ipairs(winner.general) do memberGoals[#memberGoals + 1] = goal end
  end
  winner.memberIds = {}
  for _, goal in ipairs(memberGoals) do winner.memberIds[#winner.memberIds + 1] = goal.id end
  table.sort(winner.memberIds, function(leftId, rightId)
    local left, right
    for _, goal in ipairs(memberGoals) do
      if goal.id == leftId then left = goal elseif goal.id == rightId then right = goal end
    end
    local leftRank, rightRank = Recommendations.rank(left), Recommendations.rank(right)
    if leftRank ~= rightRank then return leftRank > rightRank end
    return catalogOrder[leftId] < catalogOrder[rightId]
  end)
  local strongest = "normal"
  for _, goal in ipairs(memberGoals) do
    if Recommendations.SCORE[Recommendations.priority(goal)]
      > Recommendations.SCORE[strongest] then strongest = Recommendations.priority(goal) end
  end
  winner.priority = strongest
  return { family=winner.family, memberIds=winner.memberIds, priority=winner.priority }
end

function RouteRecommendations.contains(route, id)
  for _, memberId in ipairs(route and route.memberIds or {}) do
    if memberId == id then return true end
  end
  return false
end

function RouteRecommendations.conflicts(goal, route, options)
  if not goal or not route then return false end
  options = options or {}
  options.difficulty = tonumber(options.difficulty) or 1
  options.completionStore = options.completionStore or {}
  options.currentPlayers = options.currentPlayers or {}
  if not goal.completionRequirements and goal.routeKind ~= "tainted_unlock" then return false end
  local family = RouteRecommendations.FAMILIES[route.family]
  local compatible = family and familyCompatible(goal, family, options) or false
  return not compatible
end

local function localized(language, zh, en)
  return language == "zh" and zh or en
end

local function addUnique(result, seen, key, value)
  if seen[key] then return end
  seen[key] = true
  result[#result + 1] = value
end

local function isRepentanceFloor(context)
  return context.stageType == REP_A or context.stageType == REP_B
end

local function hasAny(aids, keys)
  for _, key in ipairs(keys) do if aids and aids[key] then return true end end
  return false
end

local function remainingMarks(route, options)
  local marks = {}
  local progressOptions = {
    completionStore=options.completionStore or {},
    currentPlayers=options.context and options.context.players or {}
  }
  for _, id in ipairs(route and route.memberIds or {}) do
    local goal = options.getGoal(id)
    if goal and goal.routeKind == "tainted_unlock" then
      marks.BEAST = true
    elseif goal and goal.completionRequirements then
      for _, requirement in ipairs(remainingRequirements(goal, progressOptions)) do
        marks[requirement.mark] = true
      end
    end
  end
  return marks
end

local function markFailed(result, mark)
  for _, evaluation in pairs(result.memberResults or {}) do
    if evaluation.mark == mark and evaluation.severity == "failed" then return true end
  end
  return false
end

local function departureWarnings(route, options, result)
  local context = options.context or {}
  local warnings, seen = {}, {}
  local marks = result.remainingMarks or {}
  if not context.normalTrapdoor then return warnings end
  local language = options.language
  local held = context.heldAids or {}
  local aids = context.aids or {}
  local fleshBypass = hasAny(held, {"sharp_key","soul_cain","cracked_orb"})

  if route.family == "mother" and marks.MOTHER and not markFailed(result, "MOTHER") then
    if context.stage == STAGE.BASEMENT2 and isRepentanceFloor(context)
      and not aids.knife1 and not fleshBypass then
      addUnique(warnings, seen, "knife1", localized(language,
        "下层前先取得菜刀碎片1。", "Take Knife Piece 1 before going down."))
    elseif context.stage == STAGE.CAVES2 and isRepentanceFloor(context)
      and not aids.knife2 and not fleshBypass then
      addUnique(warnings, seen, "knife2", localized(language,
        "下层前先取得菜刀碎片2。", "Take Knife Piece 2 before going down."))
    end
  end
  if route.family == "chest" and next(marks) ~= nil
    and context.stage == STAGE.DEPTHS2 and context.routeEvents
    and context.routeEvents.momDefeated and not held.polaroid then
    addUnique(warnings, seen, "photo", localized(language,
      "下层前先拾取全家福。", "Take The Polaroid before going down."))
  end
  if route.family == "dark_room" and next(marks) ~= nil
    and context.stage == STAGE.DEPTHS2 and context.routeEvents
    and context.routeEvents.momDefeated and not held.negative then
    addUnique(warnings, seen, "photo", localized(language,
      "下层前先拾取底片。", "Take The Negative before going down."))
  end
  if route.family == "beast" and marks.BEAST and not markFailed(result, "BEAST")
    and context.stage == STAGE.DEPTHS2 and not aids.dads_note then
    addUnique(warnings, seen, "beast", localized(language,
      "不要下层：先开启奇怪门并取得爸爸的便条。",
      "Do not go down: open the Strange Door and take Dad's Note first."))
  end
  if marks.BOSS_RUSH and not markFailed(result, "BOSS_RUSH")
    and context.stage == STAGE.DEPTHS2 and context.roomType ~= ROOM_BOSSRUSH then
    addUnique(warnings, seen, "boss_rush", localized(language,
      "下层前先进入并完成头目车轮战。", "Enter and clear Boss Rush before going down."))
  end
  if (marks.HUSH and not markFailed(result, "HUSH"))
      or (marks.DELIRIUM and not markFailed(result, "DELIRIUM")) then
    if context.stage == STAGE.WOMB2 and not isRepentanceFloor(context) then
      local warning = marks.DELIRIUM and localized(language,
          "不要下层：先进入蓝色裂口；精神错乱路线需经死寂。",
          "Do not go down: enter the blue opening; the Delirium route continues through Hush.")
        or localized(language, "不要下层：先进入蓝色裂口。",
          "Do not go down: enter the blue opening first.")
      addUnique(warnings, seen, "hush", warning)
    end
  end
  return warnings
end

local function megaSatanHints(route, options)
  if not (options.tracked == true) then return {} end
  local context = options.context or {}
  local marks = options.remainingMarks or remainingMarks(route, options)
  if not marks.MEGA_SATAN then return {} end
  local held = context.heldAids or {}
  local routeItems = context.routeItems or {}
  local ownsKey1, ownsKey2 = held.key1 or routeItems.key1, held.key2 or routeItems.key2
  if (ownsKey1 and ownsKey2) or hasAny(held,
    {"dads_key","jail_free","mr_me","sharp_key","soul_cain","cracked_orb"}) then
    return {}
  end
  local language = options.language
  if context.roomType == ROOM_ANGEL then
    if ((context.aids.key1 and not context.heldAids.key1)
        or (context.aids.key2 and not context.heldAids.key2))
      and (context.groundAids and (context.groundAids.key1 or context.groundAids.key2)) then
      return { localized(language, "拾取地上的钥匙碎片。", "Pick up the Key Piece on the floor.") }
    elseif context.angelAlive then
      return { localized(language, "击败天使并拾取钥匙碎片。", "Defeat the Angel and take its Key Piece.") }
    elseif context.angelStatue then
      return { context.hasBomb and localized(language,
        "炸毁天使雕像，击败天使并取得钥匙碎片。",
        "Bomb the Angel Statue, defeat the Angel, and take its Key Piece.")
        or localized(language, "找到炸弹后炸毁天使雕像。", "Find a bomb, then bomb the Angel Statue.") }
    end
  elseif context.roomType == ROOM_SACRIFICE then
    return { localized(language, "第9/11次献祭可取得钥匙碎片。",
      "Sacrifice Room hits 9/11 can award Key Pieces.") }
  end
  return {}
end

function RouteRecommendations.goalGuidance(goal, evaluation, options)
  options = options or {}
  local familyByMark = { MOTHER="mother", BEAST="beast", BLUE_BABY="chest", LAMB="dark_room" }
  local mark = evaluation and evaluation.mark
  local result = { memberResults={ single=evaluation }, remainingMarks={} }
  if mark then result.remainingMarks[mark] = true end
  return { departureWarnings=departureWarnings({ family=familyByMark[mark] }, options, result),
    contextHints={} }
end

function RouteRecommendations.combinedEvaluation(route, options)
  local result = { current={}, next={}, severity="completed", memberResults={},
    departureWarnings={}, contextHints={} }
  local currentSeen, nextSeen = {}, {}
  local orderedIds = copyIds(route and route.memberIds or {})
  local family = route and RouteRecommendations.FAMILIES[route.family]
  local stepOrder = {}
  for index, mark in ipairs(family and family.steps or {}) do stepOrder[mark] = index end
  table.sort(orderedIds, function(leftId, rightId)
    local function earliest(id)
      local goal, first = options.getGoal(id), math.huge
      if goal and goal.routeKind == "tainted_unlock" then return stepOrder.BEAST or first end
      for _, requirement in ipairs(goal and goal.completionRequirements or {}) do
        first = math.min(first, stepOrder[requirement.mark] or math.huge)
      end
      return first
    end
    return earliest(leftId) < earliest(rightId)
  end)
  for _, id in ipairs(orderedIds) do
    local goal = options.getGoal(id)
    local evaluation = goal and Routes.evaluate(goal, options.context,
      options.completionStore, options.language) or nil
    if evaluation then
      result.memberResults[id] = evaluation
      if evaluation.current and not currentSeen[evaluation.current] then
        currentSeen[evaluation.current] = true
        result.current[#result.current + 1] = evaluation.current
      end
      if evaluation.next and not nextSeen[evaluation.next] then
        nextSeen[evaluation.next] = true
        result.next[#result.next + 1] = evaluation.next
      end
      if (SEVERITY[evaluation.severity] or 1) > (SEVERITY[result.severity] or 0) then
        result.severity = evaluation.severity
      end
    end
  end
  if #result.current == 0 then result.severity = "completed" end
  result.remainingMarks = remainingMarks(route, options)
  result.departureWarnings = departureWarnings(route, options, result)
  result.contextHints = megaSatanHints(route, options)
  return result
end

return RouteRecommendations
