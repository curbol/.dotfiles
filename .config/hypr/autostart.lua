-- Extra autostart processes.

-- The shell's night light service only starts hyprsunset when you toggle it by
-- hand, so the scheduled profiles in hyprsunset.conf need it running already.
o.launch_on_start("hyprsunset")

-- Monitor the line-in as a loopback. The delay lets PipeWire finish enumerating
-- devices, otherwise the capture source isn't there yet to bind to.
o.exec_on_start("sleep 3 && pw-loopback --capture alsa_input.pci-0000_0a_00.4.analog-stereo --latency 50")
