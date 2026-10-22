require("session"):setup({ sync_yanked = true })

-- Narrow terminals (a tiled corner, a half-screen split) stack the preview
-- across the bottom half instead of squeezing three columns side by side; wide
-- ones keep the stock layout. ratio[3] = 0 still hides the preview.
local STACK_BELOW = 120

local stock = { layout = Tab.layout, build = Tab.build, rails = Rails.build }

local function stacked(c) return c[3].y > c[2].y end

function Tab:layout()
	if self._area.w >= STACK_BELOW then
		return stock.layout(self)
	end
	local ratio = rt.mgr.ratio
	local rows = ui.Layout()
		:direction(ui.Layout.VERTICAL)
		:constraints({ ui.Constraint.Fill(1), ui.Constraint.Percentage(ratio[3] > 0 and 50 or 0) })
		:split(self._area)
	local top = ratio[1] + ratio[2]
	local cols = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({ ui.Constraint.Ratio(ratio[1], top), ui.Constraint.Ratio(ratio[2], top) })
		:split(rows[1])
	self._chunks = { cols[1], cols[2], rows[2] }
end

function Tab:build()
	local c = self._chunks
	if not stacked(c) then
		return stock.build(self)
	end
	local p = c[2].w > 0 and 0 or 1
	self._children = {
		Parent:new(c[1]:pad(ui.Pad(0, p, 0, 1)), self._tab),
		Current:new(c[2]:pad(ui.Pad.x(1)), self._tab),
		Preview:new(c[3]:pad(ui.Pad(1, 1, 0, 1)), self._tab),
		Rails:new(c, self._tab),
		Markers:new(c, self._tab),
	}
end

-- Stacked, the stock right rail would sit on the screen edge; draw a rule above
-- the preview instead. Dragging only applies to the vertical rails, so it's off.
function Rails:build()
	local c, children = self._chunks, {}
	if not stacked(c) then
		return stock.rails(self)
	end
	if c[1].w > 0 then
		children[#children + 1] = Rail:new("rail-left", c[2] { w = math.min(1, c[2].w) }, c)
	end
	if c[3].h > 0 then
		local rule = Rail:new("rail-bottom", c[3] { h = 1 }, c)
		rule.redraw = function(r) return { ui.Bar(ui.Edge.TOP):area(r._area):symbol("─"):style(th.mgr.border_style) } end
		rule.drag = function() end
		children[#children + 1] = rule
	end
	self._children = children
end
