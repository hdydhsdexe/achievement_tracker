local Text = {}
local latinFont = Font()
local cjkFont = Font()
latinFont:Load("font/terminus8.fnt")
cjkFont:Load("font/lanapixel.fnt")

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


function Text.draw(value, x, y, scale, color, language, boxWidth, center)
  local font = language == "zh" and cjkFont or latinFont
  local tint = color or KColor(1, 1, 1, 1)
  font:DrawStringScaledUTF8(tostring(value), x, y, scale, scale, tint, boxWidth or 0, center == true)
end


return Text
