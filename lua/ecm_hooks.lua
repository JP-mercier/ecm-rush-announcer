if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

-- Host: every ECM (ours or a client's) is spawned here.
local orig_spawn = ECMJammerBase.spawn
function ECMJammerBase.spawn(pos, rot, battery_life_upgrade_lvl, owner, peer_id, ...)
	local unit = orig_spawn(pos, rot, battery_life_upgrade_lvl, owner, peer_id, ...)
	ECMRush:on_ecm_placed(unit, peer_id, battery_life_upgrade_lvl)
	return unit
end

-- Clients: the host tells everyone the ECM's owner and duration level.
Hooks:PostHook(ECMJammerBase, "sync_setup", "ECMRushAnnouncerSyncSetup", function(self, upgrade_lvl, peer_id)
	ECMRush:on_ecm_placed(self._unit, peer_id, upgrade_lvl)
end)
