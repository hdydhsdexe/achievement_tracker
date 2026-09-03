local Tracker = {}

function Tracker.new(maximum, ids, route)
  return { max = maximum or 3, ids = ids or {}, route = route }
end

function Tracker.contains(state, id)
  for _, trackedId in ipairs(state.ids) do
    if trackedId == id then return true end
  end
  return false
end

function Tracker.routeContains(state, id)
  for _, memberId in ipairs(state.route and state.route.memberIds or {}) do
    if memberId == id then return true end
  end
  return false
end

function Tracker.containsAny(state, id)
  return Tracker.contains(state, id) or Tracker.routeContains(state, id)
end

function Tracker.slotCount(state)
  return #state.ids + (state.route and 1 or 0)
end

function Tracker.allIds(state)
  local result, seen = {}, {}
  for _, id in ipairs(state.ids) do
    if not seen[id] then result[#result + 1], seen[id] = id, true end
  end
  for _, id in ipairs(state.route and state.route.memberIds or {}) do
    if not seen[id] then result[#result + 1], seen[id] = id, true end
  end
  return result
end

function Tracker.removeIds(state, idSet)
  local ids, routeMembers, removed, seen = {}, {}, {}, {}
  local function retain(id, target)
    if idSet[id] then
      if not seen[id] then removed[#removed + 1], seen[id] = id, true end
    else
      target[#target + 1] = id
    end
  end
  for _, id in ipairs(state.ids) do retain(id, ids) end
  for _, id in ipairs(state.route and state.route.memberIds or {}) do
    retain(id, routeMembers)
  end
  state.ids = ids
  if state.route then
    state.route.memberIds = routeMembers
    if #routeMembers == 0 then state.route = nil end
  end
  return removed
end

function Tracker.track(state, id)
  if Tracker.containsAny(state, id) then return true end
  if Tracker.slotCount(state) >= state.max then return false end
  table.insert(state.ids, id)
  return true
end

function Tracker.setRoute(state, route)
  state.route = route
  return route ~= nil
end

function Tracker.trackRoute(state, route)
  if not route then return false end
  if state.route then return state.route.family == route.family end
  if Tracker.slotCount(state) >= state.max then return false end
  state.route = route
  return true
end

function Tracker.replaceRoute(state, route)
  if not route then return false end
  if state.route then
    state.route = route
    return true
  end
  if Tracker.slotCount(state) >= state.max then return false end
  state.route = route
  return true
end

function Tracker.untrackRoute(state)
  if not state.route then return false end
  state.route = nil
  return true
end

function Tracker.untrack(state, id)
  for index, trackedId in ipairs(state.ids) do
    if trackedId == id then
      table.remove(state.ids, index)
      return true
    end
  end
  return false
end

function Tracker.toggle(state, id)
  if Tracker.routeContains(state, id) then return false end
  if Tracker.contains(state, id) then return Tracker.untrack(state, id) end
  return Tracker.track(state, id)
end

return Tracker
