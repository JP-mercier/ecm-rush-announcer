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
- has ECMs left, per the synced deployable count shown on the team HUD

Players who place out of turn simply have fewer ECMs when their turn comes.

Coverage is the longest remaining battery among active ECMs whose owner has
pager jamming. Duration is taken from the placed ECM
(`20s * {1, 1.25, 1.5}[upgrade_lvl]`), so ECM Overdrive is accounted for.
An upgrade level of 3 implies ECM Specialist aced.

ECMs placed before arming are tracked, so arming mid-chain works.

## How it hooks

| File | Hook | Purpose |
|---|---|---|
| `lua/ecm_hooks.lua` | `ECMJammerBase.spawn` (host), `ECMJammerBase:sync_setup` (clients) | Record owner, duration level, placement time |
| `lua/core.lua` | `GameSetupUpdate` | Coverage check, 0.1s interval |
| `lua/menu.lua` | `MenuManagerInitialize`, `LocalizationManagerPostInit` | Options menu |
| `lua/toggle.lua` | keybind | Arm / disarm |

Works as host or client. Pager upgrades are read from `HuskPlayerBase:upgrade_value`,
which is synced when each player spawns.

## Known limitations

- ECMs carried as a Jack of All Trades secondary deployable are not synced to
  other players, so those players read as having 0 ECMs and are never called.
- If more than one player runs the mod and arms it, messages are duplicated.
- ECMs that existed before you joined (drop-in) are not tracked.
