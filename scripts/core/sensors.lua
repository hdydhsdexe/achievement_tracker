local Sensors = {}

function Sensors.newRun()
  return { disqualified={}, observedPickups={}, failedGoals={}, progress={ gulp=0, items=0 } }
end

function Sensors.normalizeRun(run)
  run.disqualified = run.disqualified or {}
  run.observedPickups = run.observedPickups or {}
  run.failedGoals = run.failedGoals or {}
  run.progress = run.progress or {}
  run.progress.gulp = tonumber(run.progress.gulp) or 0
  run.progress.items = tonumber(run.progress.items) or 0
  return run
end

function Sensors.initialize(run, player)
  -- Reserved for sensors which need a start-of-run player snapshot.
end

function Sensors.update(run, player)
  Sensors.normalizeRun(run)
  if player.GetCollectibleCount then
    run.progress.items = math.max(run.progress.items, player:GetCollectibleCount())
  end
end

function Sensors.onUsePill(run, pillEffect)
  Sensors.normalizeRun(run)
  if PillEffect and pillEffect == PillEffect.PILLEFFECT_GULP then
    run.progress.gulp = run.progress.gulp + 1
  end
end

function Sensors.progress(goal, run)
  Sensors.normalizeRun(run)
  if not goal.progressKey or not goal.target then return nil end
  return math.min(goal.target, math.max(0, tonumber(run.progress[goal.progressKey]) or 0)), goal.target
end

function Sensors.onPickupUpdate(run, pickup)
  local sprite = pickup:GetSprite()
  if not sprite:IsPlaying("Collect") then return end
  local seed = pickup.InitSeed
  if run.observedPickups[seed] then return end
  run.observedPickups[seed] = true
  if pickup.Variant == PickupVariant.PICKUP_HEART then run.disqualified.heart = true end
  if pickup.Variant == PickupVariant.PICKUP_COIN then run.disqualified.coin = true end
  if pickup.Variant == PickupVariant.PICKUP_BOMB then run.disqualified.bomb = true end
end

function Sensors.snapshot(goal, run, game)
  local snapshot = { elapsed = math.floor(game.TimeCounter / 30), eligible = true }
  if goal.sensor == "no_pickups" then
    for _, reason in ipairs({"heart", "coin", "bomb"}) do
      if run.disqualified[reason] then snapshot.eligible=false; snapshot.reason=reason; break end
    end
  end
  return snapshot
end

return Sensors
