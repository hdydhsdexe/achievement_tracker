local Evaluator = {}

function Evaluator.new()
  return { emitted = {} }
end

function Evaluator.reset(state)
  state.emitted = {}
end

local function emitOnce(state, key, warning)
  if state.emitted[key] then return nil end
  state.emitted[key] = true
  return warning
end

function Evaluator.evaluate(state, goal, snapshot)
  if snapshot.eligible == false then
    return emitOnce(state, goal.id .. ":failed", {
      kind = "failed", goalId = goal.id, reason = snapshot.reason or "ineligible"
    })
  end

  if goal.deadline and snapshot.elapsed then
    local remaining = goal.deadline - snapshot.elapsed
    if remaining < 0 then
      return emitOnce(state, goal.id .. ":expired", {
        kind = "expired", goalId = goal.id, remaining = remaining
      })
    end
    for _, threshold in ipairs(goal.thresholds or {}) do
      if remaining <= threshold then
        return emitOnce(state, goal.id .. ":time:" .. threshold, {
          kind = "deadline", goalId = goal.id, remaining = remaining
        })
      end
    end
  end
  return nil
end

return Evaluator
