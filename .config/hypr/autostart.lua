-- Extra autostart processes.
-- o.launch_on_start("my-service")
o.exec_on_start("systemctl --user start opentabletdriver")
o.exec_on_start("redlightctl auto")
