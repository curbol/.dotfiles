-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- The TV advertises 119.88 rather than a round 120, and "preferred" picks 60.
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@119.88", position = "auto", scale = 1 })
