local Text = {}
local latinFont = Font()
local cjkFont = Font()
latinFont:Load("font/terminus8.fnt")
local cjkLoaded = false
local cjkFontPaths = {
  -- Repentance Chinese resource pack and Repentance+ Chinese-patch installations.
  "resources-dlc3.zh/font/lanapixel.fnt",
  "font/lanapixel.fnt",
  -- Repentance+ removes the language selector. EID provides a widely-used optional CJK fallback.
  "../mods/external item descriptions_836319872/resources/font/eid_cn_default.fnt",
  "../mods/external item descriptions/resources/font/eid_cn_default.fnt"
}
for _, fontPath in ipairs(cjkFontPaths) do
  if not cjkLoaded then cjkLoaded = cjkFont:Load(fontPath) end
end

local ui = {
  zh = {
    title = "成就条件追踪",
    controls = "F3：选择目标  |  F4：隐藏",
    menuTitle = "选择追踪目标（确认键切换，Esc关闭）",
    tracked = "个正在追踪",
    remaining = "剩余",
    failed = "条件已失效",
    language = "中文"
  },
  en = {
    title = "ACHIEVEMENT CONDITIONS",
    controls = "F3: goals  |  F4: hide",
    menuTitle = "TRACK GOALS (Enter toggle, Esc close)",
    tracked = "tracked",
    remaining = "remaining",
    failed = "condition lost",
    language = "English"
  }
}

function Text.labels(language)
  return ui[language] or ui.en
end

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
