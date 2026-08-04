-- Drag the selected (or hovered) files out of yazi via dragon-drop.
--
-- dragon-drop rather than yazi's native OSC 72 drag-and-drop because ghostty
-- implements that protocol as a drop *target* only -- it cannot act as a drag
-- source, so dragging out of a ghostty-hosted yazi needs an external GTK
-- window. dragon-drop is a native Wayland client (GTK3 wayland backend).

local function fail(s, ...)
	ya.notify { title = "Dragon", content = string.format(s, ...), timeout = 5, level = "error" }
end

---@return string[]
local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

return {
	entry = function()
		local urls = selected_or_hovered()
		if #urls == 0 then
			return ya.notify { title = "Dragon", content = "No file selected", timeout = 5, level = "warn" }
		end

		-- Leave visual mode once the selection has been read, so yazi is back in
		-- normal mode while the drag window is up.
		ya.emit("escape", { visual = true })

		local child, err = Command("dragon-drop"):arg({ "--all", "--and-exit" }):arg(urls):spawn()
		if not child then
			return fail("Failed to spawn `dragon-drop`: error code %s", err)
		end

		local output, out_err = child:wait_with_output()
		if not output then
			fail("Cannot read `dragon-drop` output: error code %s", out_err)
		elseif not output.status.success then
			fail("`dragon-drop` exited with code %s", output.status.code)
		end
	end,
}
