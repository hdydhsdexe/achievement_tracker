local json = require("json")
local Storage = {}

local function defaults()
  return {
    schemaVersion = 1,
    language = "en",
    maxTracked = 3,
    tracked = { "boss_rush", "hush" },
    hud = { x = 18, y = 82, visible = true },
    manuallyCompleted = {},
    activeRun = nil
  }
end

function Storage.load(mod)
  local data = defaults()
  if not mod:HasData() then return data end
  local ok, decoded = pcall(json.decode, mod:LoadData())
  if not ok or type(decoded) ~= "table" then return data end
  if decoded.language == "zh" or decoded.language == "en" then data.language = decoded.language end
  if type(decoded.maxTracked) == "number" then data.maxTracked = math.max(1, math.min(6, decoded.maxTracked)) end
  if type(decoded.tracked) == "table" then data.tracked = decoded.tracked end
  if type(decoded.hud) == "table" then
    data.hud.x = tonumber(decoded.hud.x) or data.hud.x
    data.hud.y = tonumber(decoded.hud.y) or data.hud.y
    data.hud.visible = decoded.hud.visible ~= false
  end
  if type(decoded.manuallyCompleted) == "table" then data.manuallyCompleted = decoded.manuallyCompleted end
  if type(decoded.activeRun) == "table" then data.activeRun = decoded.activeRun end
  return data
end

function Storage.save(mod, data)
  data.schemaVersion = 1
  mod:SaveData(json.encode(data))
end

return Storage
