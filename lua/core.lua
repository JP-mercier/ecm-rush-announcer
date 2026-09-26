-- ECM Rush Announcer: shared state, settings and rush logic.
-- Loaded (once) by every other script in this mod.

if _G.ECMRush then
	return
end

ECMRush = {}
ECMRush._path = ModPath
ECMRush._settings_path = SavePath .. "ecm_rush_announcer.json"

ECMRush.settings = {
	warn_seconds = 5,
	announce_order = true,
	announce_next = true,
	announce_warning = true
}

-- Peer ids 1-4 are the name colors, and also the rush order.
ECMRush.COLOR_NAMES = { "GREEN", "BLUE", "RED", "YELLOW" }
ECMRush.PREFIX = "[ECM] "
ECMRush.UPDATE_INTERVAL = 0.1
-- The placer's remaining-ECM count syncs a moment after the ECM itself, so wait before saying who's next.
ECMRush.NEXT_UP_DELAY = 1

ECMRush._armed = false
ECMRush._ecms = {}
ECMRush._pager_cache = {}
ECMRush._ecm_counts = {}
ECMRush._warned = false
ECMRush._next_up_t = nil
ECMRush._update_t = 0

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
function ECMRush:load_settings()
	local file = io.open(self._settings_path, "r")
	if not file then
		return
	end
	local ok, data = pcall(json.decode, file:read("*all"))
	file:close()
	if ok and type(data) == "table" then
		for k, v in pairs(data) do
			if self.settings[k] ~= nil then
				self.settings[k] = v
			end
		end
	end
end

function ECMRush:save_settings()
	local file = io.open(self._settings_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

----------------------------------------------------------------
-- Chat helpers
----------------------------------------------------------------
function ECMRush:say(message)
	if managers.chat and managers.network:session() then
		managers.chat:send_message(ChatManager.GAME, nil, self.PREFIX .. message)
	end
end

-- Only shown on your own screen.
function ECMRush:notify(message)
	if managers.chat then
		managers.chat:_receive_message(ChatManager.GAME, "ECM Rush", message, tweak_data.system_chat_color)
	end
end

----------------------------------------------------------------
-- Peer queries
----------------------------------------------------------------
function ECMRush:session()
	return managers.network and managers.network:session()
end

function ECMRush:peer(peer_id)
	local session = self:session()
	return session and session:peer(peer_id)
end

-- True if this peer has ECM Specialist aced (the only source of pager jamming).
-- The upgrade is synced to every player when their character spawns.
function ECMRush:blocks_pagers(peer)
	local key = peer:user_id() or peer:id()
	local value

	if peer == self:session():local_peer() then
		value = managers.player:has_category_upgrade("ecm_jammer", "affects_pagers")
	else
		local unit = peer:unit()
		if alive(unit) and unit:base() and unit:base().upgrade_value then
			value = unit:base():upgrade_value("ecm_jammer", "affects_pagers") and true or false
		end
	end

	if value ~= nil then
		self._pager_cache[key] = value
	end

	return self._pager_cache[key] or false
end

-- Called for every deployable count sync (local player included).
-- Only the selected deployable is synced, so remember the last ECM count we saw:
-- it stays valid after the player switches to their other deployable.
function ECMRush:on_deployable_sync(peer, deployable, amount)
	if peer and deployable == "ecm_jammer" then
		self._ecm_counts[peer:user_id() or peer:id()] = amount or 0
	end
end

-- Starting ECMs from the loadout. A Jack of All Trades second deployable gets half, rounded up.
function ECMRush:loadout_ecm_count(peer)
	local outfit = peer:blackmarket_outfit()
	if not outfit then
		return 0
	end
	if outfit.deployable == "ecm_jammer" then
		return outfit.deployable_amount or 0
	end
	if outfit.secondary_deployable == "ecm_jammer" then
		return outfit.secondary_deployable_amount or 0
	end
	return 0
end

-- Remaining ECMs: the last synced ECM count, or the loadout count if they haven't selected ECMs yet.
function ECMRush:ecm_count(peer)
	local synced = managers.player:get_synced_deployable_equipment(peer:id())
	if synced and synced.deployable == "ecm_jammer" then
		self:on_deployable_sync(peer, synced.deployable, synced.amount)
	end

	local known = self._ecm_counts[peer:user_id() or peer:id()]
	if known then
		return known
	end
	return self:loadout_ecm_count(peer)
end

function ECMRush:is_eligible(peer)
	if not self:blocks_pagers(peer) then
		return false
	end
	if managers.trade and managers.trade:is_peer_in_custody(peer:id()) then
		return false
	end
	return self:ecm_count(peer) > 0
end

-- First player in color order who still has pager-blocking ECMs.
-- Out-of-turn placements fix themselves: that player just has fewer ECMs left when their turn comes.
function ECMRush:next_peer()
	for peer_id = 1, #self.COLOR_NAMES do
		local peer = self:peer(peer_id)
		if peer and self:is_eligible(peer) then
			return peer
		end
	end
end

function ECMRush:color_name(peer)
	return self.COLOR_NAMES[peer:id()] or ("PLAYER " .. tostring(peer:id()))
end

----------------------------------------------------------------
-- ECM tracking
----------------------------------------------------------------
function ECMRush:now()
	return TimerManager:game():time()
end

function ECMRush:on_ecm_placed(unit, peer_id, upgrade_lvl)
	if not alive(unit) then
		return
	end

	upgrade_lvl = math.clamp(upgrade_lvl or 1, 1, #ECMJammerBase.battery_life_multiplier)

	local peer = peer_id and peer_id > 0 and self:peer(peer_id)
	-- Level 3 duration needs ECM Specialist aced, so it always blocks pagers.
	local pagers = upgrade_lvl == 3
	if peer then
		if pagers then
			self._pager_cache[peer:user_id() or peer:id()] = true
		else
			pagers = self:blocks_pagers(peer)
		end
	end

	local duration = tweak_data.upgrades.ecm_jammer_base_battery_life * ECMJammerBase.battery_life_multiplier[upgrade_lvl]

	self._ecms[unit:key()] = {
		unit = unit,
		pagers = pagers,
		expire_t = self:now() + duration
	}

	if self._armed and pagers and self.settings.announce_next then
		self._next_up_t = self:now() + self.NEXT_UP_DELAY
	end
end

-- Seconds of pager coverage left (the longest-lasting active pager ECM).
function ECMRush:coverage()
	local now = self:now()
	local best = 0

	for key, ecm in pairs(self._ecms) do
		local remaining = ecm.expire_t - now
		local base = alive(ecm.unit) and ecm.unit:base()
		if not base or base._battery_empty or remaining <= 0 then
			self._ecms[key] = nil
		elseif ecm.pagers and remaining > best then
			best = remaining
		end
	end

	return best
end

----------------------------------------------------------------
-- Arming
----------------------------------------------------------------
function ECMRush:in_stealth()
	local groupai = managers.groupai and managers.groupai:state()
	return groupai and groupai:whisper_mode() or false
end

function ECMRush:order_string()
	local parts = {}
	for peer_id = 1, #self.COLOR_NAMES do
		local peer = self:peer(peer_id)
		if peer and self:is_eligible(peer) then
			table.insert(parts, string.format("%s x%d", self:color_name(peer), self:ecm_count(peer)))
		end
	end
	return table.concat(parts, " > ")
end

function ECMRush:arm()
	if not self:session() or not managers.groupai then
		return
	end
	if not self:in_stealth() then
		self:notify("Can't arm: the alarm is already up.")
		return
	end

	local order = self:order_string()
	if order == "" then
		self:notify("Can't arm: nobody with ECM Specialist aced has ECMs left.")
		return
	end

	self._armed = true
	self._warned = false
	self._next_up_t = nil

	self:notify("ECM rush armed.")
	if self.settings.announce_order then
		self:say("Order: " .. order)
	end
end

function ECMRush:disarm(reason)
	self._armed = false
	self._next_up_t = nil
	self:notify("ECM rush disarmed" .. (reason and (": " .. reason) or "."))
end

function ECMRush:toggle()
	if self._armed then
		self:disarm()
	else
		self:arm()
	end
end

----------------------------------------------------------------
-- Update loop
----------------------------------------------------------------
function ECMRush:update(t, dt)
	if not self._armed then
		return
	end

	self._update_t = self._update_t - dt
	if self._update_t > 0 then
		return
	end
	self._update_t = self.UPDATE_INTERVAL

	if not self:session() then
		self._armed = false
		return
	end

	if not self:in_stealth() then
		self:disarm("alarm raised")
		return
	end

	local now = self:now()
	local coverage = self:coverage()
	local warn_s = self.settings.warn_seconds

	if self._next_up_t and now >= self._next_up_t then
		self._next_up_t = nil
		local peer = self:next_peer()
		if peer then
			self:say("Next: " .. self:color_name(peer))
		end
	end

	if coverage > warn_s then
		-- A fresh ECM went down, so allow the next warning.
		self._warned = false
	elseif coverage > 0 and not self._warned then
		self._warned = true
		local peer = self:next_peer()
		if peer then
			if self.settings.announce_warning then
				self:say(string.format("%ds - %s", math.ceil(coverage), self:color_name(peer)))
			end
		else
			self:notify("Nobody has pager ECMs left.")
		end
	elseif coverage <= 0 and not self:next_peer() and not self._next_up_t then
		self:disarm("everyone is out of ECMs")
	end
end

Hooks:Add("GameSetupUpdate", "ECMRushAnnouncerUpdate", function(t, dt)
	ECMRush:update(t, dt)
end)

ECMRush:load_settings()
