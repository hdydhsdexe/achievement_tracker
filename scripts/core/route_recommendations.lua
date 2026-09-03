local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = require("scripts.core.completion_marks")
local Recommendations = require("scripts.data.recommendations")
local Routes = require("scripts.core.routes")

local RouteRecommendations = {}

local NORMAL_ENDPOINT_ORDER = { "mother", "lamb", "blue_baby", "beast" }
local OPTIONAL_ORDER = { "BOSS_RUSH", "HUSH", "DELIRIUM", "MEGA_SATAN" }
local LEGACY_ENDPOINTS = { chest="blue_baby", dark_room="lamb" }

RouteRecommendations.ENDPOINTS = {
  mother={ key="mother", order=1, endpointMark="MOTHER",
    marks={ MOTHER=true }, steps={"MOTHER"} },
  lamb={ key="lamb", order=2, endpointMark="LAMB",
    marks={ MOMS_HEART=true, SATAN=true, LAMB=true },
    steps={"MOMS_HEART","SATAN","LAMB"} },
  blue_baby={ key="blue_baby", order=3, endpointMark="BLUE_BABY",
    marks={ MOMS_HEART=true, ISAAC=true, BLUE_BABY=true },
    steps={"MOMS_HEART","ISAAC","BLUE_BABY"} },
  beast={ key="beast", order=4, endpointMark="BEAST",
    marks={ BEAST=true }, steps={"BEAST"} },
  greed={ key="greed", order=5, endpointMark="ULTRA_GREED",
    marks={ ULTRA_GREED=true }, steps={"ULTRA_GREED"}, difficulty=1 },
  greedier={ key="greedier", order=6, endpointMark="ULTRA_GREED",
    marks={ ULTRA_GREED=true }, steps={"ULTRA_GREED"}, difficulty=2 }
}

-- Kept as a public alias for integrations written against the first route API.
RouteRecommendations.FAMILIES = RouteRecommendations.ENDPOINTS
local SEVERITY = { completed=0, normal=1, warning=2, failed=3 }

local function enum(source, name, fallback)
  return source and source[name] or fallback
end

local STAGE = {
  BASEMENT2=enum(LevelStage,"STAGE1_2",2), CAVES2=enum(LevelStage,"STAGE2_2",4),
  DEPTHS2=enum(LevelStage,"STAGE3_2",6), WOMB2=enum(LevelStage,"STAGE4_2",8),
  BLUE_WOMB=enum(LevelStage,"STAGE4_3",9)
}
local REP_A = enum(StageType,"STAGETYPE_REPENTANCE",4)
local REP_B = enum(StageType,"STAGETYPE_REPENTANCE_B",5)
local ROOM_BOSSRUSH = enum(RoomType,"ROOM_BOSSRUSH",17)
local ROOM_ANGEL = enum(RoomType,"ROOM_ANGEL",15)
local ROOM_SACRIFICE = enum(RoomType,"ROOM_SACRIFICE",13)

local LABELS = {
  mother={zh="母亲", en="Mother"}, lamb={zh="羔羊", en="The Lamb"},
  blue_baby={zh="???", en="???"}, beast={zh="祸兽", en="The Beast"},
  greed={zh="贪婪", en="Ultra Greed"},
  greedier={zh="超级贪婪", en="Ultra Greedier"}
}

local function copyIds(ids)
  local result = {}
  for _, id in ipairs(ids or {}) do result[#result + 1] = id end
  return result
end

local function copyStrings(values, allowed)
  local result, seen = {}, {}
  for _, value in ipairs(values or {}) do
    if (not allowed or allowed[value]) and not seen[value] then
      result[#result + 1], seen[value] = value, true
    end
  end
  return result
end

local OPTIONAL_SET = {}
for _, mark in ipairs(OPTIONAL_ORDER) do OPTIONAL_SET[mark] = true end

local function sortedOptionalBosses(values)
  local selected = {}
  for _, value in ipairs(copyStrings(values, OPTIONAL_SET)) do selected[value] = true end
  local result = {}
  for _, mark in ipairs(OPTIONAL_ORDER) do
    if selected[mark] then result[#result + 1] = mark end
  end
  return result
end

function RouteRecommendations.normalize(route, options)
  if type(route) ~= "table" or type(route.memberIds) ~= "table" then return nil end
  local endpoint = route.endpoint or LEGACY_ENDPOINTS[route.family] or route.family
  if endpoint == "greed" and options and options.greedier then endpoint = "greedier" end
  if not RouteRecommendations.ENDPOINTS[endpoint] then return nil end
  local priority = Recommendations.SCORE[route.priority] and route.priority or "normal"
  return { endpoint=endpoint, family=endpoint, memberIds=copyIds(route.memberIds),
    optionalBosses=sortedOptionalBosses(route.optionalBosses),
    confirmedThrough=type(route.confirmedThrough) == "string" and route.confirmedThrough or nil,
    priority=priority }
end

function RouteRecommendations.label(route, language)
  local endpoint = type(route) == "table" and (route.endpoint or route.family) or route
  endpoint = LEGACY_ENDPOINTS[endpoint] or endpoint
  local labels = LABELS[endpoint]
  return labels and (labels[language] or labels.en) or tostring(endpoint or "")
end

local function remainingRequirements(goal, options)
  local _, _, remaining = CompletionMarks.progress(goal,
    options.completionStore, options.currentPlayers)
  return remaining
end

local function marksForRoute(route)
  local endpoint = RouteRecommendations.ENDPOINTS[route.endpoint or route.family]
  local marks = {}
  for mark in pairs(endpoint and endpoint.marks or {}) do marks[mark] = true end
  for _, mark in ipairs(route.optionalBosses or {}) do marks[mark] = true end
  return marks
end

local function routeCompatible(goal, route, options)
  if goal.routeKind == "tainted_unlock" then
    return (route.endpoint or route.family) == "beast"
  end
  local remaining = remainingRequirements(goal, options)
  if #remaining == 0 then return false end
  local marks = marksForRoute(route)
  for _, requirement in ipairs(remaining) do
    if requirement.difficulty > options.difficulty then return false end
    if not marks[requirement.mark] then return false end
  end
  return true
end

local function newScore()
  return { strong=0, recommended=0, normal=0, discouraged=0,
    total=0, earliest=math.huge }
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
  if left.score.discouraged ~= right.score.discouraged then
    return left.score.discouraged > right.score.discouraged
  end
  if left.score.total ~= right.score.total then return left.score.total > right.score.total end
  if left.score.earliest ~= right.score.earliest then
    return left.score.earliest < right.score.earliest
  end
  return left.order < right.order
end

local function sortGoalIds(goals, catalogOrder)
  local byId, memberIds = {}, {}
  for _, goal in ipairs(goals) do
    byId[goal.id] = goal
    memberIds[#memberIds + 1] = goal.id
  end
  table.sort(memberIds, function(leftId, rightId)
    local left, right = byId[leftId], byId[rightId]
    local leftRank, rightRank = Recommendations.rank(left), Recommendations.rank(right)
    if leftRank ~= rightRank then return leftRank > rightRank end
    return catalogOrder[leftId] < catalogOrder[rightId]
  end)
  return memberIds
end

local function strongestPriority(goals)
  local strongest
  for _, goal in ipairs(goals) do
    local priority = Recommendations.priority(goal)
    if not strongest or Recommendations.SCORE[priority]
      > Recommendations.SCORE[strongest] then strongest = priority end
  end
  return strongest or "normal"
end

local function endpointKeys(options)
  if options.greed then return { options.greedier and "greedier" or "greed" } end
  return NORMAL_ENDPOINT_ORDER
end

local function hasAid(options, key)
  local context = options.context or {}
  return (context.aids and context.aids[key]) or (context.heldAids and context.heldAids[key])
end

local function optionCompatibility(endpoint, mark, options)
  local context = options.context or {}
  local normal = endpoint ~= "greed" and endpoint ~= "greedier"
  if not normal then return false, "贪婪模式没有该可选 Boss", "This optional boss is unavailable in Greed Mode" end
  if mark == "BOSS_RUSH" then
    if context.stage and context.stage > STAGE.DEPTHS2 and not hasAid(options, "r_key") then
      return false, "已错过 Boss Rush 入口", "The Boss Rush entrance was missed"
    end
    return true
  elseif mark == "HUSH" then
    if context.stage and context.stage > STAGE.WOMB2
      and context.stage ~= STAGE.BLUE_WOMB and not hasAid(options, "r_key") then
      return false, "已错过蓝色子宫入口", "The Blue Womb entrance was missed"
    end
    if endpoint == "lamb" or endpoint == "blue_baby" or hasAid(options, "r_key") then return true end
    return false, "死寂会偏离该终点，需要 R Key 才能串联", "Hush diverts from this endpoint; R Key is required"
  elseif mark == "DELIRIUM" then
    if endpoint == "lamb" or endpoint == "blue_baby" then return true end
    if endpoint == "mother" and context.voidPortal then return true end
    return false, endpoint == "beast" and "祸兽会直接结束对局"
      or "只有实际出现虚空入口后才能串联精神错乱",
      endpoint == "beast" and "The Beast ends the run"
      or "Delirium requires a live Void portal after Mother"
  elseif mark == "MEGA_SATAN" then
    if endpoint == "lamb" or endpoint == "blue_baby" then return true end
    return false, "超级撒但仅兼容羔羊与???路线", "Mega Satan only fits The Lamb and ??? routes"
  end
  return false
end

local function autoOptionalBosses(eligibleGoals, endpoint, options)
  local selected, selectedSet = {}, {}
  local base = RouteRecommendations.ENDPOINTS[endpoint]
  for _, goal in ipairs(eligibleGoals) do
    for _, requirement in ipairs(remainingRequirements(goal, options)) do
      if not base.marks[requirement.mark] and OPTIONAL_SET[requirement.mark]
        and not selectedSet[requirement.mark]
        and optionCompatibility(endpoint, requirement.mark, options) then
        selectedSet[requirement.mark] = true
      end
    end
  end
  for _, mark in ipairs(OPTIONAL_ORDER) do
    if selectedSet[mark] then selected[#selected + 1] = mark end
  end
  return selected
end

local PREFIX_ORDER = { MOMS_HEART=1, ISAAC=2, SATAN=2, BLUE_BABY=3, LAMB=3,
  MOTHER=3, BEAST=3, ULTRA_GREED=3, DELIRIUM=4 }

local function stablePrefix(endpoint, context)
  context = context or {}
  local stage = tonumber(context.stage) or 0
  local original = enum(StageType,"STAGETYPE_ORIGINAL",0)
  local wotl = enum(StageType,"STAGETYPE_WOTL",1)
  if endpoint == "greed" or endpoint == "greedier" then return "ULTRA_GREED" end
  if endpoint == "mother" then
    if stage >= enum(LevelStage,"STAGE4_1",7)
      and context.stageType ~= REP_A and context.stageType ~= REP_B
      and not (context.aids and context.aids.r_key) then return "MOMS_HEART" end
    return (context.secretExitUnlocked ~= false or context.secretExitDoor)
      and "MOTHER" or "MOMS_HEART"
  end
  if endpoint == "beast" then
    if stage > STAGE.DEPTHS2 and not context.ascent
      and stage ~= enum(LevelStage,"STAGE8",13)
      and not (context.aids and context.aids.r_key) then return "MOMS_HEART" end
    return context.strangeDoorUnlocked ~= false and "BEAST" or "MOMS_HEART"
  end
  if endpoint == "lamb" then
    if context.aids and context.aids.r_key then return "LAMB" end
    if stage >= enum(LevelStage,"STAGE6",11) and context.stageType == original then return "LAMB" end
    if stage >= enum(LevelStage,"STAGE5",10) then
      if context.stageType ~= original then return "MOMS_HEART" end
      return context.aids and context.aids.negative and "LAMB" or "SATAN"
    end
    if stage <= STAGE.DEPTHS2 and (context.negativeUnlocked
      or (context.aids and context.aids.negative)) then return "LAMB" end
    if context.heldAids and context.heldAids.negative then return "LAMB" end
    if context.deepPathsUnlocked or context.devilExit or (context.aids and
      (context.aids.deeper or context.aids.ehwaz)) then return "SATAN" end
    return "MOMS_HEART"
  end
  if context.aids and context.aids.r_key then return "BLUE_BABY" end
  if stage >= enum(LevelStage,"STAGE6",11) and context.stageType == wotl then return "BLUE_BABY" end
  if stage >= enum(LevelStage,"STAGE5",10) then
    if context.stageType ~= wotl then return "MOMS_HEART" end
    return context.aids and context.aids.polaroid and "BLUE_BABY" or "ISAAC"
  end
  if stage <= STAGE.DEPTHS2 and (context.polaroidUnlocked
    or (context.aids and context.aids.polaroid)) then return "BLUE_BABY" end
  if context.heldAids and context.heldAids.polaroid then return "BLUE_BABY" end
  if context.deepPathsUnlocked or context.angelExit then return "ISAAC" end
  return "MOMS_HEART"
end

function RouteRecommendations.initializeProgress(route, context)
  if not route or route.confirmedThrough then return false end
  route.confirmedThrough = stablePrefix(route.endpoint or route.family, context)
  return route.confirmedThrough ~= nil
end

function RouteRecommendations.list(goals, options)
  options = options or {}
  if options.allowed ~= true then return {} end
  options.difficulty = tonumber(options.difficulty) or 1
  options.completionStore = options.completionStore or {}
  options.currentPlayers = options.currentPlayers or {}
  options.isCompleted = options.isCompleted or function() return false end
  options.isTracked = options.isTracked or function() return false end
  local includeDiscouraged = options.includeDiscouraged == true
  local catalogOrder = {}
  for index, goal in ipairs(goals or {}) do catalogOrder[goal.id] = index end
  local eligible = {}
  for _, goal in ipairs(goals or {}) do
    if not options.isCompleted(goal) and not options.isTracked(goal.id)
      and (includeDiscouraged or Recommendations.priority(goal) ~= "discouraged") then
      local relevance = CharacterRelevance.classify(goal, options.relevanceContext)
      if relevance == "current" or relevance == "general" then eligible[#eligible + 1] = goal end
    end
  end
  local candidates = {}
  for _, endpointKey in ipairs(endpointKeys(options)) do
    local endpoint = RouteRecommendations.ENDPOINTS[endpointKey]
    local route = { endpoint=endpointKey, family=endpointKey, memberIds={},
      optionalBosses=autoOptionalBosses(eligible, endpointKey, options),
      confirmedThrough=stablePrefix(endpointKey, options.context), priority="normal" }
    local available, conditional, unavailable, failureReason, recoverable = {}, {}, {}, nil, false
    for _, goal in ipairs(eligible) do
      if routeCompatible(goal, route, options) then
        local routeResult = options.evaluate and options.evaluate(goal) or nil
        if routeResult and routeResult.severity == "failed" then
          unavailable[#unavailable + 1] = goal
          failureReason = failureReason or routeResult.current
        elseif routeResult and routeResult.severity == "warning" then
          conditional[#conditional + 1] = goal
          recoverable = true
        else available[#available + 1] = goal end
      end
    end
    local scored = {}
    for _, goal in ipairs(available) do scored[#scored + 1] = goal end
    for _, goal in ipairs(conditional) do scored[#scored + 1] = goal end
    route.memberIds = sortGoalIds(scored, catalogOrder)
    route.priority = strongestPriority(scored)
    local score = scoreGoals(scored, catalogOrder)
    candidates[#candidates + 1] = { route=route,
      availableMemberIds=sortGoalIds(available, catalogOrder),
      conditionalMemberIds=sortGoalIds(conditional, catalogOrder),
      unavailableMemberIds=sortGoalIds(unavailable, catalogOrder),
      selectable=true, recoverable=recoverable, failureReason=failureReason,
      score=score, order=endpoint.order }
  end
  table.sort(candidates, function(left, right)
    return better(left, right)
  end)
  return candidates
end

function RouteRecommendations.choose(goals, options)
  options = options or {}
  if options.allowed ~= true then return nil end
  local listOptions = {}
  for key, value in pairs(options) do listOptions[key] = value end
  listOptions.includeDiscouraged=false
  for _, candidate in ipairs(RouteRecommendations.list(goals, listOptions)) do
    if candidate.selectable and candidate.score.total > 0 then
      return RouteRecommendations.normalize(candidate.route)
    end
  end
  return nil
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
  return not routeCompatible(goal, route, options)
end

function RouteRecommendations.sameRoute(left, right)
  return left and right and (left.endpoint or left.family) == (right.endpoint or right.family)
end

function RouteRecommendations.optionalBossEntries(route, options)
  options = options or {}
  local endpoint = route.endpoint or route.family
  if endpoint == "greed" or endpoint == "greedier" then return {} end
  local selected = {}
  for _, mark in ipairs(route.optionalBosses or {}) do selected[mark] = true end
  local result = {}
  for _, mark in ipairs(OPTIONAL_ORDER) do
    if mark ~= "MEGA_SATAN" or endpoint == "lamb" or endpoint == "blue_baby" then
      local selectable, zhReason, enReason = optionCompatibility(endpoint, mark, options)
      result[#result + 1] = { mark=mark, selected=selected[mark] == true,
        selectable=selectable, reason=options.language == "zh" and zhReason or enReason }
    end
  end
  return result
end

function RouteRecommendations.toggleOptionalBoss(route, mark, options)
  local normalized = RouteRecommendations.normalize(route, options)
  if not normalized or not OPTIONAL_SET[mark] then return nil, false end
  local selected = {}
  for _, value in ipairs(normalized.optionalBosses) do selected[value] = true end
  if selected[mark] then selected[mark] = nil
  else
    local selectable = optionCompatibility(normalized.endpoint, mark, options or {})
    if not selectable then return normalized, false end
    selected[mark] = true
  end
  normalized.optionalBosses = {}
  for _, value in ipairs(OPTIONAL_ORDER) do
    if selected[value] then normalized.optionalBosses[#normalized.optionalBosses + 1] = value end
  end
  return normalized, true
end

function RouteRecommendations.refreshMembers(route, goals, options)
  options = options or {}
  local normalized = RouteRecommendations.normalize(route, options)
  if not normalized then return nil end
  options.difficulty = tonumber(options.difficulty) or 1
  options.completionStore = options.completionStore or {}
  options.currentPlayers = options.currentPlayers or {}
  options.isCompleted = options.isCompleted or function() return false end
  options.isTracked = options.isTracked or function() return false end
  local matched, catalogOrder = {}, {}
  for index, goal in ipairs(goals or {}) do
    catalogOrder[goal.id] = index
    if not options.isCompleted(goal) and not options.isTracked(goal.id)
      and routeCompatible(goal, normalized, options) then
      local relevance = CharacterRelevance.classify(goal, options.relevanceContext)
      if relevance == "current" or relevance == "general" then matched[#matched + 1] = goal end
    end
  end
  normalized.memberIds = sortGoalIds(matched, catalogOrder)
  normalized.priority = strongestPriority(matched)
  return normalized
end

local PROCESS = {
  mother={ zh={"地下室I/II","下水道/污水井I/II（菜刀碎片1）","矿洞/灰坑I/II（菜刀碎片2）",
      "陵墓/炼狱I/II（Mom与肉门）","尸宫I/II","母亲"},
    en={"Basement I/II","Downpour/Dross I/II (Knife Piece 1)","Mines/Ashpit I/II (Knife Piece 2)",
      "Mausoleum/Gehenna I/II (Mom and flesh door)","Corpse I/II","Mother"} },
  lamb={ zh={"地下室","洞穴","深牢II（底片）","子宫II","阴间（撒但）","暗室（羔羊）"},
    en={"Basement","Caves","Depths II (The Negative)","Womb II","Sheol (Satan)","Dark Room (The Lamb)"} },
  blue_baby={ zh={"地下室","洞穴","深牢II（全家福）","子宫II","教堂（以撒）","宝箱层（???）"},
    en={"Basement","Caves","Depths II (The Polaroid)","Womb II","Cathedral (Isaac)","Chest (???)"} },
  beast={ zh={"地下室","洞穴","深牢II（奇怪门）","陵墓II（爸爸的便条）","逆行","Home（教条与祸兽）"},
    en={"Basement","Caves","Depths II (Strange Door)","Mausoleum II (Dad's Note)","Ascent","Home (Dogma and The Beast)"} },
  greed={ zh={"地下室","洞穴","深牢","子宫","阴间","商店层","贪婪"},
    en={"Basement","Caves","Depths","Womb","Sheol","The Shop","Ultra Greed"} },
  greedier={ zh={"地下室","洞穴","深牢","子宫","阴间","商店层","贪婪","超级贪婪"},
    en={"Basement","Caves","Depths","Womb","Sheol","The Shop","Ultra Greed","Ultra Greedier"} }
}

local PROCESS_MARKS = {
  mother={nil,nil,nil,nil,nil,"MOTHER"},
  lamb={nil,nil,nil,"MOMS_HEART","SATAN","LAMB"},
  blue_baby={nil,nil,nil,"MOMS_HEART","ISAAC","BLUE_BABY"},
  beast={nil,nil,nil,nil,nil,"BEAST"},
  greed={nil,nil,nil,nil,nil,nil,"ULTRA_GREED"},
  greedier={nil,nil,nil,nil,nil,nil,nil,"ULTRA_GREED"}
}

function RouteRecommendations.fullProcess(route, language, options)
  local endpoint = route.endpoint or route.family
  local definition = PROCESS[endpoint]
  local source = definition and (definition[language] or definition.en) or {}
  local result = {}
  for index, value in ipairs(source) do
    result[#result + 1] = { text=value, mark=(PROCESS_MARKS[endpoint] or {})[index] }
  end
  local selected = {}
  for _, mark in ipairs(route.optionalBosses or {}) do selected[mark] = true end
  local added = 0
  for _, mark in ipairs({ "BOSS_RUSH", "HUSH", "MEGA_SATAN", "DELIRIUM" }) do
    if selected[mark] then
      local insertAt = #result + 1
      if mark == "BOSS_RUSH" then insertAt = math.min(#result + 1,
        (endpoint == "mother" and 5 or 4) + added)
      elseif mark == "HUSH" and (endpoint == "lamb" or endpoint == "blue_baby") then
        insertAt = math.min(#result + 1, 5 + added)
      end
      table.insert(result, insertAt, { mark=mark, optional=true,
        text=CompletionMarks.label(mark, language)
          .. (language == "zh" and "（可选）" or " (optional)") })
      added = added + 1
    end
  end
  local rendered = {}
  local currentStage = (options and options.context and options.context.stage) or 1
  local currentIndex = math.max(1, math.min(#result,
    math.floor((currentStage + 1) / 2)))
  local completedBosses = options and options.completedBosses or {}
  local endpointMark = RouteRecommendations.ENDPOINTS[endpoint]
    and RouteRecommendations.ENDPOINTS[endpoint].endpointMark
  for index, entry in ipairs(result) do
    local state = index < currentIndex and "completed" or index == currentIndex and "current" or "future"
    if entry.mark and completedBosses[entry.mark] then state = "completed" end
    local optionSelectable = not entry.optional or optionCompatibility(endpoint,
      entry.mark, { context=options and options.context or {} })
    if state ~= "completed" and entry.optional and not optionSelectable then
      state = "blocked"
    elseif state ~= "completed" and entry.optional and entry.mark == "DELIRIUM"
      and route.confirmedThrough ~= "DELIRIUM" then
      state = "conditional"
    elseif entry.mark == endpointMark and (PREFIX_ORDER[route.confirmedThrough] or 0)
      < (PREFIX_ORDER[endpointMark] or 0) then state = "blocked" end
    local prefix = options and ({ completed="[x] ", current="> ", future="[ ] ",
      conditional="[?] ", blocked="[!] " })[state] or ""
    rendered[#rendered + 1] = prefix .. entry.text
  end
  return rendered
end

function RouteRecommendations.extension(route, context, language)
  if not route then return nil end
  local endpoint = route.endpoint or route.family
  local wantsDelirium = false
  for _, mark in ipairs(route.optionalBosses or {}) do
    if mark == "DELIRIUM" then wantsDelirium = true end
  end
  if wantsDelirium and context and context.voidPortal
    and route.confirmedThrough ~= "DELIRIUM" then
    return { target="DELIRIUM",
      source=language == "zh" and "虚空入口" or "Void portal",
      label=CompletionMarks.label("DELIRIUM", language) }
  end
  local target = stablePrefix(endpoint, context)
  local current = route.confirmedThrough or target
  if (PREFIX_ORDER[target] or 0) <= (PREFIX_ORDER[current] or 0) then return nil end
  local source = context and context.devilExit and (language == "zh" and "恶魔房入口" or "Devil Room entrance")
    or context and context.angelExit and (language == "zh" and "天使房入口" or "Angel Room entrance")
    or context and context.voidPortal and (language == "zh" and "虚空入口" or "Void portal")
    or (language == "zh" and "可靠入口或通行物" or "reliable entrance or route item")
  return { target=target, source=source,
    label=CompletionMarks.label(target, language) }
end

function RouteRecommendations.confirmExtension(route, extension)
  if not route or not extension or not extension.target then return false end
  route.confirmedThrough = extension.target
  return true
end

function RouteRecommendations.syncActualProgress(route, context)
  if not route or not context then return false end
  local endpoint = route.endpoint or route.family
  local stage = tonumber(context.stage) or 0
  local target
  if endpoint == "lamb" and context.stageType == enum(StageType,"STAGETYPE_ORIGINAL",0) then
    target = stage >= enum(LevelStage,"STAGE6",11) and "LAMB"
      or stage >= enum(LevelStage,"STAGE5",10) and "SATAN" or nil
  elseif endpoint == "blue_baby" and context.stageType == enum(StageType,"STAGETYPE_WOTL",1) then
    target = stage >= enum(LevelStage,"STAGE6",11) and "BLUE_BABY"
      or stage >= enum(LevelStage,"STAGE5",10) and "ISAAC" or nil
  elseif endpoint == "mother" and (context.stageType == REP_A or context.stageType == REP_B)
    and stage >= enum(LevelStage,"STAGE4_1",7) then target = "MOTHER"
  elseif endpoint == "beast" and (context.ascent
    or stage == enum(LevelStage,"STAGE8",13)) then target = "BEAST"
  end
  if stage == enum(LevelStage,"STAGE7",12) then
    for _, mark in ipairs(route.optionalBosses or {}) do
      if mark == "DELIRIUM" then target = "DELIRIUM" end
    end
  end
  if target and (PREFIX_ORDER[target] or 0)
    > (PREFIX_ORDER[route.confirmedThrough] or 0) then
    route.confirmedThrough = target
    return true
  end
  return false
end

function RouteRecommendations.remedies(route, context, language)
  if not route then return {} end
  context = context or {}
  local endpoint = route.endpoint or route.family
  local current = route.confirmedThrough or stablePrefix(endpoint, context)
  local result = {}
  local function add(key, zh, en, possible)
    local available = context.aids and context.aids[key]
    result[#result + 1] = { text=language == "zh" and zh or en,
      status=available and "available" or (possible == false and "expired" or "possible") }
  end
  if endpoint == "lamb" and current ~= "LAMB" then
    add("negative", "取得底片进入暗室", "Take The Negative to enter Dark Room",
      (context.stage or 0) <= STAGE.DEPTHS2)
    add("deeper", "在子宫II制造阴间入口", "Create a Sheol entrance in Womb II",
      (context.stage or 0) <= STAGE.WOMB2)
    add("ehwaz", "使用艾瓦兹制造阴间入口", "Use Ehwaz to create a Sheol entrance",
      (context.stage or 0) <= STAGE.WOMB2)
  elseif endpoint == "blue_baby" and current ~= "BLUE_BABY" then
    add("polaroid", "取得全家福进入宝箱层", "Take The Polaroid to enter Chest",
      (context.stage or 0) <= STAGE.DEPTHS2)
  elseif endpoint == "mother" and current ~= "MOTHER" then
    add("knife1", "取得菜刀碎片1", "Take Knife Piece 1",
      context.secretExitUnlocked ~= false and (context.stage or 0) <= STAGE.BASEMENT2)
    add("knife2", "取得菜刀碎片2", "Take Knife Piece 2",
      context.secretExitUnlocked ~= false and (context.stage or 0) <= STAGE.CAVES2)
    add("sharp_key", "使用尖头钥匙开启肉门", "Use Sharp Key on the flesh door",
      context.secretExitUnlocked ~= false)
    add("soul_cain", "使用该隐魂石开启肉门", "Use Soul of Cain on the flesh door",
      context.secretExitUnlocked ~= false)
    add("cracked_orb", "使用碎裂的宝珠开启肉门", "Use Cracked Orb on the flesh door",
      context.secretExitUnlocked ~= false)
  elseif endpoint == "beast" and current ~= "BEAST" then
    add("polaroid", "用全家福开启奇怪门", "Open the Strange Door with The Polaroid",
      context.strangeDoorUnlocked ~= false)
    add("negative", "用底片开启奇怪门", "Open the Strange Door with The Negative",
      context.strangeDoorUnlocked ~= false)
    add("faded_polaroid", "用褪色的全家福开启奇怪门", "Open the Strange Door with Faded Polaroid",
      context.strangeDoorUnlocked ~= false)
  end
  local selected = {}
  for _, mark in ipairs(route.optionalBosses or {}) do selected[mark] = true end
  if selected.BOSS_RUSH then
    add("mama_mega", "用超级妈妈！开启 Boss Rush 入口",
      "Use Mama Mega! to open the Boss Rush entrance", (context.stage or 0) <= STAGE.DEPTHS2)
  end
  if selected.HUSH then
    add("strange_key", "携带奇怪的钥匙开启蓝色子宫入口",
      "Carry Strange Key to open the Blue Womb entrance", (context.stage or 0) <= STAGE.WOMB2)
    add("mama_mega", "用超级妈妈！开启蓝色子宫入口",
      "Use Mama Mega! to open the Blue Womb entrance", (context.stage or 0) <= STAGE.WOMB2)
  end
  if selected.DELIRIUM then
    result[#result + 1] = { text=language == "zh" and "进入现场出现的虚空入口"
        or "Enter a live Void portal",
      status=context.voidPortal and "available" or "possible" }
  end
  if selected.MEGA_SATAN then
    add("key1", "取得钥匙碎片1", "Take Key Piece 1")
    add("key2", "取得钥匙碎片2", "Take Key Piece 2")
    add("dads_key", "用爸爸的钥匙开启金门", "Open the golden door with Dad's Key")
    add("jail_free", "用免费出狱卡开启金门",
      "Open the golden door with Get Out of Jail Free")
    add("mr_me", "用店长先生！开启金门", "Open the golden door with Mr. ME!")
  end
  local resetCanRecover = endpoint ~= "mother" and endpoint ~= "beast"
    or endpoint == "mother" and context.secretExitUnlocked ~= false
    or endpoint == "beast" and context.strangeDoorUnlocked ~= false
  add("r_key", "使用 R Key 重置路线", "Use R Key to restart the route", resetCanRecover)
  return result
end

function RouteRecommendations.isComplete(route, completedBosses)
  if not route then return false end
  local endpoint = RouteRecommendations.ENDPOINTS[route.endpoint or route.family]
  if not endpoint or not completedBosses or not completedBosses[endpoint.endpointMark] then return false end
  for _, mark in ipairs(route.optionalBosses or {}) do
    if not completedBosses[mark] then return false end
  end
  return true
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
  local marks = marksForRoute(route or {})
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
  for mark in pairs(options.completedBosses or {}) do marks[mark] = nil end
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

  local endpoint = route.endpoint or route.family
  if endpoint == "mother" and marks.MOTHER and not markFailed(result, "MOTHER") then
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
  if endpoint == "blue_baby" and next(marks) ~= nil
    and context.stage == STAGE.DEPTHS2 and context.routeEvents
    and context.routeEvents.momDefeated and not held.polaroid then
    addUnique(warnings, seen, "photo", localized(language,
      "下层前先拾取全家福。", "Take The Polaroid before going down."))
  end
  if endpoint == "lamb" and next(marks) ~= nil
    and context.stage == STAGE.DEPTHS2 and context.routeEvents
    and context.routeEvents.momDefeated and not held.negative then
    addUnique(warnings, seen, "photo", localized(language,
      "下层前先拾取底片。", "Take The Negative before going down."))
  end
  if endpoint == "beast" and marks.BEAST and not markFailed(result, "BEAST")
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
  local familyByMark = { MOTHER="mother", BEAST="beast", BLUE_BABY="blue_baby", LAMB="lamb" }
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
  local endpointKey = route and (route.endpoint or route.family)
  local family = endpointKey and RouteRecommendations.ENDPOINTS[endpointKey]
  local stepOrder, lastOrder = {}, 0
  for index, mark in ipairs(family and family.steps or {}) do
    stepOrder[mark], lastOrder = index, math.max(lastOrder, index)
  end
  for index, mark in ipairs(OPTIONAL_ORDER) do
    if stepOrder[mark] == nil then stepOrder[mark] = lastOrder + index end
  end
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
  local plannedMarks = {}
  local primaryMark = route and (route.confirmedThrough or stablePrefix(endpointKey, options.context))
  if primaryMark and not (options.completedBosses and options.completedBosses[primaryMark]) then
    plannedMarks[#plannedMarks + 1] = primaryMark
  end
  for _, mark in ipairs(route and route.optionalBosses or {}) do
    if not (options.completedBosses and options.completedBosses[mark]) then
      plannedMarks[#plannedMarks + 1] = mark
    end
  end
  for _, mark in ipairs(plannedMarks) do
    local evaluation = Routes.evaluate({ completionRequirements={{ mark=mark,
      difficulty=family and family.difficulty or 1 }} }, options.context, {}, options.language)
    if evaluation then
      result.memberResults["route:" .. mark] = evaluation
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
  result.remedies = RouteRecommendations.remedies(route, options.context, options.language)
  result.extension = RouteRecommendations.extension(route, options.context, options.language)
  local desiredMark = family and family.endpointMark
  if desiredMark and (PREFIX_ORDER[primaryMark] or 0) < (PREFIX_ORDER[desiredMark] or 0) then
    result.missed = localized(options.language,
      "当前稳定路线止于" .. CompletionMarks.label(primaryMark, options.language),
      "The stable route currently ends at " .. CompletionMarks.label(primaryMark, options.language))
    result.severity = "warning"
  end
  if primaryMark and markFailed(result, primaryMark) then
    result.missed = localized(options.language,
      "已错过" .. CompletionMarks.label(primaryMark, options.language),
      CompletionMarks.label(primaryMark, options.language) .. " was missed")
    result.severity = "warning"
  end
  for _, mark in ipairs(route and route.optionalBosses or {}) do
    if markFailed(result, mark) then
      result.missed = localized(options.language,
        "已错过" .. CompletionMarks.label(mark, options.language),
        CompletionMarks.label(mark, options.language) .. " was missed")
      result.severity = "warning"
      break
    end
  end
  return result
end

return RouteRecommendations
