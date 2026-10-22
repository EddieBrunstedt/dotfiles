# qutebrowser config for `render`: a chromeless local viewer with its own basedir.

config.load_autoconfig(False)

c.tabs.show = "never"
c.statusbar.show = "in-mode"
c.scrolling.bar = "never"
c.scrolling.smooth = True
c.window.hide_decoration = True
c.window.title_format = "{current_title}"

c.content.autoplay = False
c.url.default_page = "about:blank"
c.url.start_pages = ["about:blank"]

config.bind("q", "close")
