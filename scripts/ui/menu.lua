local Catalog = require("scripts.data.goals")
local Tracker = require("scripts.core.tracker")
local Menu = {}

function Menu.new()
  return { open=false, cursor=1, offset=1 }
end

local function triggered(key)
  return Input.IsButtonTriggered(key, 0)
end

function Menu.update(state, save)
  if triggered(Keyboard.KEY_F3) then state.menu.open = not state.menu.open end
  if triggered(Keyboard.KEY_F4) then state.settings.hud.visible = not state.settings.hud.visible; save() end
  if not state.menu.open then return end

  local count = #Catalog.goals
  if triggered(Keyboard.KEY_UP) then state.menu.cursor = math.max(1, state.menu.cursor - 1) end
  if triggered(Keyboard.KEY_DOWN) then state.menu.cursor = math.min(count, state.menu.cursor + 1) end
  if triggered(Keyboard.KEY_ENTER) or triggered(Keyboard.KEY_SPACE) then
    Tracker.toggle(state.tracker, Catalog.goals[state.menu.cursor].id)
    state.settings.tracked = state.tracker.ids
    save()
  end
  if triggered(Keyboard.KEY_ESCAPE) then state.menu.open = false end
  state.menu.offset = math.max(1, math.min(state.menu.cursor - 5, count - 10))
end

function Menu.render(state)
  if not state.menu.open then return end
  local x, y = 70, 45
  Isaac.RenderText("TRACK GOALS (Enter toggle, Esc close)", x, y, 1, 0.85, 0.25, 1)
  y = y + 16
  local last = math.min(#Catalog.goals, state.menu.offset + 10)
  for index = state.menu.offset, last do
    local goal = Catalog.goals[index]
    local text = Catalog.text(goal, state.settings.language)
    local cursor = index == state.menu.cursor and ">" or " "
    local tracked = Tracker.contains(state.tracker, goal.id) and "[x]" or "[ ]"
    Isaac.RenderText(cursor .. tracked .. " " .. text.name, x, y, 1, 1, 1, 1)
    y = y + 12
  end
  local selected = Catalog.goals[state.menu.cursor]
  if selected then
    local detail = Catalog.text(selected, state.settings.language).detail
    Isaac.RenderText(detail, x, y + 8, 0.75, 0.75, 0.75, 1)
  end
  Isaac.RenderText(#state.tracker.ids .. "/" .. state.tracker.max .. " tracked", x, y + 22, 0.6, 0.9, 0.6, 1)
end

return Menu
