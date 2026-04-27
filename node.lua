gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local LOGOS = {
    "logo1.png",
    "logo2.png",
}

local BASE_SIZE = 390     -- reference logo size in pixels
local DEPTH_AMP = 0.30    -- +/-30% size pulse to fake a depth axis

local resources = {"shader.frag"}
for _, name in ipairs(LOGOS) do
    resources[#resources+1] = name
end
util.resource_loader(resources)

math.randomseed(os.time())

local function rand_range(a, b)
    return a + math.random() * (b - a)
end

-- One floater per logo. Position is the logo's centre.
-- The two logos pass through each other freely (no inter-logo collision).
local floaters = {}
for i, name in ipairs(LOGOS) do
    local dir = (i == 1) and 1 or -1
    floaters[i] = {
        file        = name,
        cx          = WIDTH  * (i == 1 and 0.30 or 0.70),
        cy          = HEIGHT * (i == 1 and 0.50 or 0.40),
        vel_x       = rand_range(60, 120) * dir,
        vel_y       = rand_range(40,  90) * dir,
        angle       = rand_range(0, 360),  -- random starting orientation
        spin        = 0,                   -- no rotation until first wall bounce
        depth_phase = rand_range(0, math.pi * 2),
        depth_freq  = rand_range(0.3, 0.7),
    }
end

local last_t = sys.now()

local function size_of(f, now)
    return BASE_SIZE * (1 + DEPTH_AMP * math.sin(now * f.depth_freq + f.depth_phase))
end

-- Reflect off the screen edges. On any hit, randomise the spin and apply
-- a small velocity jitter so motion never settles into a pattern. Speed
-- is clamped so the jitter doesn't compound to extremes over time.
local function bounce(f, now)
    local half = size_of(f, now) / 2
    local hit = false
    if     f.cx < half          then f.cx = 2 * half - f.cx;            f.vel_x = -f.vel_x; hit = true
    elseif f.cx > WIDTH - half  then f.cx = 2 * (WIDTH  - half) - f.cx; f.vel_x = -f.vel_x; hit = true end
    if     f.cy < half          then f.cy = 2 * half - f.cy;            f.vel_y = -f.vel_y; hit = true
    elseif f.cy > HEIGHT - half then f.cy = 2 * (HEIGHT - half) - f.cy; f.vel_y = -f.vel_y; hit = true end
    if not hit then return end

    f.spin  = rand_range(-60, 60)
    f.vel_x = f.vel_x * rand_range(0.85, 1.20)
    f.vel_y = f.vel_y * rand_range(0.85, 1.20)
    local speed  = math.sqrt(f.vel_x * f.vel_x + f.vel_y * f.vel_y)
    local target = math.max(60, math.min(speed, 200))
    f.vel_x = f.vel_x * target / speed
    f.vel_y = f.vel_y * target / speed
end

function node.render()
    gl.clear(0, 0, 0, 1)

    local now = sys.now()
    local dt = math.min(now - last_t, 0.1)
    last_t = now

    shader:use{ Time = now }

    for _, f in ipairs(floaters) do
        f.cx    = f.cx    + f.vel_x * dt
        f.cy    = f.cy    + f.vel_y * dt
        f.angle = f.angle + f.spin  * dt
        bounce(f, now)

        local size = size_of(f, now)
        local img  = _G[f.file:gsub("%.png$", "")]

        gl.pushMatrix()
        gl.translate(f.cx, f.cy)
        gl.rotate(f.angle, 0, 0, 1)
        img:draw(-size / 2, -size / 2, size / 2, size / 2)
        gl.popMatrix()
    end
end
