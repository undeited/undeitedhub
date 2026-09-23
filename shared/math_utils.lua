local MathUtils = {}

local EPSILON = 1e-10
local TAU = math.pi * 2
local HALF_PI = math.pi / 2
local DEG_TO_RAD = math.pi / 180
local RAD_TO_DEG = 180 / math.pi
local PHI = (1 + math.sqrt(5)) / 2
local EULER = math.exp(1)
local SQRT2 = math.sqrt(2)
local SQRT3 = math.sqrt(3)
local LN2 = math.log(2)
local LN10 = math.log(10)

MathUtils.EPSILON = EPSILON
MathUtils.TAU = TAU
MathUtils.HALF_PI = HALF_PI
MathUtils.DEG_TO_RAD = DEG_TO_RAD
MathUtils.RAD_TO_DEG = RAD_TO_DEG
MathUtils.PHI = PHI
MathUtils.EULER = EULER
MathUtils.SQRT2 = SQRT2
MathUtils.SQRT3 = SQRT3
MathUtils.LN2 = LN2
MathUtils.LN10 = LN10

function MathUtils.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function MathUtils.Saturate(v)
    return MathUtils.Clamp(v, 0, 1)
end

function MathUtils.Lerp(a, b, t)
    return a + (b - a) * t
end

function MathUtils.InverseLerp(a, b, v)
    if math.abs(b - a) < EPSILON then return 0 end
    return (v - a) / (b - a)
end

function MathUtils.Remap(v, inMin, inMax, outMin, outMax)
    return MathUtils.Lerp(outMin, outMax, MathUtils.InverseLerp(inMin, inMax, v))
end

function MathUtils.RemapClamped(v, inMin, inMax, outMin, outMax)
    return MathUtils.Lerp(outMin, outMax, MathUtils.Saturate(MathUtils.InverseLerp(inMin, inMax, v)))
end

function MathUtils.SmoothStep(t)
    t = MathUtils.Saturate(t)
    return t * t * (3 - 2 * t)
end

function MathUtils.SmootherStep(t)
    t = MathUtils.Saturate(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function MathUtils.SmootherStep7(t)
    t = MathUtils.Saturate(t)
    return t * t * t * t * (t * (t * (t * -20 + 70) - 84) + 35)
end

function MathUtils.Sigmoid(x, k)
    k = k or 1
    return 1 / (1 + math.exp(-k * x))
end

function MathUtils.Logistic(x, k, x0)
    k = k or 1
    x0 = x0 or 0
    return 1 / (1 + math.exp(-k * (x - x0)))
end

function MathUtils.Tanh(x)
    return (math.exp(x) - math.exp(-x)) / (math.exp(x) + math.exp(-x))
end

function MathUtils.Coth(x)
    local sinh = (math.exp(x) - math.exp(-x)) / 2
    local cosh = (math.exp(x) + math.exp(-x)) / 2
    if math.abs(sinh) < EPSILON then return 0 end
    return cosh / sinh
end

function MathUtils.Sech(x)
    return 2 / (math.exp(x) + math.exp(-x))
end

function MathUtils.Csch(x)
    if math.abs(x) < EPSILON then return 0 end
    return 2 / (math.exp(x) - math.exp(-x))
end

function MathUtils.Asinh(x)
    return math.log(x + math.sqrt(x * x + 1))
end

function MathUtils.Acosh(x)
    if x < 1 then return 0 end
    return math.log(x + math.sqrt(x * x - 1))
end

function MathUtils.Atanh(x)
    if math.abs(x) >= 1 then return 0 end
    return 0.5 * math.log((1 + x) / (1 - x))
end

function MathUtils.Sinc(x)
    if math.abs(x) < EPSILON then return 1 end
    return math.sin(x) / x
end

function MathUtils.NormalizedSinc(x)
    if math.abs(x) < EPSILON then return 1 end
    return math.sin(math.pi * x) / (math.pi * x)
end

function MathUtils.Factorial(n)
    if n < 0 or n ~= math.floor(n) then return 0 end
    if n <= 1 then return 1 end
    local result = 1
    for i = 2, n do result = result * i end
    return result
end

function MathUtils.DoubleFactorial(n)
    if n < 0 or n ~= math.floor(n) then return 0 end
    if n <= 0 then return 1 end
    local result = 1
    local i = n
    while i > 1 do
        result = result * i
        i = i - 2
    end
    return result
end

function MathUtils.Gamma(x)
    if x < 0.5 then
        return math.pi / (math.sin(math.pi * x) * MathUtils.Gamma(1 - x))
    end
    x = x - 1
    local a = {
        0.99999999999980993,
        676.5203681218851,
        -1259.1392167224028,
        771.32342877765313,
        -176.61502916214059,
        12.507343278686905,
        -0.13857109526572012,
        9.9843695780195716e-6,
        1.5056327351493116e-7,
    }
    local g = 7
    local sum = a[1]
    for i = 2, g + 2 do
        sum = sum + a[i] / (x + i - 1)
    end
    local t = x + g + 0.5
    return math.sqrt(TAU) * (t ^ (x + 0.5)) * math.exp(-t) * sum
end

function MathUtils.LnGamma(x)
    if x < 0.5 then
        return math.log(math.pi / math.abs(math.sin(math.pi * x))) - MathUtils.LnGamma(1 - x)
    end
    local coeffs = {
        76.18009172947146,
        -86.50532032941677,
        24.01409824083091,
        -1.231739572450155,
        0.1208650973866179e-2,
        -0.5395239384953e-5,
    }
    local y = x
    local tmp = x + 5.5
    tmp = tmp - (x + 0.5) * math.log(tmp)
    local ser = 1.000000000190015
    for j = 1, 6 do
        y = y + 1
        ser = ser + coeffs[j] / y
    end
    return -tmp + math.log(math.sqrt(TAU) * ser / x)
end

function MathUtils.Beta(a, b)
    return math.exp(MathUtils.LnGamma(a) + MathUtils.LnGamma(b) - MathUtils.LnGamma(a + b))
end

function MathUtils.Binomial(n, k)
    if k < 0 or k > n then return 0 end
    return MathUtils.Factorial(n) / (MathUtils.Factorial(k) * MathUtils.Factorial(n - k))
end

function MathUtils.Permutation(n, k)
    if k < 0 or k > n then return 0 end
    local result = 1
    for i = n - k + 1, n do result = result * i end
    return result
end

function MathUtils.GCD(a, b)
    a = math.abs(math.floor(a))
    b = math.abs(math.floor(b))
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

function MathUtils.LCM(a, b)
    if a == 0 or b == 0 then return 0 end
    return math.abs(a * b) / MathUtils.GCD(a, b)
end

function MathUtils.IsPrime(n)
    n = math.floor(n)
    if n < 2 then return false end
    if n < 4 then return true end
    if n % 2 == 0 then return false end
    local i = 3
    while i * i <= n do
        if n % i == 0 then return false end
        i = i + 2
    end
    return true
end

function MathUtils.NextPrime(n)
    n = math.floor(n)
    if n < 2 then return 2 end
    local candidate = n + 1
    while not MathUtils.IsPrime(candidate) do
        candidate = candidate + 1
    end
    return candidate
end

function MathUtils.PrimeFactors(n)
    n = math.floor(math.abs(n))
    local factors = {}
    if n < 2 then return factors end
    while n % 2 == 0 do
        table.insert(factors, 2)
        n = n / 2
    end
    local i = 3
    while i * i <= n do
        while n % i == 0 do
            table.insert(factors, i)
            n = n / i
        end
        i = i + 2
    end
    if n > 1 then table.insert(factors, n) end
    return factors
end

function MathUtils.NthRoot(x, n)
    if n == 0 then return 0 end
    if x < 0 and n % 2 == 0 then return 0 end
    if x < 0 then return -((-x) ^ (1 / n)) end
    return x ^ (1 / n)
end

function MathUtils.LogBase(x, base)
    if x <= 0 or base <= 0 or base == 1 then return 0 end
    return math.log(x) / math.log(base)
end

function MathUtils.Log2(x)
    if x <= 0 then return 0 end
    return math.log(x) / LN2
end

function MathUtils.Log10(x)
    if x <= 0 then return 0 end
    return math.log(x) / LN10
end

function MathUtils.Hypot(x, y)
    return math.sqrt(x * x + y * y)
end

function MathUtils.Hypot3(x, y, z)
    return math.sqrt(x * x + y * y + z * z)
end

function MathUtils.Sign(x)
    if x > 0 then return 1 end
    if x < 0 then return -1 end
    return 0
end

function MathUtils.Approximately(a, b, tolerance)
    tolerance = tolerance or EPSILON
    return math.abs(a - b) <= tolerance
end

function MathUtils.Wrap(x, min, max)
    local range = max - min
    if range <= 0 then return min end
    while x < min do x = x + range end
    while x > max do x = x - range end
    return x
end

function MathUtils.WrapAngle(radians)
    return MathUtils.Wrap(radians, -math.pi, math.pi)
end

function MathUtils.WrapAnglePositive(radians)
    return MathUtils.Wrap(radians, 0, TAU)
end

function MathUtils.AngleDifference(a, b)
    return MathUtils.WrapAngle(b - a)
end

function MathUtils.AngleLerp(a, b, t)
    return a + MathUtils.AngleDifference(a, b) * MathUtils.Saturate(t)
end

function MathUtils.MoveTowards(current, target, maxDelta)
    local delta = target - current
    if math.abs(delta) <= maxDelta then return target end
    return current + MathUtils.Sign(delta) * maxDelta
end

function MathUtils.MoveTowardsAngle(current, target, maxDelta)
    local diff = MathUtils.AngleDifference(current, target)
    if math.abs(diff) <= maxDelta then return target end
    return current + MathUtils.Sign(diff) * maxDelta
end

function MathUtils.SmoothDamp(current, target, velocity, smoothTime, maxSpeed, deltaTime)
    smoothTime = math.max(0.0001, smoothTime)
    deltaTime = deltaTime or (1 / 60)
    maxSpeed = maxSpeed or math.huge
    local omega = 2 / smoothTime
    local x = omega * deltaTime
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local originalTo = target
    local maxChange = maxSpeed * smoothTime
    change = MathUtils.Clamp(change, -maxChange, maxChange)
    target = current - change
    local temp = (velocity + omega * change) * deltaTime
    velocity = (velocity - omega * temp) * exp
    local output = target + (change + temp) * exp
    if (originalTo - current > 0) == (output > originalTo) then
        output = originalTo
        velocity = (output - originalTo) / deltaTime
    end
    return output, velocity
end

function MathUtils.DampedSpring(current, target, velocity, stiffness, damping, deltaTime)
    deltaTime = deltaTime or (1 / 60)
    local force = -stiffness * (current - target)
    local dampingForce = -damping * velocity
    local acceleration = force + dampingForce
    velocity = velocity + acceleration * deltaTime
    current = current + velocity * deltaTime
    return current, velocity
end

function MathUtils.SmoothVelocity(history, maxSamples)
    if #history < 2 then return Vector3.new(0, 0, 0) end
    local sum = Vector3.new(0, 0, 0)
    local count = 0
    for i = math.max(1, #history - maxSamples + 1), #history do
        local prev = history[i - 1] and history[i - 1] or history[i]
        local dt = history[i].time - prev.time
        if dt > 0 and dt < 0.3 then
            local vel = (history[i].pos - prev.pos) / dt
            if vel.Magnitude < 500 then
                sum = sum + vel
                count = count + 1
            end
        end
    end
    if count == 0 then return Vector3.new(0, 0, 0) end
    return sum / count
end

function MathUtils.WeightedVelocity(history, decay)
    if #history < 2 then return Vector3.new(0, 0, 0) end
    decay = decay or 0.7
    local sum = Vector3.new(0, 0, 0)
    local weightSum = 0
    local weight = 1
    for i = #history, 2, -1 do
        local prev = history[i - 1]
        local dt = history[i].time - prev.time
        if dt > 0 and dt < 0.3 then
            local vel = (history[i].pos - prev.pos) / dt
            if vel.Magnitude < 500 then
                sum = sum + vel * weight
                weightSum = weightSum + weight
            end
        end
        weight = weight * decay
    end
    if weightSum < EPSILON then return Vector3.new(0, 0, 0) end
    return sum / weightSum
end

function MathUtils.PredictPosition(origin, targetPos, targetVel, bulletSpeed, gravity)
    gravity = gravity or Vector3.new(0, -workspace.Gravity, 0)
    local relativePos = targetPos - origin
    local travelTime = relativePos.Magnitude / bulletSpeed
    local drop = 0.5 * gravity * (travelTime * travelTime)
    local predicted = targetPos + targetVel * travelTime + drop
    return predicted
end

function MathUtils.PredictPositionIterative(origin, targetPos, targetVel, bulletSpeed, gravity, iterations)
    iterations = iterations or 5
    gravity = gravity or Vector3.new(0, -workspace.Gravity, 0)
    local guess = targetPos
    for _ = 1, iterations do
        local relativePos = guess - origin
        local travelTime = relativePos.Magnitude / bulletSpeed
        local drop = 0.5 * gravity * (travelTime * travelTime)
        guess = targetPos + targetVel * travelTime + drop
    end
    return guess
end

function MathUtils.SolveBallisticAngle(origin, target, speed, gravity)
    gravity = gravity or -workspace.Gravity
    local dx = target.X - origin.X
    local dz = target.Z - origin.Z
    local horizontal = math.sqrt(dx * dx + dz * dz)
    local dy = target.Y - origin.Y
    local speedSq = speed * speed
    local disc = speedSq * speedSq - gravity * (gravity * horizontal * horizontal + 2 * dy * speedSq)
    if disc < 0 then return nil end
    local sqrtDisc = math.sqrt(disc)
    local angleLow = math.atan2(speedSq - sqrtDisc, gravity * horizontal)
    local angleHigh = math.atan2(speedSq + sqrtDisc, gravity * horizontal)
    return angleLow, angleHigh
end

function MathUtils.BallisticTrajectory(origin, target, speed, gravity)
    gravity = gravity or -workspace.Gravity
    local dx = target.X - origin.X
    local dz = target.Z - origin.Z
    local horizontal = math.sqrt(dx * dx + dz * dz)
    local dy = target.Y - origin.Y
    local speedSq = speed * speed
    local disc = speedSq * speedSq - gravity * (gravity * horizontal * horizontal + 2 * dy * speedSq)
    if disc < 0 then return nil end
    local sqrtDisc = math.sqrt(disc)
    local angle = math.atan2(speedSq - sqrtDisc, gravity * horizontal)
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    local dirX = dx / horizontal
    local dirZ = dz / horizontal
    return Vector3.new(vx * dirX, vy, vx * dirZ)
end

function MathUtils.SolveTravelTime(origin, target, targetVel, bulletSpeed)
    local relativePos = target - origin
    local a = targetVel:Dot(targetVel) - bulletSpeed * bulletSpeed
    local b = 2 * relativePos:Dot(targetVel)
    local c = relativePos:Dot(relativePos)
    if math.abs(a) < EPSILON then
        if math.abs(b) < EPSILON then return nil end
        return -c / b
    end
    local disc = b * b - 4 * a * c
    if disc < 0 then return nil end
    local sqrtDisc = math.sqrt(disc)
    local t1 = (-b - sqrtDisc) / (2 * a)
    local t2 = (-b + sqrtDisc) / (2 * a)
    if t1 > 0 and t2 > 0 then return math.min(t1, t2) end
    if t1 > 0 then return t1 end
    if t2 > 0 then return t2 end
    return nil
end

function MathUtils.PredictLinearIntercept(origin, target, targetVel, bulletSpeed)
    local t = MathUtils.SolveTravelTime(origin, target, targetVel, bulletSpeed)
    if not t then return nil end
    return target + targetVel * t
end

function MathUtils.SmoothVector(current, target, smoothing, deltaTime)
    deltaTime = deltaTime or (1 / 60)
    smoothing = math.max(0, smoothing)
    local alpha = 1 - math.exp(-smoothing * deltaTime)
    return current + (target - current) * alpha
end

function MathUtils.LerpVector(a, b, t)
    return a + (b - a) * t
end

function MathUtils.ClampMagnitude(v, max)
    if v.Magnitude > max then return v.Unit * max end
    return v
end

function MathUtils.ClampMagnitudeMin(v, min)
    local m = v.Magnitude
    if m < min and m > EPSILON then return v.Unit * min end
    return v
end

function MathUtils.VectorDistance(a, b)
    return (a - b).Magnitude
end

function MathUtils.VectorDistanceSquared(a, b)
    local d = a - b
    return d.X * d.X + d.Y * d.Y + d.Z * d.Z
end

function MathUtils.AngleBetween(a, b)
    local denominator = a.Magnitude * b.Magnitude
    if denominator < EPSILON then return 0 end
    local cos = MathUtils.Clamp(a:Dot(b) / denominator, -1, 1)
    return math.acos(cos)
end

function MathUtils.ProjectVector(a, b)
    local bMagSq = b:Dot(b)
    if bMagSq < EPSILON then return Vector3.new(0, 0, 0) end
    return b * (a:Dot(b) / bMagSq)
end

function MathUtils.RejectVector(a, b)
    return a - MathUtils.ProjectVector(a, b)
end

function MathUtils.ReflectVector(v, normal)
    local n = normal.Unit
    return v - 2 * v:Dot(n) * n
end

function MathUtils.RefractVector(v, normal, eta)
    local n = normal.Unit
    local cosi = -v.Unit:Dot(n)
    local k = 1 - eta * eta * (1 - cosi * cosi)
    if k < 0 then return nil end
    return (eta * v + (eta * cosi - math.sqrt(k)) * n).Unit
end

function MathUtils.RotateAroundAxis(v, axis, angle)
    axis = axis.Unit
    local cos = math.cos(angle)
    local sin = math.sin(angle)
    return v * cos + axis:Cross(v) * sin + axis * (axis:Dot(v) * (1 - cos))
end

function MathUtils.VectorToYaw(v)
    return math.atan2(-v.X, -v.Z)
end

function MathUtils.VectorToPitch(v)
    local horizontal = math.sqrt(v.X * v.X + v.Z * v.Z)
    return math.atan2(v.Y, horizontal)
end

function MathUtils.YawToVector(yaw)
    return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function MathUtils.SphericalToCartesian(radius, theta, phi)
    local sinPhi = math.sin(phi)
    return Vector3.new(
        radius * sinPhi * math.cos(theta),
        radius * cos(phi),
        radius * sinPhi * math.sin(theta)
    )
end

function MathUtils.CartesianToSpherical(v)
    local radius = v.Magnitude
    if radius < EPSILON then return 0, 0, 0 end
    local theta = math.atan2(v.Z, v.X)
    local phi = math.acos(MathUtils.Clamp(v.Y / radius, -1, 1))
    return radius, theta, phi
end

function MathUtils.CylindricalToCartesian(radius, theta, height)
    return Vector3.new(radius * math.cos(theta), height, radius * math.sin(theta))
end

function MathUtils.CartesianToCylindrical(v)
    local radius = math.sqrt(v.X * v.X + v.Z * v.Z)
    local theta = math.atan2(v.Z, v.X)
    return radius, theta, v.Y
end

function MathUtils.VectorToTable(v)
    return { X = v.X, Y = v.Y, Z = v.Z }
end

function MathUtils.TableToVector(t)
    return Vector3.new(t.X or 0, t.Y or 0, t.Z or 0)
end

function MathUtils.VectorComponents(v)
    return v.X, v.Y, v.Z
end

function MathUtils.VectorToArray(v)
    return { v.X, v.Y, v.Z }
end

function MathUtils.ArrayToVector(arr)
    return Vector3.new(arr[1] or 0, arr[2] or 0, arr[3] or 0)
end

function MathUtils.CFrameToTable(cf)
    return {
        Position = MathUtils.VectorToTable(cf.Position),
        RightVector = MathUtils.VectorToTable(cf.RightVector),
        UpVector = MathUtils.VectorToTable(cf.UpVector),
        LookVector = MathUtils.VectorToTable(cf.LookVector),
    }
end

function MathUtils.TableToCFrame(t)
    if not t.Position or not t.LookVector then
        return CFrame.new()
    end
    local pos = MathUtils.TableToVector(t.Position)
    local look = MathUtils.TableToVector(t.LookVector)
    local up = MathUtils.TableToVector(t.UpVector)
    return CFrame.lookAt(pos, pos + look, up)
end

function MathUtils.MatrixMultiply(a, b)
    local result = {}
    for i = 1, #a do
        result[i] = {}
        for j = 1, #b[1] do
            local sum = 0
            for k = 1, #b do
                sum = sum + a[i][k] * b[k][j]
            end
            result[i][j] = sum
        end
    end
    return result
end

function MathUtils.MatrixTranspose(m)
    local result = {}
    for i = 1, #m[1] do
        result[i] = {}
        for j = 1, #m do
            result[i][j] = m[j][i]
        end
    end
    return result
end

function MathUtils.MatrixIdentity(n)
    local result = {}
    for i = 1, n do
        result[i] = {}
        for j = 1, n do
            result[i][j] = (i == j) and 1 or 0
        end
    end
    return result
end

function MathUtils.MatrixDeterminant2(m)
    return m[1][1] * m[2][2] - m[1][2] * m[2][1]
end

function MathUtils.MatrixDeterminant3(m)
    return m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2])
         - m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1])
         + m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
end

function MathUtils.SolveQuadratic(a, b, c)
    if math.abs(a) < EPSILON then
        if math.abs(b) < EPSILON then return nil end
        return -c / b
    end
    local disc = b * b - 4 * a * c
    if disc < 0 then return nil end
    local sqrtDisc = math.sqrt(disc)
    return (-b + sqrtDisc) / (2 * a), (-b - sqrtDisc) / (2 * a)
end

function MathUtils.SolveCubic(a, b, c, d)
    if math.abs(a) < EPSILON then
        return MathUtils.SolveQuadratic(b, c, d)
    end
    local b2 = b / a
    local c2 = c / a
    local d2 = d / a
    local p = c2 - b2 * b2 / 3
    local q = 2 * b2 * b2 * b2 / 27 - b2 * c2 / 3 + d2
    local disc = q * q / 4 + p * p * p / 27
    if disc > 0 then
        local sqrtDisc = math.sqrt(disc)
        local u = MathUtils.NthRoot(-q / 2 + sqrtDisc, 3)
        local v = MathUtils.NthRoot(-q / 2 - sqrtDisc, 3)
        return u + v - b2 / 3
    elseif math.abs(disc) < EPSILON then
        local u = MathUtils.NthRoot(-q / 2, 3)
        return 2 * u - b2 / 3, -u - b2 / 3
    else
        local r = math.sqrt(-p * p * p / 27)
        local phi = math.acos(MathUtils.Clamp(-q / (2 * r), -1, 1))
        local t1 = 2 * MathUtils.NthRoot(r, 3) * math.cos(phi / 3) - b2 / 3
        local t2 = 2 * MathUtils.NthRoot(r, 3) * math.cos((phi + TAU) / 3) - b2 / 3
        local t3 = 2 * MathUtils.NthRoot(r, 3) * math.cos((phi + 2 * TAU) / 3) - b2 / 3
        return t1, t2, t3
    end
end

function MathUtils.NewtonRaphson(f, df, x0, tolerance, maxIter)
    tolerance = tolerance or 1e-7
    maxIter = maxIter or 50
    local x = x0
    for _ = 1, maxIter do
        local fx = f(x)
        if math.abs(fx) < tolerance then return x end
        local dfx = df(x)
        if math.abs(dfx) < EPSILON then return x end
        x = x - fx / dfx
    end
    return x
end

function MathUtils.Bisection(f, a, b, tolerance, maxIter)
    tolerance = tolerance or 1e-7
    maxIter = maxIter or 100
    local fa = f(a)
    local fb = f(b)
    if fa * fb > 0 then return nil end
    local mid
    for _ = 1, maxIter do
        mid = (a + b) / 2
        local fm = f(mid)
        if math.abs(fm) < tolerance or (b - a) / 2 < tolerance then
            return mid
        end
        if fa * fm < 0 then
            b = mid
            fb = fm
        else
            a = mid
            fa = fm
        end
    end
    return mid
end

function MathUtils.Secant(f, x0, x1, tolerance, maxIter)
    tolerance = tolerance or 1e-7
    maxIter = maxIter or 50
    local f0 = f(x0)
    local f1 = f(x1)
    local x2
    for _ = 1, maxIter do
        if math.abs(f1 - f0) < EPSILON then return x1 end
        x2 = x1 - f1 * (x1 - x0) / (f1 - f0)
        if math.abs(x2 - x1) < tolerance then return x2 end
        x0, f0 = x1, f1
        x1, f1 = x2, f(x2)
    end
    return x2 or x1
end

function MathUtils.TrapezoidalIntegral(f, a, b, n)
    n = n or 100
    local h = (b - a) / n
    local sum = (f(a) + f(b)) / 2
    for i = 1, n - 1 do
        sum = sum + f(a + i * h)
    end
    return sum * h
end

function MathUtils.SimpsonIntegral(f, a, b, n)
    n = n or 100
    if n % 2 == 1 then n = n + 1 end
    local h = (b - a) / n
    local sum = f(a) + f(b)
    for i = 1, n - 1 do
        local x = a + i * h
        if i % 2 == 0 then
            sum = sum + 2 * f(x)
        else
            sum = sum + 4 * f(x)
        end
    end
    return sum * h / 3
end

function MathUtils.NumericalDerivative(f, x, h)
    h = h or 1e-6
    return (f(x + h) - f(x - h)) / (2 * h)
end

function MathUtils.SecondDerivative(f, x, h)
    h = h or 1e-5
    return (f(x + h) - 2 * f(x) + f(x - h)) / (h * h)
end

function MathUtils.Bezier(points, t)
    t = MathUtils.Saturate(t)
    local n = #points - 1
    local result = Vector3.new(0, 0, 0)
    for i = 0, n do
        local coeff = MathUtils.Binomial(n, i) * (t ^ i) * ((1 - t) ^ (n - i))
        result = result + points[i + 1] * coeff
    end
    return result
end

function MathUtils.QuadraticBezier(p0, p1, p2, t)
    local inv = 1 - t
    return inv * inv * p0 + 2 * inv * t * p1 + t * t * p2
end

function MathUtils.CubicBezier(p0, p1, p2, p3, t)
    local inv = 1 - t
    local inv2 = inv * inv
    local t2 = t * t
    return inv2 * inv * p0 + 3 * inv2 * t * p1 + 3 * inv * t2 * p2 + t2 * t * p3
end

function MathUtils.QuadraticBezierDerivative(p0, p1, p2, t)
    return 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
end

function MathUtils.CubicBezierDerivative(p0, p1, p2, p3, t)
    local inv = 1 - t
    return 3 * inv * inv * (p1 - p0) + 6 * inv * t * (p2 - p1) + 3 * t * t * (p3 - p2)
end

function MathUtils.CatmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )
end

function MathUtils.LagrangeInterpolate(points, x)
    local result = 0
    local n = #points
    for i = 1, n do
        local term = points[i].y
        for j = 1, n do
            if i ~= j then
                local denom = points[i].x - points[j].x
                if math.abs(denom) > EPSILON then
                    term = term * (x - points[j].x) / denom
                end
            end
        end
        result = result + term
    end
    return result
end

function MathUtils.ArraySum(arr)
    local sum = 0
    for _, v in ipairs(arr) do sum = sum + v end
    return sum
end

function MathUtils.ArrayProduct(arr)
    local product = 1
    for _, v in ipairs(arr) do product = product * v end
    return product
end

function MathUtils.ArrayMean(arr)
    if #arr == 0 then return 0 end
    return MathUtils.ArraySum(arr) / #arr
end

function MathUtils.ArrayMedian(arr)
    if #arr == 0 then return 0 end
    local sorted = {}
    for _, v in ipairs(arr) do table.insert(sorted, v) end
    table.sort(sorted)
    local n = #sorted
    if n % 2 == 1 then
        return sorted[(n + 1) / 2]
    else
        return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
    end
end

function MathUtils.ArrayMode(arr)
    if #arr == 0 then return nil end
    local counts = {}
    local maxCount = 0
    local mode = arr[1]
    for _, v in ipairs(arr) do
        counts[v] = (counts[v] or 0) + 1
        if counts[v] > maxCount then
            maxCount = counts[v]
            mode = v
        end
    end
    return mode
end

function MathUtils.ArrayVariance(arr, sample)
    if #arr < 2 then return 0 end
    local mean = MathUtils.ArrayMean(arr)
    local sum = 0
    for _, v in ipairs(arr) do
        sum = sum + (v - mean) ^ 2
    end
    if sample then
        return sum / (#arr - 1)
    end
    return sum / #arr
end

function MathUtils.ArrayStdDev(arr, sample)
    return math.sqrt(MathUtils.ArrayVariance(arr, sample))
end

function MathUtils.ArrayMin(arr)
    if #arr == 0 then return nil end
    local min = arr[1]
    for i = 2, #arr do
        if arr[i] < min then min = arr[i] end
    end
    return min
end

function MathUtils.ArrayMax(arr)
    if #arr == 0 then return nil end
    local max = arr[1]
    for i = 2, #arr do
        if arr[i] > max then max = arr[i] end
    end
    return max
end

function MathUtils.ArrayRange(arr)
    return MathUtils.ArrayMax(arr) - MathUtils.ArrayMin(arr)
end

function MathUtils.ArrayNormalize(arr)
    local sum = MathUtils.ArraySum(arr)
    if math.abs(sum) < EPSILON then return arr end
    local result = {}
    for i, v in ipairs(arr) do result[i] = v / sum end
    return result
end

function MathUtils.ArrayScale(arr, scalar)
    local result = {}
    for i, v in ipairs(arr) do result[i] = v * scalar end
    return result
end

function MathUtils.ArrayAdd(a, b)
    local result = {}
    local n = math.max(#a, #b)
    for i = 1, n do
        result[i] = (a[i] or 0) + (b[i] or 0)
    end
    return result
end

function MathUtils.ArraySubtract(a, b)
    local result = {}
    local n = math.max(#a, #b)
    for i = 1, n do
        result[i] = (a[i] or 0) - (b[i] or 0)
    end
    return result
end

function MathUtils.ArrayDot(a, b)
    local sum = 0
    local n = math.min(#a, #b)
    for i = 1, n do
        sum = sum + a[i] * b[i]
    end
    return sum
end

function MathUtils.ArrayMagnitude(arr)
    local sum = 0
    for _, v in ipairs(arr) do sum = sum + v * v end
    return math.sqrt(sum)
end

function MathUtils.ArrayNormalizeVector(arr)
    local mag = MathUtils.ArrayMagnitude(arr)
    if mag < EPSILON then return arr end
    local result = {}
    for i, v in ipairs(arr) do result[i] = v / mag end
    return result
end

function MathUtils.WeightedAverage(values, weights)
    if #values ~= #weights then return 0 end
    local sum = 0
    local weightSum = 0
    for i = 1, #values do
        sum = sum + values[i] * weights[i]
        weightSum = weightSum + weights[i]
    end
    if math.abs(weightSum) < EPSILON then return 0 end
    return sum / weightSum
end

function MathUtils.MovingAverage(arr, window)
    window = math.max(1, window or 3)
    local result = {}
    for i = 1, #arr do
        local start = math.max(1, i - window + 1)
        local sum = 0
        local count = 0
        for j = start, i do
            sum = sum + arr[j]
            count = count + 1
        end
        result[i] = sum / count
    end
    return result
end

function MathUtils.ExponentialMovingAverage(arr, alpha)
    alpha = alpha or 0.5
    if #arr == 0 then return {} end
    local result = { arr[1] }
    for i = 2, #arr do
        result[i] = alpha * arr[i] + (1 - alpha) * result[i - 1]
    end
    return result
end

function MathUtils.PearsonCorrelation(x, y)
    local n = math.min(#x, #y)
    if n < 2 then return 0 end
    local meanX = MathUtils.ArrayMean(x)
    local meanY = MathUtils.ArrayMean(y)
    local num = 0
    local denX = 0
    local denY = 0
    for i = 1, n do
        local dx = x[i] - meanX
        local dy = y[i] - meanY
        num = num + dx * dy
        denX = denX + dx * dx
        denY = denY + dy * dy
    end
    local den = math.sqrt(denX * denY)
    if den < EPSILON then return 0 end
    return num / den
end

function MathUtils.LinearRegression(x, y)
    local n = math.min(#x, #y)
    if n < 2 then return nil end
    local sumX = 0
    local sumY = 0
    local sumXY = 0
    local sumX2 = 0
    for i = 1, n do
        sumX = sumX + x[i]
        sumY = sumY + y[i]
        sumXY = sumXY + x[i] * y[i]
        sumX2 = sumX2 + x[i] * x[i]
    end
    local denom = n * sumX2 - sumX * sumX
    if math.abs(denom) < EPSILON then return nil end
    local slope = (n * sumXY - sumX * sumY) / denom
    local intercept = (sumY - slope * sumX) / n
    return slope, intercept
end

function MathUtils.ExponentialRegression(x, y)
    local n = math.min(#x, #y)
    if n < 2 then return nil end
    local lnY = {}
    for i = 1, n do
        if y[i] <= 0 then return nil end
        lnY[i] = math.log(y[i])
    end
    local slope, intercept = MathUtils.LinearRegression(x, lnY)
    if not slope then return nil end
    return math.exp(intercept), slope
end

function MathUtils.PowerRegression(x, y)
    local n = math.min(#x, #y)
    if n < 2 then return nil end
    local lnX = {}
    local lnY = {}
    for i = 1, n do
        if x[i] <= 0 or y[i] <= 0 then return nil end
        lnX[i] = math.log(x[i])
        lnY[i] = math.log(y[i])
    end
    local slope, intercept = MathUtils.LinearRegression(lnX, lnY)
    if not slope then return nil end
    return math.exp(intercept), slope
end

function MathUtils.PolynomialRegression(x, y, degree)
    degree = degree or 2
    local n = math.min(#x, #y)
    if n < degree + 1 then return nil end
    local matrix = {}
    local vector = {}
    for i = 1, degree + 1 do
        matrix[i] = {}
        for j = 1, degree + 1 do
            local sum = 0
            for k = 1, n do
                sum = sum + x[k] ^ (i + j - 2)
            end
            matrix[i][j] = sum
        end
        local sumY = 0
        for k = 1, n do
            sumY = sumY + y[k] * (x[k] ^ (i - 1))
        end
        vector[i] = sumY
    end
    local coeffs = {}
    for i = 1, degree + 1 do coeffs[i] = 0 end
    for _ = 1, 100 do
        local maxChange = 0
        for i = 1, degree + 1 do
            local sum = vector[i]
            for j = 1, degree + 1 do
                if i ~= j then
                    sum = sum - matrix[i][j] * coeffs[j]
                end
            end
            if math.abs(matrix[i][i]) > EPSILON then
                local newVal = sum / matrix[i][i]
                maxChange = math.max(maxChange, math.abs(newVal - coeffs[i]))
                coeffs[i] = newVal
            end
        end
        if maxChange < 1e-9 then break end
    end
    return coeffs
end

function MathUtils.Noise1D(x)
    local xi = math.floor(x)
    local xf = x - xi
    local u = MathUtils.SmoothStep(xf)
    local a = math.sin(xi * 12.9898) * 43758.5453
    local b = math.sin((xi + 1) * 12.9898) * 43758.5453
    a = a - math.floor(a)
    b = b - math.floor(b)
    return MathUtils.Lerp(a, b, u)
end

function MathUtils.Noise2D(x, y)
    local xi = math.floor(x)
    local yi = math.floor(y)
    local xf = x - xi
    local yf = y - yi
    local u = MathUtils.SmoothStep(xf)
    local v = MathUtils.SmoothStep(yf)
    local function hash(px, py)
        local h = math.sin(px * 127.1 + py * 311.7) * 43758.5453
        return h - math.floor(h)
    end
    local a = hash(xi, yi)
    local b = hash(xi + 1, yi)
    local c = hash(xi, yi + 1)
    local d = hash(xi + 1, yi + 1)
    return MathUtils.Lerp(MathUtils.Lerp(a, b, u), MathUtils.Lerp(c, d, u), v)
end

function MathUtils.FractalNoise1D(x, octaves, persistence)
    octaves = octaves or 4
    persistence = persistence or 0.5
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    for _ = 1, octaves do
        total = total + MathUtils.Noise1D(x * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    if maxValue < EPSILON then return 0 end
    return total / maxValue
end

function MathUtils.FractalNoise2D(x, y, octaves, persistence)
    octaves = octaves or 4
    persistence = persistence or 0.5
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    for _ = 1, octaves do
        total = total + MathUtils.Noise2D(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    if maxValue < EPSILON then return 0 end
    return total / maxValue
end

local randomSeed = os.clock() * 1e6

function MathUtils.SeedRandom(seed)
    randomSeed = seed
end

function MathUtils.Random()
    randomSeed = (randomSeed * 9301 + 49297) % 233280
    return randomSeed / 233280
end

function MathUtils.RandomRange(min, max)
    return min + MathUtils.Random() * (max - min)
end

function MathUtils.RandomInt(min, max)
    return math.floor(MathUtils.RandomRange(min, max + 1))
end

function MathUtils.RandomGaussian(mean, stdDev)
    mean = mean or 0
    stdDev = stdDev or 1
    local u1 = MathUtils.Random()
    local u2 = MathUtils.Random()
    if u1 < EPSILON then u1 = EPSILON end
    local z = math.sqrt(-2 * math.log(u1)) * math.cos(TAU * u2)
    return mean + z * stdDev
end

function MathUtils.ShuffleArray(arr)
    local result = {}
    for i, v in ipairs(arr) do result[i] = v end
    for i = #result, 2, -1 do
        local j = MathUtils.RandomInt(1, i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end

function MathUtils.RandomChoice(arr)
    if #arr == 0 then return nil end
    return arr[MathUtils.RandomInt(1, #arr)]
end

function MathUtils.RandomWeighted(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    if total < EPSILON then return 1 end
    local roll = MathUtils.Random() * total
    local cumulative = 0
    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if roll <= cumulative then return i end
    end
    return #weights
end

function MathUtils.BinomialDistribution(n, p, k)
    if k < 0 or k > n then return 0 end
    return MathUtils.Binomial(n, k) * (p ^ k) * ((1 - p) ^ (n - k))
end

function MathUtils.PoissonDistribution(lambda, k)
    if k < 0 then return 0 end
    return (lambda ^ k) * math.exp(-lambda) / MathUtils.Factorial(k)
end

function MathUtils.NormalPDF(x, mean, stdDev)
    mean = mean or 0
    stdDev = stdDev or 1
    if stdDev < EPSILON then return 0 end
    local exponent = -((x - mean) ^ 2) / (2 * stdDev * stdDev)
    return (1 / (stdDev * math.sqrt(TAU))) * math.exp(exponent)
end

function MathUtils.NormalCDF(x, mean, stdDev)
    mean = mean or 0
    stdDev = stdDev or 1
    if stdDev < EPSILON then return 0 end
    return 0.5 * (1 + MathUtils.Erf((x - mean) / (stdDev * SQRT2)))
end

function MathUtils.Erf(x)
    local sign = 1
    if x < 0 then sign = -1; x = -x end
    local a1 = 0.254829592
    local a2 = -0.284496736
    local a3 = 1.421413741
    local a4 = -1.453152027
    local a5 = 1.061405429
    local p = 0.3275911
    local t = 1 / (1 + p * x)
    local y = 1 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)
    return sign * y
end

function MathUtils.Erfc(x)
    return 1 - MathUtils.Erf(x)
end

function MathUtils.InverseErf(x)
    local a = 0.147
    local ln1x = math.log(1 - x * x)
    local term1 = 2 / (math.pi * a) + ln1x / 2
    local term2 = ln1x / a
    return MathUtils.Sign(x) * math.sqrt(math.sqrt(term1 * term1 - term2) - term1)
end

function MathUtils.NormalQuantile(p, mean, stdDev)
    mean = mean or 0
    stdDev = stdDev or 1
    if p <= 0 or p >= 1 then return mean end
    return mean + stdDev * SQRT2 * MathUtils.InverseErf(2 * p - 1)
end

function MathUtils.GeometricDistribution(p, k)
    if k < 1 or p <= 0 or p > 1 then return 0 end
    return ((1 - p) ^ (k - 1)) * p
end

function MathUtils.ExponentialPDF(lambda, x)
    if x < 0 or lambda <= 0 then return 0 end
    return lambda * math.exp(-lambda * x)
end

function MathUtils.UniformPDF(a, b, x)
    if x < a or x > b or b <= a then return 0 end
    return 1 / (b - a)
end

function MathUtils.ZScore(x, mean, stdDev)
    if stdDev < EPSILON then return 0 end
    return (x - mean) / stdDev
end

function MathUtils.Skewness(arr)
    local n = #arr
    if n < 3 then return 0 end
    local mean = MathUtils.ArrayMean(arr)
    local stdDev = MathUtils.ArrayStdDev(arr)
    if stdDev < EPSILON then return 0 end
    local sum = 0
    for _, v in ipairs(arr) do
        sum = sum + ((v - mean) / stdDev) ^ 3
    end
    return (n / ((n - 1) * (n - 2))) * sum
end

function MathUtils.Kurtosis(arr)
    local n = #arr
    if n < 4 then return 0 end
    local mean = MathUtils.ArrayMean(arr)
    local stdDev = MathUtils.ArrayStdDev(arr)
    if stdDev < EPSILON then return 0 end
    local sum = 0
    for _, v in ipairs(arr) do
        sum = sum + ((v - mean) / stdDev) ^ 4
    end
    return sum / n - 3
end

function MathUtils.Covariance(x, y, sample)
    local n = math.min(#x, #y)
    if n < 2 then return 0 end
    local meanX = MathUtils.ArrayMean(x)
    local meanY = MathUtils.ArrayMean(y)
    local sum = 0
    for i = 1, n do
        sum = sum + (x[i] - meanX) * (y[i] - meanY)
    end
    if sample then return sum / (n - 1) end
    return sum / n
end

function MathUtils.Percentile(arr, p)
    if #arr == 0 then return nil end
    local sorted = {}
    for _, v in ipairs(arr) do table.insert(sorted, v) end
    table.sort(sorted)
    local index = MathUtils.Saturate(p) * (#sorted - 1) + 1
    local low = math.floor(index)
    local high = math.ceil(index)
    if low == high then return sorted[low] end
    return MathUtils.Lerp(sorted[low], sorted[high], index - low)
end

function MathUtils.InterquartileRange(arr)
    local q1 = MathUtils.Percentile(arr, 0.25)
    local q3 = MathUtils.Percentile(arr, 0.75)
    if not q1 or not q3 then return 0 end
    return q3 - q1
end

function MathUtils.OutlierBounds(arr, factor)
    factor = factor or 1.5
    local q1 = MathUtils.Percentile(arr, 0.25)
    local q3 = MathUtils.Percentile(arr, 0.75)
    if not q1 or not q3 then return nil, nil end
    local iqr = q3 - q1
    return q1 - factor * iqr, q3 + factor * iqr
end

function MathUtils.IsOutlier(value, arr, factor)
    local lo, hi = MathUtils.OutlierBounds(arr, factor)
    if not lo then return false end
    return value < lo or value > hi
end

function MathUtils.EaseInQuad(t) return t * t end
function MathUtils.EaseOutQuad(t) return t * (2 - t) end
function MathUtils.EaseInOutQuad(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
end
function MathUtils.EaseInCubic(t) return t * t * t end
function MathUtils.EaseOutCubic(t)
    local inv = t - 1
    return inv * inv * inv + 1
end
function MathUtils.EaseInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local inv = 2 * t - 2
    return 0.5 * inv * inv * inv + 1
end
function MathUtils.EaseInQuart(t) return t * t * t * t end
function MathUtils.EaseOutQuart(t)
    local inv = t - 1
    return 1 - inv * inv * inv * inv
end
function MathUtils.EaseInQuint(t) return t * t * t * t * t end
function MathUtils.EaseOutQuint(t)
    local inv = t - 1
    return 1 + inv * inv * inv * inv * inv
end
function MathUtils.EaseInSine(t)
    return 1 - math.cos(t * HALF_PI)
end
function MathUtils.EaseOutSine(t)
    return math.sin(t * HALF_PI)
end
function MathUtils.EaseInOutSine(t)
    return -(math.cos(math.pi * t) - 1) / 2
end
function MathUtils.EaseInExpo(t)
    if t <= 0 then return 0 end
    return 2 ^ (10 * (t - 1))
end
function MathUtils.EaseOutExpo(t)
    if t >= 1 then return 1 end
    return 1 - 2 ^ (-10 * t)
end
function MathUtils.EaseInOutExpo(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    if t < 0.5 then return (2 ^ (20 * t - 10)) / 2 end
    return (2 - 2 ^ (-20 * t + 10)) / 2
end
function MathUtils.EaseInCirc(t)
    return 1 - math.sqrt(1 - t * t)
end
function MathUtils.EaseOutCirc(t)
    local inv = t - 1
    return math.sqrt(1 - inv * inv)
end
function MathUtils.EaseInOutCirc(t)
    if t < 0.5 then
        return (1 - math.sqrt(1 - 4 * t * t)) / 2
    end
    return (math.sqrt(1 - ((-2 * t) + 2) ^ 2) + 1) / 2
end
function MathUtils.EaseInBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return c3 * t * t * t - c1 * t * t
end
function MathUtils.EaseOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local inv = t - 1
    return 1 + c3 * inv * inv * inv + c1 * inv * inv
end
function MathUtils.EaseInOutBack(t)
    local c1 = 1.70158
    local c2 = c1 * 1.525
    if t < 0.5 then
        local t2 = 2 * t
        return (t2 * t2 * ((c2 + 1) * t2 - c2)) / 2
    end
    local t2 = 2 * t - 2
    return (t2 * t2 * ((c2 + 1) * t2 + c2) + 2) / 2
end
function MathUtils.EaseInElastic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local c4 = TAU / 3
    return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * c4)
end
function MathUtils.EaseOutElastic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local c4 = TAU / 3
    return (2 ^ (-10 * t)) * math.sin((t * 10 - 0.75) * c4) + 1
end
function MathUtils.EaseInOutElastic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local c5 = TAU / 4.5
    if t < 0.5 then
        return -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * c5)) / 2
    end
    return (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * c5)) / 2 + 1
end
function MathUtils.EaseOutBounce(t)
    local n1 = 7.5625
    local d1 = 2.75
    if t < 1 / d1 then return n1 * t * t end
    if t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    end
    if t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    end
    t = t - 2.625 / d1
    return n1 * t * t + 0.984375
end
function MathUtils.EaseInBounce(t)
    return 1 - MathUtils.EaseOutBounce(1 - t)
end
function MathUtils.EaseInOutBounce(t)
    if t < 0.5 then
        return (1 - MathUtils.EaseOutBounce(1 - 2 * t)) / 2
    end
    return (1 + MathUtils.EaseOutBounce(2 * t - 1)) / 2
end

function MathUtils.Clamp01(x)
    return MathUtils.Saturate(x)
end

function MathUtils.PingPong(x, length)
    if length <= 0 then return 0 end
    local wrapped = MathUtils.Wrap(x, 0, 2 * length)
    if wrapped > length then
        return 2 * length - wrapped
    end
    return wrapped
end

function MathUtils.RepeatRange(x, min, max)
    if max <= min then return min end
    return min + (x - min) % (max - min)
end

function MathUtils.Step(edge, x)
    if x < edge then return 0 end
    return 1
end

function MathUtils.Pulse(x, center, width)
    local d = math.abs(x - center)
    if d < width then return 1 end
    return 0
end

function MathUtils.TriangleWave(x, period)
    period = period or TAU
    local phase = (x % period) / period
    if phase < 0.5 then return phase * 4 - 1 end
    return 3 - phase * 4
end

function MathUtils.SawtoothWave(x, period)
    period = period or TAU
    local phase = (x % period) / period
    return phase * 2 - 1
end

function MathUtils.SquareWave(x, period)
    period = period or TAU
    if (x % period) / period < 0.5 then return 1 end
    return -1
end

function MathUtils.Identity(x)
    return x
end

function MathUtils.Zero()
    return 0
end

function MathUtils.One()
    return 1
end

function MathUtils.Max(...)
    return math.max(...)
end

function MathUtils.Min(...)
    return math.min(...)
end

function MathUtils.Abs(x)
    return math.abs(x)
end

function MathUtils.Floor(x)
    return math.floor(x)
end

function MathUtils.Ceil(x)
    return math.ceil(x)
end

function MathUtils.Round(x)
    return math.floor(x + 0.5)
end

function MathUtils.RoundTo(x, increment)
    if increment <= 0 then return x end
    return math.floor(x / increment + 0.5) * increment
end

function MathUtils.FloorTo(x, increment)
    if increment <= 0 then return x end
    return math.floor(x / increment) * increment
end

function MathUtils.CeilTo(x, increment)
    if increment <= 0 then return x end
    return math.ceil(x / increment) * increment
end

function MathUtils.Fractional(x)
    return x - math.floor(x)
end

function MathUtils.Denormalize(value, min, max)
    return min + value * (max - min)
end

function MathUtils.Normalize(value, min, max)
    if math.abs(max - min) < EPSILON then return 0 end
    return (value - min) / (max - min)
end

function MathUtils.Distance3D(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function MathUtils.Distance2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function MathUtils.ManhattanDistance3D(x1, y1, z1, x2, y2, z2)
    return math.abs(x2 - x1) + math.abs(y2 - y1) + math.abs(z2 - z1)
end

function MathUtils.ManhattanDistance2D(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

function MathUtils.ChebyshevDistance3D(x1, y1, z1, x2, y2, z2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
end

function MathUtils.MinkowskiDistance(a, b, p)
    p = p or 2
    local dx = math.abs(a.X - b.X)
    local dy = math.abs(a.Y - b.Y)
    local dz = math.abs(a.Z - b.Z)
    return (dx ^ p + dy ^ p + dz ^ p) ^ (1 / p)
end

function MathUtils.CosineSimilarity(a, b)
    local denom = a.Magnitude * b.Magnitude
    if denom < EPSILON then return 0 end
    return a:Dot(b) / denom
end

function MathUtils.EuclideanNorm(v)
    return v.Magnitude
end

function MathUtils.ManhattanNorm(v)
    return math.abs(v.X) + math.abs(v.Y) + math.abs(v.Z)
end

function MathUtils.InfinityNorm(v)
    return math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

function MathUtils.PNorm(v, p)
    p = p or 2
    return (math.abs(v.X) ^ p + math.abs(v.Y) ^ p + math.abs(v.Z) ^ p) ^ (1 / p)
end

function MathUtils.Deg2Rad(deg)
    return deg * DEG_TO_RAD
end

function MathUtils.Rad2Deg(rad)
    return rad * RAD_TO_DEG
end

function MathUtils.WrapDegrees(deg)
    return MathUtils.Rad2Deg(MathUtils.WrapAngle(MathUtils.Deg2Rad(deg)))
end

function MathUtils.ShortestRotation(from, to)
    return MathUtils.WrapAngle(to - from)
end

function MathUtils.InterpolateAngle(from, to, t)
    return from + MathUtils.ShortestRotation(from, to) * t
end

function MathUtils.DirectionToCFrame(direction, upVector)
    upVector = upVector or Vector3.new(0, 1, 0)
    local look = direction.Unit
    if math.abs(look:Dot(upVector)) > 0.999 then
        upVector = Vector3.new(1, 0, 0)
    end
    return CFrame.lookAt(Vector3.new(0, 0, 0), look, upVector)
end

function MathUtils.CFrameFromTo(from, to, upVector)
    upVector = upVector or Vector3.new(0, 1, 0)
    return CFrame.lookAt(from, to, upVector)
end

function MathUtils.CFrameRotationBetween(a, b)
    local axis = a:Cross(b)
    if axis.Magnitude < EPSILON then
        return CFrame.new()
    end
    local angle = math.acos(MathUtils.Clamp(a.Unit:Dot(b.Unit), -1, 1))
    return CFrame.fromAxisAngle(axis.Unit, angle)
end

function MathUtils.LerpCFrame(a, b, t)
    local pos = a.Position:Lerp(b.Position, t)
    local rot = a - a.Position
    local rotB = b - b.Position
    local q1 = rot:ToQuaternion()
    local q2 = rotB:ToQuaternion()
    local lerpedQ = q1:Lerp(q2, t)
    return CFrame.new(pos) * CFrame.fromQuaternion(lerpedQ)
end

function MathUtils.SmoothCFrame(current, target, smoothing, deltaTime)
    deltaTime = deltaTime or (1 / 60)
    local alpha = 1 - math.exp(-smoothing * deltaTime)
    local pos = current.Position:Lerp(target.Position, alpha)
    local rot = (current - current.Position):Lerp(target - target.Position, alpha)
    return CFrame.new(pos) * rot
end

function MathUtils.IsFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function MathUtils.IsFiniteVector(value)
    return typeof(value) == "Vector3"
        and MathUtils.IsFiniteNumber(value.X)
        and MathUtils.IsFiniteNumber(value.Y)
        and MathUtils.IsFiniteNumber(value.Z)
end

function MathUtils.SafeDivide(a, b, default)
    if math.abs(b) < EPSILON then return default or 0 end
    return a / b
end

function MathUtils.SafeNormalize(v, default)
    if v.Magnitude < EPSILON then return default or Vector3.new(0, 0, 0) end
    return v.Unit
end

function MathUtils.SafeSqrt(x)
    if x < 0 then return 0 end
    return math.sqrt(x)
end

function MathUtils.SafeAcos(x)
    return math.acos(MathUtils.Clamp(x, -1, 1))
end

function MathUtils.SafeAsin(x)
    return math.asin(MathUtils.Clamp(x, -1, 1))
end

function MathUtils.SafeLog(x)
    if x <= 0 then return 0 end
    return math.log(x)
end

function MathUtils.SafePow(base, exp)
    if base < 0 and exp ~= math.floor(exp) then return 0 end
    return base ^ exp
end

function MathUtils.CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function MathUtils.SumTable(t)
    local sum = 0
    for _, v in pairs(t) do
        if type(v) == "number" then sum = sum + v end
    end
    return sum
end

function MathUtils.MapTable(t, fn)
    local result = {}
    for k, v in pairs(t) do
        result[k] = fn(v, k)
    end
    return result
end

function MathUtils.FilterTable(t, fn)
    local result = {}
    for k, v in pairs(t) do
        if fn(v, k) then
            result[k] = v
        end
    end
    return result
end

function MathUtils.ReduceTable(t, fn, initial)
    local acc = initial
    for k, v in pairs(t) do
        acc = fn(acc, v, k)
    end
    return acc
end

return MathUtils
