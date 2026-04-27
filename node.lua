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

-- 1..2 instances of each logo, decided at startup.
local floaters = {}
for _, name in ipairs(LOGOS) do
    local count = 1 + math.random(0, 1)
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

-- Equal-mass elastic collision between two floaters, treating each as a
-- circle of its current half-size. The cropped logos roughly fit their
-- inscribed circles, so circle-vs-circle reads as logo-vs-logo.
local function collide_pair(a, b, now)
    local ra = size_of(a, now) / 2
    local rb = size_of(b, now) / 2
    local dx, dy = b.cx - a.cx, b.cy - a.cy
    local d2 = dx * dx + dy * dy
    local rsum = ra + rb
    if d2 >= rsum * rsum or d2 < 1e-6 then return end

    local d = math.sqrt(d2)
    local nx, ny = dx / d, dy / d
    local rel_n = (b.vel_x - a.vel_x) * nx + (b.vel_y - a.vel_y) * ny
    if rel_n >= 0 then return end  -- already separating

    a.vel_x = a.vel_x + rel_n * nx
    a.vel_y = a.vel_y + rel_n * ny
    b.vel_x = b.vel_x - rel_n * nx
    b.vel_y = b.vel_y - rel_n * ny

    local push = (rsum - d) / 2
    a.cx = a.cx - nx * push
    a.cy = a.cy - ny * push
    b.cx = b.cx + nx * push
    b.cy = b.cy + ny * push

    a.spin = rand_range(-80, 80)
    b.spin = rand_range(-80, 80)
    clamp_speed(a)
    clamp_speed(b)
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

    -- Pairwise inter-logo collision (every pair, since we have at most 4
    -- floaters this is at most 6 checks per frame).
    for i = 1, #floaters do
        for j = i + 1, #floaters do
            collide_pair(floaters[i], floaters[j], now)
        end
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
