if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

if Utils:IsInHeist() then
	ECMRush:toggle()
end
