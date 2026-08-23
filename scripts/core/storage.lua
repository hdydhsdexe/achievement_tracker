local json = require("json")
local Storage = {}
local MAX_ACHIEVEMENT_COUNT = 16384
local MAX_MOD_SAVE_DATA_BYTES = 4 * 1024 * 1024
local NATIVE_FONT_PIXELS = { [11]=true, [22]=true, [33]=true }
local COMPLETION_MARKS = {
  MOMS_HEART=true, ISAAC=true, SATAN=true, BOSS_RUSH=true, BLUE_BABY=true,
  LAMB=true, MEGA_SATAN=true, ULTRA_GREED=true, HUSH=true, DELIRIUM=true,
  MOTHER=true, BEAST=true
}

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

local function normalizeCompletionMarks(snapshot)
  local normalized, playerCount = {}, 0
  if type(snapshot) ~= "table" then return normalized end
  for player, marks in pairs(snapshot) do
    local playerNumber = tonumber(player)
    if playerCount < 64 and isInteger(playerNumber) and playerNumber >= 0 and playerNumber <= 1024
      and type(marks) == "table" then
      local clean = {}
      for mark, value in pairs(marks) do
        value = tonumber(value)
        if COMPLETION_MARKS[mark] and isInteger(value) and value >= 1 and value <= 2 then
          clean[mark] = value
        end
      end
      if next(clean) ~= nil then
        normalized[tostring(playerNumber)] = clean
        playerCount = playerCount + 1
      end
    end
  end
  return normalized
end

local function migrateHudFontPixels(decoded)
  local schemaVersion = tonumber(decoded.schemaVersion)
  if schemaVersion and schemaVersion >= 8 and type(decoded.hud) == "table"
    and NATIVE_FONT_PIXELS[decoded.hud.fontPixels] then
    return decoded.hud.fontPixels
  end
  local oldScale = type(decoded.hud) == "table" and tonumber(decoded.hud.fontScale) or 1
  oldScale = math.max(0.5, math.min(2, oldScale or 1))
  local oldPixels = math.floor(oldScale * 16 + 0.5)
  return oldPixels >= 22 and 22 or 11
end

local function normalizeHudLineSpacing(value)
  value = tonumber(value)
  if not value then return 0 end
  return math.max(0, math.min(8, math.floor(value + 0.5)))
end

local function migrateF3FontPixels(decoded)
  local schemaVersion = tonumber(decoded.schemaVersion)
  if schemaVersion and schemaVersion >= 7
    and type(decoded.f3) == "table" and NATIVE_FONT_PIXELS[decoded.f3.fontPixels] then
    return decoded.f3.fontPixels
  end
  return 11
end

local function defaults()
  return {
    schemaVersion = 9,
    language = "zh",
    maxTracked = 3,
    tracked = {},
    hud = { x = 18, y = 82, fontPixels = 11, lineSpacingPixels = 0, visible = true },
    f3 = { fontPixels = 11 },
    manuallyCompleted = {},
    observedCompleted = {},
    achievementImport = nil,
    completionMarks = {},
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
    data.hud.lineSpacingPixels = normalizeHudLineSpacing(decoded.hud.lineSpacingPixels)
    data.hud.visible = decoded.hud.visible ~= false
  end
  data.hud.fontPixels = migrateHudFontPixels(decoded)
  data.f3.fontPixels = migrateF3FontPixels(decoded)
  if type(decoded.manuallyCompleted) == "table" then data.manuallyCompleted = decoded.manuallyCompleted end
  if type(decoded.observedCompleted) == "table" then data.observedCompleted = decoded.observedCompleted end
  data.completionMarks = normalizeCompletionMarks(decoded.completionMarks)
  data.achievementImport = normalizeAchievementImport(decoded.achievementImport)
  if type(decoded.activeRun) == "table" then data.activeRun = decoded.activeRun end
  return data
end

function Storage.save(mod, data)
  data.schemaVersion = 9
  data.hud = type(data.hud) == "table" and data.hud
    or { x = 18, y = 82, fontPixels = 11, lineSpacingPixels = 0, visible = true }
  if not NATIVE_FONT_PIXELS[data.hud.fontPixels] then data.hud.fontPixels = 11 end
  data.hud.lineSpacingPixels = normalizeHudLineSpacing(data.hud.lineSpacingPixels)
  data.hud["fontScale"] = nil
  data.f3 = type(data.f3) == "table" and data.f3 or { fontPixels = 11 }
  if not NATIVE_FONT_PIXELS[data.f3.fontPixels] then data.f3.fontPixels = 11 end
  data.achievementImport = normalizeAchievementImport(data.achievementImport)
  data.completionMarks = normalizeCompletionMarks(data.completionMarks)
  mod:SaveData(json.encode(data))
end

return Storage
