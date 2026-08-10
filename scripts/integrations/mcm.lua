local Catalog = require("scripts.data.goals")
local Tracker = require("scripts.core.tracker")
local Mcm = {}

function Mcm.setup(state, save)
  if ModConfigMenu == nil then return false end
  local modName = "Achievement Tracker"
  ModConfigMenu.RemoveCategory(modName)
  ModConfigMenu.AddText(modName, "General", function() return "Achievement Tracker v0.1.0" end)
  ModConfigMenu.AddSetting(modName, "General", {
    Type = ModConfigMenu.OptionType.BOOLEAN,
    CurrentSetting = function() return state.settings.hud.visible end,
    Display = function() return "Show HUD: " .. (state.settings.hud.visible and "On" or "Off") end,
    OnChange = function(value) state.settings.hud.visible=value; save() end,
    Info = { "F3 also opens the in-run goal selector." }
  })
  for _, goal in ipairs(Catalog.goals) do
    ModConfigMenu.AddSetting(modName, "Goals", {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function() return Tracker.contains(state.tracker, goal.id) end,
      Display = function() return Catalog.text(goal, state.settings.language).name end,
      OnChange = function() Tracker.toggle(state.tracker, goal.id); state.settings.tracked=state.tracker.ids; save() end,
      Info = { Catalog.text(goal, state.settings.language).detail }
    })
  end
  return true
end

return Mcm
