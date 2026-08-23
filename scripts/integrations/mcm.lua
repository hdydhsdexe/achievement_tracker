local Catalog = require("scripts.data.goals")
local Tracker = require("scripts.core.tracker")
local Mcm = {}
local NATIVE_PIXELS_BY_INDEX = { [1]=11, [2]=22, [3]=33 }

local function languageIndex(language) return language == "zh" and 1 or 2 end
local function languageName(index) return index == 1 and "中文" or "English" end
local function fontIndex(pixels) return pixels == 11 and 1 or (pixels == 33 and 3 or 2) end
local function fontName(pixels)
  return pixels == 11 and "Small / 小"
    or (pixels == 33 and "Large / 大" or "Standard / 标准")
end

local function addNumber(modName, category, label, current, onChange, minimum, maximum, step, suffix)
  ModConfigMenu.AddSetting(modName, category, {
    Type = ModConfigMenu.OptionType.NUMBER,
    CurrentSetting = current,
    Minimum = minimum,
    Maximum = maximum,
    ModifyBy = step,
    Display = function()
      local value = current()
      return label .. ": " .. tostring(value) .. (suffix or "")
    end,
    OnChange = onChange
  })
end

local function addFontSize(modName, category, label, current, onChange)
  ModConfigMenu.AddSetting(modName, category, {
    Type = ModConfigMenu.OptionType.NUMBER,
    CurrentSetting = function() return fontIndex(current()) end,
    Minimum = 1,
    Maximum = 3,
    ModifyBy = 1,
    Display = function() return label .. ": " .. fontName(current()) end,
    OnChange = function(value) onChange(NATIVE_PIXELS_BY_INDEX[value] or 11) end
  })
end

function Mcm.setup(state, save)
  if ModConfigMenu == nil then return false end
  local modName = "Achievement Tracker"
  local general = "General / 常规"
  ModConfigMenu.RemoveCategory(modName)
  ModConfigMenu.AddText(modName, general, function() return "Achievement Tracker v0.7.2 / 成就条件追踪" end)

  ModConfigMenu.AddSetting(modName, general, {
    Type = ModConfigMenu.OptionType.BOOLEAN,
    CurrentSetting = function() return state.settings.hud.visible end,
    Display = function()
      return (state.settings.language == "zh" and "显示追踪面板: " or "Show HUD: ")
        .. (state.settings.hud.visible and "On" or "Off")
    end,
    OnChange = function(value) state.settings.hud.visible=value; save() end,
    Info = { "F3 opens the in-run selector; F4 toggles the HUD.", "F3打开局内选择菜单，F4显示或隐藏面板。" }
  })

  addNumber(modName, general, "Language / 语言",
    function() return languageIndex(state.settings.language) end,
    function(value) state.settings.language = value == 1 and "zh" or "en"; save() end,
    1, 2, 1)
  -- Override the generic numeric display with a friendly language name.
  ModConfigMenu.AddText(modName, general, function()
    return "Current language / 当前语言: " .. languageName(languageIndex(state.settings.language))
  end)

  addFontSize(modName, general, "HUD font size / HUD 字体大小",
    function() return state.settings.hud.fontPixels end,
    function(pixels)
      state.settings.hud.fontPixels = pixels
      save()
    end)
  addNumber(modName, general, "HUD line spacing / HUD 行间距",
    function() return state.settings.hud.lineSpacingPixels end,
    function(value) state.settings.hud.lineSpacingPixels=value; save() end,
    0, 8, 1, "px")
  addFontSize(modName, general, "F3 font size / F3 字体大小",
    function() return state.settings.f3.fontPixels end,
    function(pixels)
      state.settings.f3.fontPixels = pixels
      save()
    end)
  addNumber(modName, general, "HUD X / 横向位置",
    function() return state.settings.hud.x end,
    function(value) state.settings.hud.x=math.max(0, math.min(600, value)); save() end,
    0, 600, 5)
  addNumber(modName, general, "HUD Y / 纵向位置",
    function() return state.settings.hud.y end,
    function(value) state.settings.hud.y=math.max(0, math.min(400, value)); save() end,
    0, 400, 5)

  for _, goalValue in ipairs(Catalog.goals) do
    local goal = goalValue
    ModConfigMenu.AddSetting(modName, "Goals / 目标", {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function() return Tracker.contains(state.tracker, goal.id) end,
      Display = function() return Catalog.text(goal, state.settings.language).name end,
      OnChange = function()
        Tracker.toggle(state.tracker, goal.id)
        state.settings.tracked=state.tracker.ids
        save()
      end,
      Info = { Catalog.text(goal, state.settings.language).detail }
    })
  end
  return true
end

return Mcm
