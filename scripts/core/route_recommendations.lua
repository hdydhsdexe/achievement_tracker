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

function RouteRecommendations.combinedEvaluation(route, options)
  local result = { current={}, next={}, severity="completed", memberResults={} }
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
  return result
end

return RouteRecommendations
