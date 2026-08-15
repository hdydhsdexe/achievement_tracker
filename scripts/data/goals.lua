local Rewards = require("scripts.core.rewards")
local goals = {}
for _, goal in ipairs(require("scripts.data.achievements_1_50")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_51_100")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_101_200")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_201_300")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_301_400")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_401_500")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_501_600")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_601_641")) do table.insert(goals, goal) end

local legacyGoals = {
  { id="boss_rush", deadline=1200, thresholds={300,120,30}, category="timed", zh={name="Boss Rush",detail="20分钟内击败妈腿并进入大房间"}, en={name="Boss Rush",detail="Defeat Mom and enter the large door before 20:00"} },
  { id="hush", deadline=1800, thresholds={300,120,30}, category="timed", zh={name="Hush",detail="30分钟内击败妈心/它还活着"}, en={name="Hush",detail="Defeat Mom's Heart / It Lives before 30:00"} },
  { id="zip", deadline=1200, thresholds={300,120,30}, category="timed", reward={kind="card",enum="CARD_ACE_OF_DIAMONDS"}, zh={name="Zip!",detail="20分钟内击败羔羊"}, en={name="Zip!",detail="Defeat The Lamb before 20:00"} },
  { id="its_the_key", category="restriction", sensor="no_pickups", reward={kind="card",enum="CARD_ACE_OF_SPADES"}, zh={name="It's the Key",detail="不拾取心、硬币和炸弹并击败羔羊"}, en={name="It's the Key",detail="Defeat The Lamb without taking hearts, coins, or bombs"} },
  { id="mother", category="route", zh={name="Mother路线",detail="下水道→矿洞→陵墓，收集两块刀片"}, en={name="Mother route",detail="Downpour, Mines, Mausoleum; collect both Knife Pieces"} },
  { id="beast", category="route", zh={name="The Beast路线",detail="深层拿传送牌，回到起点并上升"}, en={name="The Beast route",detail="Keep a teleport card, return to the start, then ascend"} },
  { id="mega_satan", category="route", zh={name="Mega Satan",detail="牺牲房或天使房集齐两把钥匙"}, en={name="Mega Satan",detail="Assemble the Key Pieces via Angel or Sacrifice Rooms"} },
  { id="delirium", category="route", zh={name="Delirium",detail="进入虚空并击败精神错乱"}, en={name="Delirium",detail="Reach the Void and defeat Delirium"} },
  { id="greedier", category="completion", zh={name="Greedier",detail="使用当前角色完成困难贪婪模式"}, en={name="Greedier",detail="Clear Greedier Mode with the current character"} },
  { id="tainted_unlock", category="route", zh={name="里角色解锁",detail="上升途中取得红钥匙并打开隐藏衣柜"}, en={name="Tainted character",detail="Take the Red Key during ascent and open the hidden closet"} },
  { id="forgotten_unlock", category="route", reward={kind="character",id=16}, zh={name="遗骸解锁",detail="一分钟内击败一层Boss并完成铲子路线"}, en={name="The Forgotten",detail="Beat the first-floor boss within 1:00 and complete the shovel route"} },
  { id="lost_unlock", category="route", reward={kind="character",id=10}, zh={name="游魂解锁",detail="持寻人启事在献祭房死亡"}, en={name="The Lost",detail="Die in a Sacrifice Room while holding Missing Poster"} },
  { id="keeper_unlock", category="progress", reward={kind="character",id=14}, zh={name="店主解锁",detail="向贪婪机累计投入1000硬币"}, en={name="Keeper",detail="Donate 1000 coins to the Greed Donation Machine"} },
  { id="marbles", category="counter", reward={kind="collectible",enum="COLLECTIBLE_MARBLES"}, zh={name="Marbles",detail="一局中使用5颗Gulp!药丸"}, en={name="Marbles",detail="Use five Gulp! pills in one run"} },
  { id="huge_growth", category="counter", reward={kind="card",enum="CARD_HUGE_GROWTH"}, zh={name="Huge Growth",detail="一局中使体型增大5次"}, en={name="Huge Growth",detail="Increase in size five times during one run"} },
  { id="u_broke_it", category="counter", reward={kind="trinket",enum="TRINKET_BUTTER"}, zh={name="U Broke It!",detail="一局中获得50个道具"}, en={name="U Broke It!",detail="Obtain 50 items in one run"} },
  { id="rerun", category="streak", zh={name="RERUN",detail="连续完成三次胜利圈并开始第四圈"}, en={name="RERUN",detail="Complete three Victory Laps and start the fourth"} },
  { id="daily_streak", category="streak", reward={kind="collectible",enum="COLLECTIBLE_BROKEN_MODEM"}, zh={name="每日挑战连胜",detail="连续完成5次每日挑战"}, en={name="Daily streak",detail="Win five Daily Challenges in a row"} }
}
for _, goal in ipairs(legacyGoals) do table.insert(goals, goal) end

-- Progress metadata lives separately from localized copy so counter goals can be
-- extended without coupling sensors to display text.
local progressGoals = {
  marbles = { key="gulp", target=5 },
  u_broke_it = { key="items", target=50 }
}
for _, goal in ipairs(goals) do
  local progress = progressGoals[goal.id]
  if progress then goal.progressKey=progress.key; goal.target=progress.target end
  goal.reward = Rewards.display(goal)
end

local Catalog = { goals = goals }

function Catalog.get(id)
  for _, goal in ipairs(goals) do if goal.id == id then return goal end end
  return nil
end

function Catalog.text(goal, language)
  return goal[language] or goal.en
end

local SEARCH_KIND_ALIASES = {
  collectible="item collectible active passive familiar",
  trinket="trinket",
  card="card rune soul",
  character="character player",
  area="area location floor room route",
  challenge="challenge",
  feature="feature mechanic",
  other="other reward"
}

local function normalizeSearch(value)
  local normalized = string.lower(tostring(value or ""))
  normalized = string.gsub(normalized, "[%c%p%s]+", " ")
  normalized = string.gsub(normalized, "^%s+", "")
  normalized = string.gsub(normalized, "%s+$", "")
  return normalized
end

local function compactSearch(value)
  return string.gsub(normalizeSearch(value), "%s+", "")
end

local function subsequenceScore(haystack, needle)
  if needle == "" then return 0 end
  local position, skipped = 1, 0
  for index = 1, #needle do
    local found = string.find(haystack, string.sub(needle, index, index), position, true)
    if not found then return nil end
    skipped = skipped + found - position
    position = found + 1
  end
  return skipped
end

local function searchFields(goal)
  local reward = goal.reward or {}
  return {
    { value=goal.zh and goal.zh.name, priority=0 },
    { value=goal.en and goal.en.name, priority=0 },
    { value=goal.zh and goal.zh.detail, priority=100 },
    { value=goal.en and goal.en.detail, priority=100 },
    { value=table.concat({ goal.id or "", tostring(goal.achievementId or "") }, " "),
      priority=200 },
    { value=table.concat({ goal.category or "", reward.kind or "",
        SEARCH_KIND_ALIASES[reward.kind] or "", tostring(reward.id or ""),
        reward.enum or "" }, " "), priority=300 }
  }
end

local function fieldScore(field, term)
  local normalized = normalizeSearch(field.value)
  if normalized == "" then return nil end
  if normalized == term then return field.priority end
  for word in string.gmatch(normalized, "[^%s]+") do
    if word == term then return 1000 + field.priority end
  end
  for word in string.gmatch(normalized, "[^%s]+") do
    if string.sub(word, 1, #term) == term then
      return 2000 + field.priority + #word - #term
    end
  end
  local start = string.find(normalized, term, 1, true)
  if start then return 3000 + field.priority + start - 1 end
  local gap = subsequenceScore(compactSearch(normalized), compactSearch(term))
  if gap then return 4000 + field.priority + gap end
  return nil
end

local function queryTerms(query)
  local terms = {}
  for term in string.gmatch(normalizeSearch(query), "[^%s]+") do
    table.insert(terms, term)
  end
  return terms
end

function Catalog.search(query)
  local results, terms = {}, queryTerms(query)
  for catalogIndex, goal in ipairs(goals) do
    local totalScore, matched = 0, true
    for _, term in ipairs(terms) do
      local best
      for _, field in ipairs(searchFields(goal)) do
        local score = fieldScore(field, term)
        if score and (not best or score < best) then best = score end
      end
      if not best then matched = false; break end
      totalScore = totalScore + best
    end
    if matched then
      table.insert(results, { goal=goal, score=totalScore, catalogIndex=catalogIndex })
    end
  end
  table.sort(results, function(left, right)
    if left.score ~= right.score then return left.score < right.score end
    return left.catalogIndex < right.catalogIndex
  end)
  return results
end

return Catalog
