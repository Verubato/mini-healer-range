# MiniHealerRange reference

## What it does

Shows a warning text (default: big red "No healer in range") on screen when you are
out of range of your group's healer. Works in arenas, battlegrounds, dungeons and
scenarios, each individually toggleable. It does nothing while you yourself are a
healer, and it does not run in the open world or in raid instances.

## Facts

| Item | Value |
| --- | --- |
| Version | 1.5.1 |
| Author | Verz |
| Interface versions (TOC) | 120100, 120007, 120005, 50504, 40402, 38002, 38000, 30405, 20506, 11509 |
| Saved variables | MiniHealerRangeDB |
| Slash commands | /minihr, /mhr (both open the settings panel) |
| Options location | Game options -> AddOns -> MiniHealerRange |
| Bundled libraries | LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibRangeCheck-3.0, MiniFramework |
| Integrations | Fonts registered by other addons via LibSharedMedia appear in the Font dropdown |

## How it works

- Runs only when all of these hold: you are not the healer (assigned role), you are
  inside an instance, and the matching toggle is on: arena -> "Arena", battleground
  -> "Battlegrounds", dungeon or scenario -> "Dungeons". Raid instances and the open
  world are never covered.
- Scans your party or raid members for the assigned HEALER role. If several
  healers are found it prefers one within 25 yards (25 rather than 40 to account
  for Evoker range), then one within 40 yards, then any healer. Distance estimates
  come from LibRangeCheck.
- The warning shows when Blizzard's UnitInRange check says the chosen healer is out
  of range, and hides when in range. Checked every 0.5 seconds while active.
- If there is no healer in the group at all, the warning is hidden (it does not
  warn about a missing healer).
- Test button: toggles a test mode that forces the warning to show anywhere so it
  can be styled and repositioned. Test mode automatically turns off when you enter
  combat.

### Positioning

- Drag the warning text with the left mouse button to move it; the position is
  saved. Default position is top center of the screen, 200 px down.
- The "Lock" option prevents dragging (and mouse interaction).

## Settings

Single options panel. Panel description reads "Increase your awareness."

| Setting | Type | Default | Range / options | Notes |
| --- | --- | --- | --- | --- |
| Arena | checkbox | on | - | Enable in arenas. |
| Battlegrounds | checkbox | off | - | Enable in battlegrounds. |
| Dungeons | checkbox | on | - | Enable in dungeons and scenarios. |
| Lock | checkbox | off | - | Prevents the frame from being dragged. |
| Message | edit box | "No healer in range" | - | The warning text. |
| Size | slider | 24 | 10-120 | Font size (Blizzard caps fonts at 120). |
| Font | dropdown | Friz Quadrata | LibSharedMedia fonts; falls back to 5 built-ins (Friz Quadrata, Arial Narrow, Morpheus, Skurri, Myriad Pro) | |
| Outline | dropdown | Outline | Outline, Thick Outline, Monochrome, None | |
| Colour | color swatch | red (1, 0, 0, 1) | any color + alpha | |
| Test | button | - | - | Toggles test mode on/off. |

There is no reset-to-defaults button; settings live in MiniHealerRangeDB.

## Version-gated behavior

- On Midnight (12.x) clients UnitInRange can return a secret value the addon cannot
  read directly; the warning is then driven by setting the frame's transparency
  from that secret (fully transparent when in range, opaque when out of range)
  instead of showing/hiding the frame. Behavior looks the same to the user.
- On Midnight clients the settings panel cannot be opened during combat; the slash
  command prints "Can't do that during combat." instead.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| No warning ever appears | Check the toggles: Battlegrounds is off by default. The addon only runs inside arenas, battlegrounds, dungeons and scenarios; never in raids or the open world. It also does nothing if you are playing a healer, or if the group has no member with the healer role assigned. |
| Warning does not show in battlegrounds | The "Battlegrounds" checkbox defaults to off; enable it. |
| Warning does not show in raids (or raid content) | Raid instances are not supported; only arena, battleground, dungeon and scenario instance types are checked. |
| Warning shows even though a healer is nearby | The range check uses the assigned healer role and Blizzard's UnitInRange on the chosen healer; role assignments must be correct. With multiple healers it tracks the nearest bucket (25 yd, then 40 yd, then any). |
| Cannot move the text | "Lock" is checked, or the text is not currently shown; click Test to show it, drag it, then click Test again. |
| Test text vanished on its own | Test mode auto-disables when you enter combat. |
| Custom fonts missing from the dropdown | Only fonts registered through LibSharedMedia (usually by a SharedMedia addon) are listed; otherwise the 5 built-in fonts show. |
