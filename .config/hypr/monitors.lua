-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Pin 1-9 to main (DP-4), 10 fixed to second (HDMI-A-3)
for i = 1, 9 do
  hl.workspace_rule({ workspace = tostring(i), monitor = "DP-4" })
end
hl.workspace_rule({ workspace = "1", monitor = "DP-4", default = true })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-3", persistent = true, default = true })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
