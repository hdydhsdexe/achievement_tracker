local Text = {}
local latinFont = Font()
local cjkFont = Font()
latinFont:Load("font/terminus8.fnt", "")

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

local function tryLoadFont(font, path)
  font:Load(path, "")
  return font:IsLoaded()
end

local bundledFontPath = Text.GetCurrentModPath() .. "resources/font/achievement_zh.fnt"
local cjkLoaded = tryLoadFont(cjkFont, bundledFontPath)
if not cjkLoaded then
  cjkLoaded = tryLoadFont(cjkFont, "../mods/achievement_tracker/resources/font/achievement_zh.fnt")
end

local ui = {
  zh = {
    title = "成就条件追踪", controls = "F3：选择目标  |  F4：隐藏",
    menuTitle = "选择追踪目标（确认键切换，Esc关闭）", tracked = "个正在追踪",
    remaining = "剩余", failed = "条件已失效", language = "中文"
  },
  en = {
    title = "ACHIEVEMENT CONDITIONS", controls = "F3: goals  |  F4: hide",
    menuTitle = "TRACK GOALS (Enter toggle, Esc close)", tracked = "tracked",
    remaining = "remaining", failed = "condition lost", language = "English"
  }
}

function Text.labels(language) return ui[language] or ui.en end

function Text.resolveLanguage(language)
  if language == "zh" and not cjkLoaded then return "en" end
  return language
end

function Text.draw(value, x, y, scale, color, language, boxWidth, center)
  local font = language == "zh" and cjkLoaded and cjkFont or latinFont
  local tint = color or KColor(1, 1, 1, 1)
  font:DrawStringScaledUTF8(tostring(value), x, y, scale, scale, tint, boxWidth or 0, center == true)
end

return Text
