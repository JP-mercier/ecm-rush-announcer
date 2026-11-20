if not _G.ECMRush then
	dofile(ModPath .. "lua/core.lua")
end

-- Other players' chat arrives here before it is shown. Returning early hides the message on
-- this screen only: chat goes straight from the sender to every peer, so nothing can stop it
-- reaching anyone else.
local receive_message_by_peer = ChatManager.receive_message_by_peer
function ChatManager:receive_message_by_peer(channel_id, peer, message, ...)
	if ECMRush.settings.hide_foreign_timers and ECMRush:is_foreign_ecm_message(message) then
		return
	end
	return receive_message_by_peer(self, channel_id, peer, message, ...)
end
