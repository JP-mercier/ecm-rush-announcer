if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

-- Maps each toggle's menu id to its settings key.
local TOGGLE_KEYS = {
	ecm_rush_announce_warning = "announce_warning",
	ecm_rush_announce_next = "announce_next",
	ecm_rush_announce_order = "announce_order"
}

Hooks:Add("LocalizationManagerPostInit", "ECMRushAnnouncerLocalization", function(loc)
	loc:add_localized_strings({
		ecm_rush_menu_title = "ECM Rush Announcer",
		ecm_rush_menu_desc = "Chat announcements for ECM rushes. Arm it with the keybind under Mod Keybinds.",
		ecm_rush_warn_seconds_title = "Warning time (seconds)",
		ecm_rush_warn_seconds_desc = "How many seconds of pager coverage are left when the next player is called.",
		ecm_rush_announce_warning_title = "Announce low coverage",
		ecm_rush_announce_warning_desc = "Posts \"[ECM] 5s - BLUE\" when the current ECMs are about to run out.",
		ecm_rush_announce_next_title = "Announce next player",
		ecm_rush_announce_next_desc = "Posts \"[ECM] Next: BLUE\" right after each ECM is placed.",
		ecm_rush_announce_order_title = "Announce order when armed",
		ecm_rush_announce_order_desc = "Posts the lineup, with colors and ECM counts, when you arm the announcer."
	})
end)

Hooks:Add("MenuManagerInitialize", "ECMRushAnnouncerMenu", function(menu_manager)
	MenuCallbackHandler.ecm_rush_callback_warn_seconds = function(self, item)
		ECMRush.settings.warn_seconds = math.round(item:value())
		ECMRush:save_settings()
	end

	MenuCallbackHandler.ecm_rush_callback_toggle = function(self, item)
		local key = TOGGLE_KEYS[item:name()]
		if key then
			ECMRush.settings[key] = item:value() == "on"
			ECMRush:save_settings()
		end
	end

	MenuHelper:LoadFromJsonFile(ECMRush._path .. "menu.json", ECMRush, ECMRush.settings)
end)
