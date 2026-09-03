local Text = {}
local pixelFonts = {}
local PIXEL_FONT_SIZES = { 11, 22, 33 }

local function roundPixel(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return math.ceil(value - 0.5)
end

function Text.GetCurrentModPath()
  if debug and debug.getinfo then
    local source = string.sub(debug.getinfo(Text.GetCurrentModPath).source, 2)
    source = string.gsub(source, "\\", "/")
    local root = string.match(source, "^(.*)/scripts/ui/text%.lua$")
    if root then return root .. "/" end
  end
  local _, err = pcall(require, "")
  if type(err) == "string" then
    local _, firstPath = string.find(err, "no file '", 1, true)
    local _, modPathStart = string.find(err, "no file '", (firstPath or 0) + 1, true)
    local modPathEnd = modPathStart and string.find(err, ".lua'", modPathStart, true) or nil
    if modPathStart and modPathEnd then
      local path = string.sub(err, modPathStart + 1, modPathEnd - 1)
      path = string.gsub(path, "\\", "/")
      path = string.gsub(path, "//", "/")
      path = string.gsub(path, ":/", ":\\")
      if string.sub(path, -1) ~= "/" and string.sub(path, -1) ~= "\\" then path = path .. "/" end
      return path
    end
  end
  return "../mods/achievement_tracker_3788047099/"
end

local modPath = Text.GetCurrentModPath()
for _, pixelSize in ipairs(PIXEL_FONT_SIZES) do
  local font = Font()
  font:Load(modPath .. "resources/font/achievement_lanapixel_" .. tostring(pixelSize) .. ".fnt", "")
  pixelFonts[pixelSize] = font
end

local ui = {
  zh = {
    title = "成就条件追踪", controls = "F3：选择目标  |  按住 Tab 查看路线详情  |  F4：隐藏",
    menuTitle = "成就奖励", tracked = "个正在追踪",
    remaining = "剩余", failed = "条件已失效", language = "中文",
    unlockReward = "解锁奖励",
    completed = "已完成", currentAvailable = "未确认 · 本角色可完成",
    generalAvailable = "未确认 · 一般角色可完成",
    convertiblePending = "未确认 · 转换后可完成",
    currentModeUnavailable = "未确认 · 当前条件不可完成", rewardId = "编号",
    filterHint = "Tab 分类  / 搜索", pauseUnavailable = "当前环境无法暂停，游戏仍在运行",
    multiplayerRealtime = "多人模式：游戏仍在运行", emptyFilter = "该分类暂无成就",
    searchPrompt = "搜索", searchResults = "%d 个结果", emptySearch = "没有匹配的成就",
    controlsMenu = "方向键选择  Enter/Space追踪  /搜索  Esc关闭",
    controlsSearch = "输入英文/数字  Backspace删除  Enter完成  Esc清空",
    recommendationPriorities = { strong="强烈推荐", recommended="推荐",
      normal="普通", discouraged="不建议提前解锁" },
    routeRecommendation = "推荐路线", trackedRoute = "正在追踪的路线",
    availableRoute = "可选路线", unavailableRoute = "当前不可选路线",
    routeUnavailable = "当前路线不可进入",
    routeOptionUnavailable = "该可选 Boss 当前无法与终点同局完成",
    routeOption = "可选 Boss", routeOptionSelected = "已加入路线",
    routeProcess = "完整流程", routeStableEnd = "当前稳定终点",
    routeConditional = "等待入口%d个成就", routeDetailPage = "详情 %d/%d",
    routeExtensionPrompt = "发现%s，可继续至%s；按 V 确认",
    routeMissedRemedies = "错过路线入口，按住 Tab 查看补救措施",
    remedyAvailable = "当前可用", remedyPossible = "仍可能取得", remedyExpired = "已失效",
    trackRecommendedRoute = "按 V 追踪整条路线",
    routeProgress = "路线进度 %d/%d", routeMembers = "包含成就",
    routeMemberLocked = "该成就是路线成员，请通过路线行统一取消",
    routeConflict = "与当前路线冲突",
    trackerFull = "追踪栏已满，请先在 F3 取消目标",
    goalCompleted = "%s已完成",
    routeSlot = "占用 1 个追踪位，共 %d 个成就",
    routeScore = "强烈%d · 推荐%d · 普通%d · 不建议%d",
    routeMissed = "已错过%d个成就", routeSelectHint = "Enter/Space切换路线",
    filterStatus = "分类：[%s] %d/%d",
    filterNames = { all="全部", collectible="道具", trinket="饰品", card="卡牌",
      character="人物", monster="怪物", area="地点", challenge="挑战",
      pickup="掉落物", world="机器与场景", feature="机制", route="路线", other="其他" },
    rewardKinds = { collectible="道具", trinket="饰品", card="卡牌", pickup="掉落物",
      slot="机器/乞丐", grid="格子实体", character="人物", monster="怪物",
      area="地点", challenge="挑战", feature="机制", other="其他" }
  },
  en = {
    title = "ACHIEVEMENT CONDITIONS", controls = "F3: goals  |  Hold Tab for route details  |  F4: hide",
    menuTitle = "ACHIEVEMENT REWARDS", tracked = "tracked",
    remaining = "remaining", failed = "condition lost", language = "English",
    unlockReward = "UNLOCKS",
    completed = "completed", currentAvailable = "unconfirmed · available to this character",
    generalAvailable = "unconfirmed · available to any character",
    convertiblePending = "unconfirmed · available after transformation",
    currentModeUnavailable = "unconfirmed · unavailable now", rewardId = "ID",
    filterHint = "Tab filter  / search", pauseUnavailable = "Pause unavailable; game is still running",
    multiplayerRealtime = "Multiplayer: game is still running", emptyFilter = "No achievements in this category",
    searchPrompt = "SEARCH", searchResults = "%d results", emptySearch = "No matching achievements",
    controlsMenu = "Arrows select  Enter/Space track  / search  Esc close",
    controlsSearch = "Type letters/numbers  Backspace delete  Enter done  Esc clear",
    recommendationPriorities = { strong="Strongly recommended", recommended="Recommended",
      normal="Normal", discouraged="Avoid early unlock" },
    routeRecommendation = "Recommended route", trackedRoute = "Tracked route",
    availableRoute = "Available route", unavailableRoute = "Route unavailable now",
    routeUnavailable = "This route cannot be entered now",
    routeOptionUnavailable = "This optional boss cannot be completed with this endpoint now",
    routeOption = "Optional boss", routeOptionSelected = "Added to route",
    routeProcess = "Full route", routeStableEnd = "Stable endpoint",
    routeConditional = "%d achievements await an entrance", routeDetailPage = "Details %d/%d",
    routeExtensionPrompt = "%s found; continue to %s — press V to confirm",
    routeMissedRemedies = "Route entrance missed; hold Tab for recovery options",
    remedyAvailable = "Available now", remedyPossible = "Still obtainable", remedyExpired = "Expired",
    trackRecommendedRoute = "Press V to track the whole route",
    routeProgress = "Route progress %d/%d", routeMembers = "Achievements",
    routeMemberLocked = "This achievement belongs to the route; cancel it from the route row",
    routeConflict = "Conflicts with the tracked route",
    trackerFull = "Tracker is full; cancel a goal in F3 first",
    goalCompleted = "%s completed",
    routeSlot = "Uses 1 tracking slot for %d achievements",
    routeScore = "Strong %d · Recommended %d · Normal %d · Avoid %d",
    routeMissed = "%d achievements missed", routeSelectHint = "Enter/Space to switch route",
    filterStatus = "Filter: [%s] %d/%d",
    filterNames = { all="All", collectible="Items", trinket="Trinkets", card="Cards",
      character="Characters", monster="Monsters", area="Locations", challenge="Challenges",
      pickup="Pickups", world="Machines & Scenery", feature="Features", route="Routes", other="Other" },
    rewardKinds = { collectible="Item", trinket="Trinket", card="Card", pickup="Pickup",
      slot="Machine", grid="Grid entity", character="Character", monster="Monster",
      area="Location", challenge="Challenge", feature="Feature", other="Other" }
  }
}

function Text.labels(language) return ui[language] or ui.en end

function Text.resolveLanguage(language)
  return language
end

function Text.pixel(value)
  return roundPixel(tonumber(value) or 0)
end

local function drawWithFont(font, value, x, y, scale, color, boxWidth, center)
  local tint = color or KColor(1, 1, 1, 1)
  local drawWidth = boxWidth and Text.pixel(boxWidth) or 0
  font:DrawStringScaledUTF8(tostring(value), Text.pixel(x), Text.pixel(y),
    scale, scale, tint, drawWidth, center == true)
end

local function nativePixelSize(pixelSize)
  local value = Text.pixel(pixelSize)
  if pixelFonts[value] then return value end
  return 11
end

function Text.drawPixels(value, x, y, pixelSize, color, language, boxWidth, center)
  local size = nativePixelSize(pixelSize)
  drawWithFont(pixelFonts[size], value, x, y, 1, color, boxWidth, center)
end

function Text.widthPixels(value, pixelSize)
  local size = nativePixelSize(pixelSize)
  return pixelFonts[size]:GetStringWidthUTF8(tostring(value))
end

function Text.lineHeightPixels(pixelSize)
  local size = nativePixelSize(pixelSize)
  return size == 33 and 48 or (size == 22 and 32 or 16)
end

local function glyphs(value)
  local result = {}
  local source = tostring(value or "")
  if utf8 and utf8.codes then
    for _, codepoint in utf8.codes(source) do table.insert(result, utf8.char(codepoint)) end
  else
    for index = 1, #source do table.insert(result, string.sub(source, index, index)) end
  end
  return result
end

function Text.ellipsizePixels(value, maxWidth, pixelSize)
  local text = tostring(value or "")
  if Text.widthPixels(text, pixelSize) <= maxWidth then return text end
  local chars = glyphs(text)
  local suffix = "..."
  while #chars > 0 and Text.widthPixels(table.concat(chars) .. suffix, pixelSize) > maxWidth do
    table.remove(chars)
  end
  return table.concat(chars) .. suffix
end

local function wrapWithWidth(value, maxWidth, measure)
  local lines, current, lastSpace = {}, "", nil
  for _, glyph in ipairs(glyphs(value)) do
    if glyph == "\n" then
      table.insert(lines, current)
      current, lastSpace = "", nil
    else
      local candidate = current .. glyph
      if current ~= "" and measure(candidate) > maxWidth then
        if lastSpace then
          table.insert(lines, string.sub(current, 1, lastSpace - 1))
          local remainder = string.sub(current, lastSpace + 1) .. glyph
          current = string.gsub(remainder, "^ +", "")
        else
          table.insert(lines, current)
          current = glyph == " " and "" or glyph
        end
        lastSpace = string.match(current, ".*() ")
      else
        current = candidate
        if glyph == " " then lastSpace = #current end
      end
    end
  end
  if current ~= "" or #lines == 0 then table.insert(lines, current) end
  return lines
end

function Text.wrapPixels(value, maxWidth, pixelSize)
  return wrapWithWidth(value, maxWidth, function(text) return Text.widthPixels(text, pixelSize) end)
end

return Text
