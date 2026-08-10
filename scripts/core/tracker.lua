local Tracker = {}

function Tracker.new(maximum, ids)
  return { max = maximum or 3, ids = ids or {} }
end

function Tracker.contains(state, id)
  for _, trackedId in ipairs(state.ids) do
    if trackedId == id then return true end
  end
  return false
end

function Tracker.track(state, id)
  if Tracker.contains(state, id) then return true end
  if #state.ids >= state.max then return false end
  table.insert(state.ids, id)
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
  if Tracker.contains(state, id) then return Tracker.untrack(state, id) end
  return Tracker.track(state, id)
end

return Tracker
