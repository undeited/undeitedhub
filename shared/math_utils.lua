local MathUtils = {}

function MathUtils.SmoothVelocity(history, maxSamples)
    if #history < 2 then return Vector3.new(0,0,0) end
    local sum = Vector3.new(0,0,0)
    local count = 0
    for i = math.max(1, #history - maxSamples + 1), #history do
        local prev = history[i-1] and history[i-1] or history[i]
        local dt = history[i].time - prev.time
        if dt > 0 and dt < 0.3 then
            local vel = (history[i].pos - prev.pos) / dt
            if vel.Magnitude < 500 then
                sum = sum + vel
                count = count + 1
            end
        end
    end
    if count == 0 then return Vector3.new(0,0,0) end
    return sum / count
end

function MathUtils.PredictPosition(origin, targetPos, targetVel, bulletSpeed, gravity)
    gravity = gravity or Vector3.new(0, -workspace.Gravity, 0)
    local relativePos = targetPos - origin
    local travelTime = relativePos.Magnitude / bulletSpeed
    local drop = 0.5 * gravity * (travelTime * travelTime)
    local predicted = targetPos + targetVel * travelTime + drop
    return predicted
end

function MathUtils.ClampMagnitude(v, max)
    if v.Magnitude > max then return v.Unit * max end
    return v
end

return MathUtils