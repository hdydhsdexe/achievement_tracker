local json = require("json")
local Storage = {}
local MAX_ACHIEVEMENT_COUNT = 16384
local MAX_MOD_SAVE_DATA_BYTES = 4 * 1024 * 1024

local function isInteger(value)
  return type(value) == "number" and value == math.floor(value)
end

local function normalizeAchievementImport(snapshot)
  if type(snapshot) ~= "table" or snapshot.formatVersion ~= 1 then return nil end
  if not isInteger(snapshot.saveSlot) or snapshot.saveSlot < 1 or snapshot.saveSlot > 3 then return nil end
  if not isInteger(snapshot.achievementCount) or snapshot.achievementCount <= 0
    or snapshot.achievementCount > MAX_ACHIEVEMENT_COUNT then return nil end
  if type(snapshot.unlockedIds) ~= "table" then return nil end

  local normalizedIds = {}
  local seen = {}
  local entryCount = 0
  local maxIndex = 0
  for index, id in pairs(snapshot.unlockedIds) do
    if not isInteger(index) or index < 1 then return nil end
    if not isInteger(id) or id < 1 or id >= snapshot.achievementCount then return nil end
    if entryCount >= snapshot.achievementCount - 1 then return nil end
    entryCount = entryCount + 1
    maxIndex = math.max(maxIndex, index)
    if not seen[id] then
      seen[id] = true
      normalizedIds[#normalizedIds + 1] = id
    end
  end
  if maxIndex ~= entryCount then return nil end
  table.sort(normalizedIds)

  return {
    formatVersion = 1,
    saveSlot = snapshot.saveSlot,
    achievementCount = snapshot.achievementCount,
    unlockedIds = normalizedIds
  }
end

local function defaults()
  return {
    schemaVersion = 4,
    language = "zh",
    maxTracked = 3,
    tracked = {},
    hud = { x = 18, y = 82, fontScale = 1, visible = true },
    manuallyCompleted = {},
    observedCompleted = {},
    achievementImport = nil,
    activeRun = nil
  }
end

function Storage.load(mod)
  local data = defaults()
  if not mod:HasData() then return data end
  local raw = mod:LoadData()
  if type(raw) ~= "string" or #raw > MAX_MOD_SAVE_DATA_BYTES then return data end
  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" then return data end
  if decoded.language == "zh" or decoded.language == "en" then data.language = decoded.language end
  if type(decoded.maxTracked) == "number" then data.maxTracked = math.max(1, math.min(6, decoded.maxTracked)) end
  if type(decoded.tracked) == "table" then data.tracked = decoded.tracked end
  if type(decoded.hud) == "table" then
    data.hud.x = tonumber(decoded.hud.x) or data.hud.x
    data.hud.y = tonumber(decoded.hud.y) or data.hud.y
    data.hud.fontScale = math.max(0.5, math.min(2, tonumber(decoded.hud.fontScale) or data.hud.fontScale))
    data.hud.visible = decoded.hud.visible ~= false
  end
  if type(decoded.manuallyCompleted) == "table" then data.manuallyCompleted = decoded.manuallyCompleted end
  if type(decoded.observedCompleted) == "table" then data.observedCompleted = decoded.observedCompleted end
  data.achievementImport = normalizeAchievementImport(decoded.achievementImport)
  if type(decoded.activeRun) == "table" then data.activeRun = decoded.activeRun end
  return data
end

function Storage.save(mod, data)
  data.schemaVersion = 4
  data.achievementImport = normalizeAchievementImport(data.achievementImport)
  mod:SaveData(json.encode(data))
end

return Storage
