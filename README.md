# ECM Rush Announcer

SuperBLT mod for PAYDAY 2. Posts chat messages during an ECM rush telling the
lobby whose turn it is to place an ECM. No BeardLib dependency.

## Install

Copy the folder into `PAYDAY 2/mods/`. Requires SuperBLT.

Bind the key under **Options > Mod Keybinds > Arm / disarm ECM rush**.

## Usage

Press the keybind in a heist to arm it. Press again to disarm.

Chat output (all toggleable):

| Event | Message |
|---|---|
| Armed | `[ECM] Order: GREEN x2 > BLUE x2 > YELLOW x2` |
| Pager ECM placed | `[ECM] Next: BLUE` |
| Coverage at warning threshold | `[ECM] 5s - BLUE` |

With **Use player names** on, players are named instead of colored, e.g.
`[ECM] Next: Moke`.

Arm/disarm notices are local only. Auto-disarms when the alarm is raised or
when no eligible player has ECMs left.

## Settings

**Options > Mod Options > ECM Rush Announcer**

| Setting | Default |
|---|---|
| Warning time (seconds) | 5 (range 2-15) |
| Announce low coverage | on |
| Announce next player | on |
| Announce order when armed | on |
| Use player names | off |

Saved to `mods/saves/ecm_rush_announcer.json`.

## Turn logic

Order is peer id / name color: 1 GREEN, 2 BLUE, 3 RED, 4 YELLOW.

The next player is the first peer in that order who:

- is in the session and not in custody
- has `ecm_jammer.affects_pagers` (ECM Specialist aced)
- has ECMs left (see below)

Players who place out of turn simply have fewer ECMs when their turn comes.

ECM count per player:

- The game only syncs the count of each player's *selected* deployable
  (`sync_deployable_equipment`). The last ECM count seen for each player is
  kept, so it stays valid after they switch to their other deployable.
- Until a player selects their ECMs, the starting count from their loadout is
  used (outfit fields `deployable_amount` / `secondary_deployable_amount`).
  A Jack of All Trades second deployable gets `ceil(amount / 2)`, so a second
  slot ECM with ECM Specialist is 1.
- After a pager ECM is placed, `Next` is posted once the placer's updated ECM
  count arrives, so it never names someone who just used their last ECM. Falls
  back to posting after 3s if no update arrives. A count update received up to
  0.5s before the ECM itself (network reordering) counts as that placement's.
- Your own count is read directly from `PlayerManager:get_equipment_amount`,
  not from the synced copy.
- A synced ECM count of 0 from a player who hasn't placed an ECM yet is
  ignored, unless their first ECM shows up within 0.5s of it. Entering the
  civilian player state (Golden Grin Casino before taking the gear from the
  guitar case) syncs the selected deployable as 0, and vanilla never sends the
  real count back on exit: `PlayerCivilian:exit` only resyncs when the amount
  is a string, but equipment amounts are tables. Without this, everyone would
  read as having no ECMs until they placed one or switched deployables.

Coverage is the longest remaining battery among active ECMs whose owner has
pager jamming. Duration is taken from the placed ECM
(`20s * {1, 1.25, 1.5}[upgrade_lvl]`), so ECM Overdrive is accounted for.
An upgrade level of 3 implies ECM Specialist aced.

ECMs placed before arming are tracked, so arming mid-chain works.

## How it hooks

| File | Hook | Purpose |
|---|---|---|
| `lua/player_hooks.lua` | `PlayerManager:set_synced_deployable_equipment` | Track each player's ECM count |
| `lua/network_hooks.lua` | `UnitNetworkHandler:sync_upgrade` (pre) | Record pager jamming before vanilla can drop it |
| `lua/ecm_hooks.lua` | `ECMJammerBase.spawn` (host), `ECMJammerBase:sync_setup` (clients) | Record owner, duration level, placement time |
| `lua/core.lua` | `GameSetupUpdate` | Coverage check, 0.1s interval |
| `lua/menu.lua` | `MenuManagerInitialize`, `LocalizationManagerPostInit` | Options menu |
| `lua/toggle.lua` | keybind | Arm / disarm |

Works as host or client.

Pager jamming for other players comes from any of:

- their `sync_upgrade ecm_jammer affects_pagers` message
- `HuskPlayerBase:upgrade_value` (the host's upgrades arrive this way, in its unit's save data)
- a level 3 ECM placed by them

Clients send `sync_upgrade` from `PlayerBase:init`, straight to every peer. Vanilla's
handler drops it when the receiver has no unit for that peer yet, which often happens
between two clients because the unit itself is announced by the host. The husk then never
gets the upgrade, so the mod reads the message in a pre-hook instead, and a husk saying "no"
is never trusted over an earlier "yes".

## Known limitations

- Loadout counts ignore Crime Spree modifiers until the player selects their
  ECMs and the real count syncs.
- If more than one player runs the mod and arms it, messages are duplicated.
- ECMs that existed before you joined (drop-in) are not tracked.
- A player who rejoins after using deployables has their count reset to 0 by
  the drop-in penalty. If you didn't see them place an ECM earlier (you joined
  after they did), that 0 is ignored and their loadout count is used instead.
