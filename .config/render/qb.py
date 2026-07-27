# qutebrowser config for the `render` helper — a chromeless, vim-navigable
# viewer for pandoc output. Loaded via `--config-py`, alongside a dedicated
# `--basedir`, so this never touches a normal qutebrowser profile.

config.load_autoconfig(False)

# No chrome: the window is just the page.
c.tabs.show = "never"
c.statusbar.show = "in-mode"
c.scrolling.bar = "never"
c.window.hide_decoration = True
c.window.title_format = "{current_title}"

# Local files only — nothing here needs to reach the network.
c.content.autoplay = False
c.url.default_page = "about:blank"
c.url.start_pages = ["about:blank"]

c.scrolling.smooth = True

config.bind("q", "close")
