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
    title = "成就条件追踪", controls = "F3：选择目标  |  F4：隐藏",
    menuTitle = "成就奖励", tracked = "个正在追踪",
    remaining = "剩余", failed = "条件已失效", language = "中文",
    unlockReward = "解锁奖励",
    completed = "已完成", currentAvailable = "未确认 · 当前可完成",
    convertiblePending = "未确认 · 转换后可完成",
    otherCharacterPending = "未确认 · 需其他角色",
    currentModeUnavailable = "未确认 · 当前模式不可完成", rewardId = "编号",
    filterHint = "Tab 分类  / 搜索", pauseUnavailable = "当前环境无法暂停，游戏仍在运行",
    multiplayerRealtime = "多人模式：游戏仍在运行", emptyFilter = "该分类暂无成就",
    searchPrompt = "搜索", searchResults = "%d 个结果", emptySearch = "没有匹配的成就",
    controlsMenu = "方向键选择  Enter/Space追踪  /搜索  Esc关闭",
    controlsSearch = "输入英文/数字  Backspace删除  Enter完成  Esc清空",
    filterStatus = "分类：[%s] %d/%d",
    filterNames = { all="全部", collectible="道具", trinket="饰品", card="卡牌",
      character="人物", monster="怪物", area="地点", challenge="挑战",
      pickup="掉落物", world="机器与场景", feature="机制", other="其他" },
    rewardKinds = { collectible="道具", trinket="饰品", card="卡牌", pickup="掉落物",
      slot="机器/乞丐", grid="格子实体", character="人物", monster="怪物",
      area="地点", challenge="挑战", feature="机制", other="其他" }
  },
  en = {
    title = "ACHIEVEMENT CONDITIONS", controls = "F3: goals  |  F4: hide",
    menuTitle = "ACHIEVEMENT REWARDS", tracked = "tracked",
    remaining = "remaining", failed = "condition lost", language = "English",
    unlockReward = "UNLOCKS",
    completed = "completed", currentAvailable = "unconfirmed · available now",
    convertiblePending = "unconfirmed · available after transformation",
    otherCharacterPending = "unconfirmed · requires another character",
    currentModeUnavailable = "unconfirmed · unavailable in current mode", rewardId = "ID",
    filterHint = "Tab filter  / search", pauseUnavailable = "Pause unavailable; game is still running",
    multiplayerRealtime = "Multiplayer: game is still running", emptyFilter = "No achievements in this category",
    searchPrompt = "SEARCH", searchResults = "%d results", emptySearch = "No matching achievements",
    controlsMenu = "Arrows select  Enter/Space track  / search  Esc close",
    controlsSearch = "Type letters/numbers  Backspace delete  Enter done  Esc clear",
    filterStatus = "Filter: [%s] %d/%d",
    filterNames = { all="All", collectible="Items", trinket="Trinkets", card="Cards",
      character="Characters", monster="Monsters", area="Locations", challenge="Challenges",
      pickup="Pickups", world="Machines & Scenery", feature="Features", other="Other" },
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
