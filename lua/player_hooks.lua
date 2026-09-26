if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

-- Every player's selected deployable and its count, including our own.
Hooks:PostHook(PlayerManager, "set_synced_deployable_equipment", "ECMRushAnnouncerDeployableSync", function(self, peer, deployable, amount)
	ECMRush:on_deployable_sync(peer, deployable, amount)
end)
