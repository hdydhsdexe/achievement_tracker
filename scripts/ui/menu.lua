local Catalog = require("scripts.data.goals")
local Text = require("scripts.ui.text")
local Tracker = require("scripts.core.tracker")
local Menu = {}

function Menu.new() return { open=false, cursor=1, offset=1 } end

local function triggered(key) return Input.IsButtonTriggered(key, 0) end

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
  state.menu.offset = math.max(1, math.min(state.menu.cursor - 5, math.max(1, count - 10)))
end

function Menu.render(state)
  if not state.menu.open then return end
  local language = state.settings.language
  local labels = Text.labels(language)
  local scale = state.settings.hud.fontScale
  local lineHeight = math.max(9, math.floor(12 * scale))
  local x, y = 70, 45
  Text.draw(labels.menuTitle, x, y, scale, KColor(1, 0.85, 0.25, 1), language)
  y = y + lineHeight + 4
  local last = math.min(#Catalog.goals, state.menu.offset + 10)
  for index = state.menu.offset, last do
    local goal = Catalog.goals[index]
    local name = Catalog.text(goal, language).name
    local cursor = index == state.menu.cursor and ">" or " "
    local tracked = Tracker.contains(state.tracker, goal.id) and "[x]" or "[ ]"
    Text.draw(cursor .. tracked .. " " .. name, x, y, scale, KColor(1, 1, 1, 1), language)
    y = y + lineHeight
  end
  local selected = Catalog.goals[state.menu.cursor]
  if selected then
    Text.draw(Catalog.text(selected, language).detail, x, y + 8, scale * 0.85, KColor(0.75, 0.75, 0.75, 1), language)
  end
  Text.draw(#state.tracker.ids .. "/" .. state.tracker.max .. " " .. labels.tracked, x, y + lineHeight + 10, scale * 0.8, KColor(0.6, 0.9, 0.6, 1), language)
end

return Menu
