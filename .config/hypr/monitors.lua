-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Pin 1-9 to main (DP-4), 10 fixed to second (HDMI-A-3), but only when those monitors are actually connected (skip on laptop).
local has_dp4 = o.shell_succeeds(
'for d in /sys/class/drm/card*-DP-4; do [ -e "$d" ] && [ "$(cat "$d/status" 2>/dev/null)" = "connected" ] && exit 0; done; exit 1')
local has_hdmi_a3 = o.shell_succeeds(
'for d in /sys/class/drm/card*-HDMI-A-3; do [ -e "$d" ] && [ "$(cat "$d/status" 2>/dev/null)" = "connected" ] && exit 0; done; exit 1')

if has_dp4 then
  for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-4" })
  end
  hl.workspace_rule({ workspace = "1", monitor = "DP-4", default = true })
end

if has_hdmi_a3 then
  hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-3", persistent = true, default = true })
end

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
