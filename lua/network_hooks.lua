if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

-- Clients send their synced upgrades as soon as their own player unit exists. Vanilla drops
-- the message if we haven't been told about that unit yet (common between two clients),
-- leaving their husk without affects_pagers for the whole heist. Record it before that check.
Hooks:PreHook(UnitNetworkHandler, "sync_upgrade", "ECMRushAnnouncerSyncUpgrade", function(self, category, upgrade, level, sender)
	ECMRush:on_upgrade_sync(self._verify_sender(sender), category, upgrade)
end)
