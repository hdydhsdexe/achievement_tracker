local Sensors = {}

function Sensors.newRun()
  return { disqualified={}, observedPickups={} }
end

function Sensors.initialize(run, player)
  -- Reserved for sensors which need a start-of-run player snapshot.
end

function Sensors.update(run, player)
  -- Per-frame player sensors are intentionally kept separate from pickup events.
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
