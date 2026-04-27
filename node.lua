gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local LOGOS = {
    "logo1.png",
    "logo2.png",
}

local BASE_SIZE = 390     -- reference logo size in pixels
local DEPTH_AMP = 0.30    -- +/-30% size pulse to fake a depth axis
local MIN_SPEED = 40
local MAX_SPEED = 220

local resources = {"shader.frag"}
for _, name in ipairs(LOGOS) do
    resources[#resources+1] = name
end
util.resource_loader(resources)

math.randomseed(os.time())

local function rand_range(a, b)
    return a + math.random() * (b - a)
end

local function rand_sign()
    return math.random() < 0.5 and -1 or 1
end

-- Each floater is one drawn instance. Multiple floaters can share the
-- same logo file. Position is the logo's centre.
local function spawn_floater(file)
    return {
        file        = file,
        key         = file:gsub("%.png$", ""),
        cx          = rand_range(0.15, 0.85) * WIDTH,
        cy          = rand_range(0.15, 0.85) * HEIGHT,
        vel_x       = rand_range(60, 130) * rand_sign(),
        vel_y       = rand_range(45, 100) * rand_sign(),
        angle       = rand_range(0, 360),
        spin        = 0,                            -- starts still, picks up rotation on first wall bounce
        depth_phase = rand_range(0, math.pi * 2),
        depth_freq  = rand_range(0.25, 0.65),
        flow_phx    = rand_range(0, math.pi * 2),
        flow_phy    = rand_range(0, math.pi * 2),
        flow_fx     = rand_range(0.20, 0.55),
        flow_fy     = rand_range(0.20, 0.55),
    }
end

-- 2..4 instances of each logo, decided at startup.
local floaters = {}
for _, name in ipairs(LOGOS) do
    local count = 2 + math.random(0, 2)
    for _ = 1, count do
        floaters[#floaters + 1] = spawn_floater(name)
    end
end

local last_t = sys.now()

local function size_of(f, now)
    return BASE_SIZE * (1 + DEPTH_AMP * math.sin(now * f.depth_freq + f.depth_phase))
end

-- Keep speed in a band so flow-field forces and bounce jitter neither
-- stall the floater nor pump it to extremes.
local function clamp_speed(f)
    local s = math.sqrt(f.vel_x * f.vel_x + f.vel_y * f.vel_y)
    if s < 1e-3 then
        local a = rand_range(0, math.pi * 2)
        f.vel_x = math.cos(a) * MIN_SPEED
        f.vel_y = math.sin(a) * MIN_SPEED
    elseif s < MIN_SPEED then
        f.vel_x = f.vel_x * MIN_SPEED / s
        f.vel_y = f.vel_y * MIN_SPEED / s
    elseif s > MAX_SPEED then
        f.vel_x = f.vel_x * MAX_SPEED / s
        f.vel_y = f.vel_y * MAX_SPEED / s
    end
end

-- Reflect off the screen edges. On any hit, randomise the spin and
-- apply a small velocity jitter so motion never settles into a pattern.
local function bounce(f, now)
    local half = size_of(f, now) / 2
    local hit  = false
    if     f.cx < half          then f.cx = 2 * half - f.cx;            f.vel_x = -f.vel_x; hit = true
    elseif f.cx > WIDTH - half  then f.cx = 2 * (WIDTH  - half) - f.cx; f.vel_x = -f.vel_x; hit = true end
    if     f.cy < half          then f.cy = 2 * half - f.cy;            f.vel_y = -f.vel_y; hit = true
    elseif f.cy > HEIGHT - half then f.cy = 2 * (HEIGHT - half) - f.cy; f.vel_y = -f.vel_y; hit = true end
    if not hit then return end

    f.spin  = rand_range(-60, 60)
    f.vel_x = f.vel_x * rand_range(0.85, 1.20)
    f.vel_y = f.vel_y * rand_range(0.85, 1.20)
    clamp_speed(f)
end

function node.render()
    gl.clear(0, 0, 0, 1)

    local now = sys.now()
    local dt  = math.min(now - last_t, 0.1)
    last_t    = now

    -- Per-frame physics step: gentle flow-field force gives meandering
    -- curves instead of straight lines; mild damping prevents the field
    -- and bounce jitter from compounding to extremes.
    for _, f in ipairs(floaters) do
        local fx = 35 * math.sin(now * f.flow_fx + f.flow_phx)
        local fy = 35 * math.cos(now * f.flow_fy + f.flow_phy)
        f.vel_x = (f.vel_x + fx * dt) * (1 - 0.10 * dt)
        f.vel_y = (f.vel_y + fy * dt) * (1 - 0.10 * dt)
        clamp_speed(f)

        f.cx    = f.cx    + f.vel_x * dt
        f.cy    = f.cy    + f.vel_y * dt
        f.angle = f.angle + f.spin  * dt
        bounce(f, now)
    end

    -- Depth illusion: draw smaller (further) instances first so the
    -- larger (closer) ones overlap on top of them.
    table.sort(floaters, function(a, b)
        return size_of(a, now) < size_of(b, now)
    end)

    shader:use{ Time = now }
    for _, f in ipairs(floaters) do
        local size = size_of(f, now)
        local img  = _G[f.key]
        gl.pushMatrix()
        gl.translate(f.cx, f.cy)
        gl.rotate(f.angle, 0, 0, 1)
        img:draw(-size / 2, -size / 2, size / 2, size / 2)
        gl.popMatrix()
    end
end
