gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local LOGOS = {
    "logo1.png",
    "logo2.png",
}

-- Visible logo size and the transparent margin around it that the shader
-- fills with the aura halo. The drawn quad is LOGO_SIZE + 2*GLOW_MARGIN.
local LOGO_SIZE   = 390
local GLOW_MARGIN = 15
local QUAD_SIZE   = LOGO_SIZE + 2 * GLOW_MARGIN
local INSET       = GLOW_MARGIN / QUAD_SIZE
local LOGO_RADIUS = LOGO_SIZE / 2

local resources = {"shader.frag"}
for _, name in ipairs(LOGOS) do
    resources[#resources+1] = name
end
util.resource_loader(resources)

local function logo_image(filename)
    return _G[filename:gsub("%.png$", "")]
end

-- One floater per logo. Position is the top-left of the (logo + glow) quad.
-- Initial velocities use mismatched components so the path doesn't lock to
-- a 45 degree pattern.
local floaters = {
    {
        file  = "logo1.png",
        pos_x = WIDTH  * 0.25 - QUAD_SIZE / 2,
        pos_y = HEIGHT * 0.50 - QUAD_SIZE / 2,
        vel_x =  80,
        vel_y =  53,
    },
    {
        file  = "logo2.png",
        pos_x = WIDTH  * 0.75 - QUAD_SIZE / 2,
        pos_y = HEIGHT * 0.40 - QUAD_SIZE / 2,
        vel_x = -67,
        vel_y =  71,
    },
}

local last_t = sys.now()

local function reflect_walls(f)
    local max_x = WIDTH  - QUAD_SIZE
    local max_y = HEIGHT - QUAD_SIZE
    if f.pos_x < 0     then f.pos_x = -f.pos_x;            f.vel_x = -f.vel_x end
    if f.pos_x > max_x then f.pos_x = 2 * max_x - f.pos_x; f.vel_x = -f.vel_x end
    if f.pos_y < 0     then f.pos_y = -f.pos_y;            f.vel_y = -f.vel_y end
    if f.pos_y > max_y then f.pos_y = 2 * max_y - f.pos_y; f.vel_y = -f.vel_y end
end

-- Equal-mass elastic collision between the two logos, treating each as a
-- circle of LOGO_RADIUS centred on the quad. Glow halos overlap freely;
-- only the visible logo shapes interact.
local function collide(a, b)
    local ax = a.pos_x + QUAD_SIZE / 2
    local ay = a.pos_y + QUAD_SIZE / 2
    local bx = b.pos_x + QUAD_SIZE / 2
    local by = b.pos_y + QUAD_SIZE / 2
    local dx, dy = bx - ax, by - ay
    local d2 = dx * dx + dy * dy
    local r  = 2 * LOGO_RADIUS
    if d2 >= r * r or d2 < 1e-6 then return end

    local d = math.sqrt(d2)
    local nx, ny = dx / d, dy / d
    local rel_n = (b.vel_x - a.vel_x) * nx + (b.vel_y - a.vel_y) * ny
    if rel_n >= 0 then return end  -- already separating

    a.vel_x = a.vel_x + rel_n * nx
    a.vel_y = a.vel_y + rel_n * ny
    b.vel_x = b.vel_x - rel_n * nx
    b.vel_y = b.vel_y - rel_n * ny

    -- Push apart so they don't stay overlapping after the bounce.
    local push = (r - d) / 2
    a.pos_x = a.pos_x - nx * push
    a.pos_y = a.pos_y - ny * push
    b.pos_x = b.pos_x + nx * push
    b.pos_y = b.pos_y + ny * push
end

function node.render()
    gl.clear(0, 0, 0, 1)

    local now = sys.now()
    local dt = math.min(now - last_t, 0.1)
    last_t = now

    for _, f in ipairs(floaters) do
        f.pos_x = f.pos_x + f.vel_x * dt
        f.pos_y = f.pos_y + f.vel_y * dt
        reflect_walls(f)
    end
    collide(floaters[1], floaters[2])

    shader:use{
        Time  = now,
        Inset = INSET,
    }
    for _, f in ipairs(floaters) do
        logo_image(f.file):draw(
            f.pos_x, f.pos_y,
            f.pos_x + QUAD_SIZE, f.pos_y + QUAD_SIZE
        )
    end
end
