gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

-- Drop PNGs (with alpha) into this folder and list them here.
-- Rotation cycles through the list, INTERVAL seconds per logo.
local LOGOS = {
    "logo1.png",
    "logo2.png",
}
local INTERVAL = 30

local resources = {"shader.frag"}
for _, name in ipairs(LOGOS) do
    resources[#resources+1] = name
end
util.resource_loader(resources)

local function current_logo()
    local idx = math.floor(os.time() / INTERVAL) % #LOGOS + 1
    return _G[LOGOS[idx]:gsub("%.png$", "")]
end

function node.render()
    gl.clear(0, 0, 0, 1)
    shader:use{
        Effect = math.cos(os.time() * 2) * 3,
    }
    current_logo():draw(util.scale_into(WIDTH, HEIGHT, 400, 400))
end
