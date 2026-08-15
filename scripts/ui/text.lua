local Text = {}
local bundledFont = Font()
local FONT_NATIVE_PIXELS = 16

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
  return "../mods/achievement_tracker/"
end

local modPath = Text.GetCurrentModPath()
bundledFont:Load(modPath .. "resources/font/achievement_lanapixel.fnt", "")

local ui = {
  zh = {
    title = "成就条件追踪", controls = "F3：选择目标  |  F4：隐藏",
    menuTitle = "成就奖励", tracked = "个正在追踪",
    remaining = "剩余", failed = "条件已失效", language = "中文",
    completionCondition = "完成条件", unlockReward = "解锁奖励",
    completed = "已完成", unconfirmed = "未确认", rewardId = "编号",
    availableAfterTransformation = "转换后可完成",
    filterHint = "Tab 分类  / 搜索", pauseUnavailable = "当前环境无法暂停，游戏仍在运行",
    multiplayerRealtime = "多人模式：游戏仍在运行", emptyFilter = "该分类暂无成就",
    searchPrompt = "搜索", searchResults = "%d 个结果", emptySearch = "没有匹配的成就",
    controlsMenu = "方向键选择  Enter/Space追踪  /搜索  Esc关闭",
    controlsSearch = "输入英文/数字  Backspace删除  Enter完成  Esc清空",
    filterNames = { all="全部", collectible="道具", trinket="饰品", card="卡牌", other="其他" },
    rewardKinds = { collectible="道具", trinket="饰品", card="卡牌", character="角色", area="区域", challenge="挑战", feature="机制", other="其他" }
  },
  en = {
    title = "ACHIEVEMENT CONDITIONS", controls = "F3: goals  |  F4: hide",
    menuTitle = "ACHIEVEMENT REWARDS", tracked = "tracked",
    remaining = "remaining", failed = "condition lost", language = "English",
    completionCondition = "CONDITION", unlockReward = "UNLOCKS",
    completed = "completed", unconfirmed = "unconfirmed", rewardId = "ID",
    availableAfterTransformation = "available after transformation",
    filterHint = "Tab filter  / search", pauseUnavailable = "Pause unavailable; game is still running",
    multiplayerRealtime = "Multiplayer: game is still running", emptyFilter = "No achievements in this category",
    searchPrompt = "SEARCH", searchResults = "%d results", emptySearch = "No matching achievements",
    controlsMenu = "Arrows select  Enter/Space track  / search  Esc close",
    controlsSearch = "Type letters/numbers  Backspace delete  Enter done  Esc clear",
    filterNames = { all="All", collectible="Items", trinket="Trinkets", card="Cards", other="Other" },
    rewardKinds = { collectible="Item", trinket="Trinket", card="Card", character="Character", area="Area", challenge="Challenge", feature="Feature", other="Other" }
  }
}

function Text.labels(language) return ui[language] or ui.en end

function Text.resolveLanguage(language)
  return language
end

function Text.pixel(value)
  return roundPixel(tonumber(value) or 0)
end

function Text.scaleForPixels(pixelSize)
  return math.max(1, Text.pixel(pixelSize)) / FONT_NATIVE_PIXELS
end

function Text.snapScale(scale)
  return Text.scaleForPixels((tonumber(scale) or 1) * FONT_NATIVE_PIXELS)
end

function Text.draw(value, x, y, scale, color, language, boxWidth, center)
  local tint = color or KColor(1, 1, 1, 1)
  local drawScale = Text.snapScale(scale)
  local drawWidth = boxWidth and Text.pixel(boxWidth) or 0
  bundledFont:DrawStringScaledUTF8(tostring(value), Text.pixel(x), Text.pixel(y),
    drawScale, drawScale, tint, drawWidth, center == true)
end

function Text.width(value, scale)
  return bundledFont:GetStringWidthUTF8(tostring(value)) * Text.snapScale(scale)
end

function Text.ellipsize(value, maxWidth, scale)
  local text = tostring(value or "")
  if Text.width(text, scale) <= maxWidth then return text end
  local glyphs = {}
  if utf8 and utf8.codes then
    for _, codepoint in utf8.codes(text) do table.insert(glyphs, utf8.char(codepoint)) end
  else
    for index = 1, #text do table.insert(glyphs, string.sub(text, index, index)) end
  end
  local suffix = "..."
  while #glyphs > 0 and Text.width(table.concat(glyphs) .. suffix, scale) > maxWidth do
    table.remove(glyphs)
  end
  return table.concat(glyphs) .. suffix
end

return Text
