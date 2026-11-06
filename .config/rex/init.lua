rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+space>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind("ctrl+space>ctrl+space", "pane.send_key", { key = "ctrl+space" })
rex.bind("ctrl+space>q", "client.config.reload")

rex.bind("alt+enter", "pane.split", { direction = "down" })
rex.bind("alt+shift+enter", "pane.split", { direction = "right" })
rex.bind("alt+esc", "client.close")

rex.bind("ctrl+space>h", "pane.split", { direction = "down" })
rex.bind("ctrl+space>v", "pane.split", { direction = "right" })
rex.bind("ctrl+space>x", "client.close")
rex.bind("ctrl+space>m", "pane.zoom")
rex.bind("repeat/m", "pane.zoom")

rex.bind("ctrl+alt+left", "pane.focus", { direction = "left" })
rex.bind("ctrl+alt+right", "pane.focus", { direction = "right" })
rex.bind("ctrl+alt+up", "pane.focus", { direction = "up" })
rex.bind("ctrl+alt+down", "pane.focus", { direction = "down" })

rex.bind("ctrl+alt+shift+left", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+alt+shift+down", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+alt+shift+up", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+alt+shift+right", "pane.resize", { amount = 5, direction = "right" })

rex.bind("ctrl+space>r", "client.tab.rename")
rex.bind("ctrl+space>c", "client.tab.new")
rex.bind("ctrl+space>k", "client.tab.close")

rex.bind("alt+1", "client.tab.goto", { index = 1 })
rex.bind("alt+2", "client.tab.goto", { index = 2 })
rex.bind("alt+3", "client.tab.goto", { index = 3 })
rex.bind("alt+4", "client.tab.goto", { index = 4 })
rex.bind("alt+5", "client.tab.goto", { index = 5 })
rex.bind("alt+6", "client.tab.goto", { index = 6 })
rex.bind("alt+7", "client.tab.goto", { index = 7 })
rex.bind("alt+8", "client.tab.goto", { index = 8 })
rex.bind("alt+9", "client.tab.goto", { index = 9 })

rex.bind("alt+left", "client.tab.previous")
rex.bind("alt+right", "client.tab.next")
rex.bind("alt+b", "client.tab.previous")
rex.bind("alt+f", "client.tab.next")

rex.bind("ctrl+space>shift+r", "session.rename")
rex.bind("ctrl+space>shift+c", "session.new")
rex.bind("ctrl+space>shift+k", "session.close")
rex.bind("ctrl+space>shift+p", "session.previous")
rex.bind("ctrl+space>shift+n", "session.next")

rex.bind("alt+up", "session.previous")
rex.bind("alt+down", "session.next")

rex.bind("shift+insert", "pane.paste")
rex.bind("ctrl+insert", "pane.copy")
