local mathLib = {}

function mathLib.distance(p1, p2)
    return (p1 - p2).Magnitude
end

function mathLib.lerp(a, b, t)
    return a + (b - a) * t
end

function mathLib.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function mathLib.gaussian(mean, variance)
    local u1 = math.random()
    local u2 = math.random()
    local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    return mean + math.sqrt(variance) * z
end

function mathLib.linearRegression(x, y)
    local n = #x
    local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0
    for i = 1, n do
        sumX = sumX + x[i]
        sumY = sumY + y[i]
        sumXY = sumXY + x[i] * y[i]
        sumX2 = sumX2 + x[i] * x[i]
    end
    local slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
    local intercept = (sumY - slope * sumX) / n
    return slope, intercept
end

function mathLib.predictPosition(positions, times, currentTime)
    if #positions < 2 then return positions[#positions] end
    local relTimes = {}
    for i = 1, #times do relTimes[i] = times[i] - times[1] end
    local relCurrent = currentTime - times[1]
    local slopeX, interceptX = mathLib.linearRegression(relTimes, positions[1])
    local slopeY, interceptY = mathLib.linearRegression(relTimes, positions[2])
    local slopeZ, interceptZ = mathLib.linearRegression(relTimes, positions[3])
    return Vector3.new(
        slopeX * relCurrent + interceptX,
        slopeY * relCurrent + interceptY,
        slopeZ * relCurrent + interceptZ
    )
end

function mathLib.kalmanPredict(prevPos, prevVel, accel, dt)
    local newPos = prevPos + prevVel * dt + 0.5 * accel * dt * dt
    local newVel = prevVel + accel * dt
    return newPos, newVel
end

function mathLib.optimalOrder(points, startPos)
    local order = {}
    local remaining = {}
    for i, p in ipairs(points) do remaining[i] = p end
    local current = startPos
    while #remaining > 0 do
        local bestIdx = 1
        local bestDist = math.huge
        for i, p in ipairs(remaining) do
            local d = mathLib.distance(current, p)
            if d < bestDist then
                bestDist = d
                bestIdx = i
            end
        end
        table.insert(order, remaining[bestIdx])
        current = remaining[bestIdx]
        table.remove(remaining, bestIdx)
    end
    return order
end

return mathLib