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

Coverage is the longest remaining battery among active ECMs whose owner has
pager jamming. Duration is taken from the placed ECM
(`20s * {1, 1.25, 1.5}[upgrade_lvl]`), so ECM Overdrive is accounted for.
An upgrade level of 3 implies ECM Specialist aced.

ECMs placed before arming are tracked, so arming mid-chain works.

## How it hooks

| File | Hook | Purpose |
|---|---|---|
| `lua/player_hooks.lua` | `PlayerManager:set_synced_deployable_equipment` | Track each player's ECM count |
| `lua/ecm_hooks.lua` | `ECMJammerBase.spawn` (host), `ECMJammerBase:sync_setup` (clients) | Record owner, duration level, placement time |
| `lua/core.lua` | `GameSetupUpdate` | Coverage check, 0.1s interval |
| `lua/menu.lua` | `MenuManagerInitialize`, `LocalizationManagerPostInit` | Options menu |
| `lua/toggle.lua` | keybind | Arm / disarm |

Works as host or client. Pager upgrades are read from `HuskPlayerBase:upgrade_value`,
which is synced when each player spawns.

## Known limitations

- Loadout counts ignore Crime Spree modifiers until the player selects their
  ECMs and the real count syncs.
- If more than one player runs the mod and arms it, messages are duplicated.
- ECMs that existed before you joined (drop-in) are not tracked.
