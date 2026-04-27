gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

-- Drop PNGs (with alpha) into this folder and list them here.
-- Rotation cycles through the list, INTERVAL seconds per logo.
local LOGOS = {
    "logo1.png",
    "logo2.png",
}
local INTERVAL = 30

-- Visible logo size and the transparent margin around it that the shader
-- fills with the aura halo. The drawn quad is LOGO_SIZE + 2*GLOW_MARGIN.
local LOGO_SIZE   = 260
local GLOW_MARGIN = 40
local QUAD_SIZE   = LOGO_SIZE + 2 * GLOW_MARGIN
local INSET       = GLOW_MARGIN / QUAD_SIZE

local resources = {"shader.frag"}
for _, name in ipairs(LOGOS) do
    resources[#resources+1] = name
end
util.resource_loader(resources)

local function current_logo()
    local idx = math.floor(os.time() / INTERVAL) % #LOGOS + 1
    return _G[LOGOS[idx]:gsub("%.png$", "")]
end

-- DVD-screensaver bounce. Non-equal velocities so the path doesn't lock
-- into a 45 degree pattern.
local pos_x, pos_y = (WIDTH - QUAD_SIZE) / 2, (HEIGHT - QUAD_SIZE) / 2
local vel_x, vel_y = 70, 53
local last_t = sys.now()

function node.render()
    gl.clear(0, 0, 0, 1)

    local now = sys.now()
    local dt = math.min(now - last_t, 0.1)
    last_t = now

    pos_x = pos_x + vel_x * dt
    pos_y = pos_y + vel_y * dt

    local max_x = WIDTH  - QUAD_SIZE
    local max_y = HEIGHT - QUAD_SIZE
    if pos_x < 0     then pos_x = -pos_x;            vel_x = -vel_x end
    if pos_x > max_x then pos_x = 2 * max_x - pos_x; vel_x = -vel_x end
    if pos_y < 0     then pos_y = -pos_y;            vel_y = -vel_y end
    if pos_y > max_y then pos_y = 2 * max_y - pos_y; vel_y = -vel_y end

    shader:use{
        Time  = now,
        Inset = INSET,
    }
    current_logo():draw(pos_x, pos_y, pos_x + QUAD_SIZE, pos_y + QUAD_SIZE)
end
