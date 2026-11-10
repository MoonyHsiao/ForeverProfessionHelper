# Forever Profession Helper

A profession leveling and inventory management addon for **World of Warcraft: Forever (1.60.1)**.

Track profession reagents and inventory across characters on the same realm, inspect item tooltips, and get estimated 1–300 profession leveling routes.

> **Development branch — v1.1.6-dev** (based on the v1.0.0 baseline). The current feature baseline has been accepted for release. Profession recipes, trainer locations, skill-up estimates, and compatibility still depend on game/addon data and may be incomplete. See [SPEC.md](SPEC.md) for the requirements.

## Branches and versioning

- **`main`**: the v1.0.0 baseline and future stable releases.
- **`develop`**: ongoing feature development. Changes should be reviewed before merging into `main`.
- Development builds increment **only the patch component**: `v1.1.6-dev` → `v1.1.7-dev` → `v1.1.8-dev`. Do not increase the minor version for ordinary `develop` commits.
- When a set of changes is promoted to the stable `main` branch, bump the stable release to the next minor version (for example, `v1.2.0`) and drop the `-dev` suffix. This repository uses `main`, not `master`.
- After that release, continue new development builds from the released series by increasing only the patch version (for example, `v1.2.1-dev`).
- Keep version numbers synchronized in `ForeverProfessionHelper.toc` and `Core.lua`.

## Requirements

| Addon | Required? | Purpose |
| --- | --- | --- |
| [LibProfessionDB](https://www.curseforge.com/wow/addons/libprofessiondb) | **Yes** | Forever-compatible recipes, including recipes not yet learned. Install the Forever 1.60.1 build (e.g. v1.9.1). |
| [Ace3](https://www.curseforge.com/wow/addons/ace3) | LibProfessionDB dependency | Must load successfully in the Forever client. |
| [LibVersionCheck](https://www.curseforge.com/wow/addons/versioncheck) | LibProfessionDB dependency | Use the Forever-compatible build (shown in-game as `Lib: VersionCheck-1.0`). |
| [OneForAll — Forever](https://github.com/smoergi/OneForAll_Forever) | Optional | Can collect the addon's minimap button into its button bar. |

## Installation

1. Install the Forever-compatible LibProfessionDB build and ensure its dependencies are enabled. Do not assume the library loaded just because CurseForge says it is installed.
2. Copy all `*.lua` files and `ForeverProfessionHelper.toc` into:
   ```text
   Interface/AddOns/ForeverProfessionHelper/
   ```
   Avoid an extra nested directory.
3. At character selection, enable **Forever Profession Helper** and **Lib: ProfessionDB Forever**. If dependencies are reported missing, check Ace3 and LibVersionCheck.
4. In-game, run `/reload` and `/fph db` to check the number of parsed recipes and covered profession IDs.
5. Log into each character at least once, and open each character's bank to update its bank inventory snapshot.

To inspect library registration directly:

```lua
/run print("Lib:", LibStub and LibStub("LibProfessionDB-1.0", true))
```

A table indicates that the library object is registered; `nil` indicates that it is unavailable under this name.

## Language settings

The addon defaults to **Auto**, which follows the language of the WoW client via `GetLocale()`.

- In the addon window, click **Language** to open a dropdown menu and directly select **Auto**, **Traditional Chinese**, **Simplified Chinese**, or **English**. The override is saved account-wide in SavedVariables and takes effect immediately.
- You can also type `/fph lang enUS`, `/fph lang zhTW`, `/fph lang zhCN`, or `/fph lang auto`.
- Client languages other than `zhTW`, `zhCN`, and `enUS` currently use English as the default.
- Core UI, profession names (by profession ID, including offline snapshots), material/tooltips, leveling-plan labels, and guide instructions are localized. English gathering route names are included; Simplified Chinese gathering place and resource names may still use Traditional Chinese source data, and trainer names, recipe names and item names originate from the game or LibProfessionDB and may not match the selected language.
- Switching the addon language does not change the WoW client's language.

## OneForAll minimap button integration

**No registration, API key, or modification to OneForAll is required.**

Forever Profession Helper includes its own 32 × 32 minimap button, designed to be picked up by the **OneForAll minimap button collector**.

- **Left-click:** Open the character and inventory overview.
- **Right-click:** Open profession leveling recommendations.
- **With OneForAll installed:** Open `/ofa` → **Quality of Life** → enable **Collect minimap buttons**. Expand OneForAll's collected-button bar to find the Forever Profession Helper button.
- **Without OneForAll:** The button remains available on the minimap.

**v0.3.4 fix:** `MinimapButton.lua` is now listed in `ForeverProfessionHelper.toc`. In v0.3.3, that omission prevented WoW from loading the button entirely.

Integration is based on the [OneForAll Forever 6.2.2 minimap collector](https://github.com/smoergi/OneForAll_Forever/blob/main/OneForAll/MinimapCollector.lua) and is **not yet verified in-game**. If the button is absent, first confirm that `MinimapButton.lua` exists in the installed addon directory and is listed in the `.toc` file.

## Commands

| Command | Action |
| --- | --- |
| `/fph` | Open character and inventory overview. |
| `/fph plan` | Open the leveling planner for the default recorded profession. |
| `/fph plan 164` | Open the planner for a specific profession ID (164 = Blacksmithing). The UI also provides a profession dropdown listing available professions and current ranks. |
| `/fph db` | Show library status, parsed recipe count, reagent links, and profession coverage. |
| `/fph scan` | Rescan currently accessible bags, bank, and professions. |
| `/fph lang [auto\|enUS\|zhTW\|zhCN]` | Change the addon language; omitting an argument cycles the choices. |
| `/fph help` | Show available commands. |

## Features in the current development build

- **Same-realm inventory:** Track bags, bank and professions across recorded characters; offline stock is a snapshot.
- **Material classification:** Identify materials used by learned professions and show relevant quantities in item tooltips.
- **Leveling guide:** Display a predetermined recipe route by current skill level, prioritizing orange/yellow recipes, with green as fallback. Offline-generated records include approximate material requirements and intermediary skill gains.
- **Intermediate recipes:** Reuse earlier crafted products and simulate up to three levels of same-profession prerequisites.
- **Estimated materials:** Show gross raw-material requirements, **without deducting current inventory**.
- **Gathering guides:** Text reference routes for Herbalism, Mining and Skinning.
- **Trainer hints:** Show learned status when detectable, required skill and trainer/location references.

**No Auctionator integration, background calculation or runtime cost optimization is used for the leveling guide.**

## Reuse of crafted intermediate items (develop)

The planner now simulates **crafted output items** as well as reagent consumption. When an earlier stage creates an item required by a later recipe, the later stage uses the simulated stock before adding additional raw material requirements.

Example: **Fine Leather Belt (item 4246) → Dark Leather Belt**. Belts crafted earlier in the selected route are counted as available materials for the later step. The recommendation output also lists how many intermediate items were reused.

The offline route generator expands selected same-profession intermediate reagents where supported by the source dataset. Intermediate crafts are shown before the stage that consumes them. The recipe output mapping comes from OneForAll Forever for recipes whose LibProfessionDB crafted-item ID is absent. The planner still uses local greedy decisions; it is not yet a globally optimized route. It assumes one crafted item per operation unless recipe yield metadata is explicitly provided, and it only credits outputs with a valid crafted item ID.

Prerequisite crafts now contribute **estimated skill gains** before the parent recipe is simulated. Static route entries already account for estimated prerequisite skill gains and display those estimates next to prerequisite crafts. Yellow/green gains remain probability-based estimates, not guaranteed results. The offline generator compares expected skill gains and raw-material counts, not market prices. Cross-profession crafting is deliberately excluded: prerequisites must belong to the selected profession. An isolated Lua regression script is available at `tests/planner_prerequisites.lua` (not loaded by WoW). See [PLANNER_TEST_CASES.md](PLANNER_TEST_CASES.md) for the expected belt example. Changes in `develop` are not included in stable `main` until merged.

## Offline precomputed leveling routes (develop)

The addon ships a `StaticRoutes.lua` lookup table generated **outside the game** from OneForAll Forever's recipe skill thresholds and reagent data. For each skill level, it contains a reference recipe, approximate craft count, anticipated intermediate crafts and raw-material quantities.

**No runtime route optimizer or background worker is loaded.** Clicking **Leveling Guide** simply reads the current profession skill and displays the corresponding static entries; there is no coroutine, `OnUpdate` planner, inventory-driven reranking or price lookup. A language change only re-renders labels.

The guide is an approximation, and its static selection may not always match trainer availability reported by LibProfessionDB. Not all profession skill levels are covered by the source snapshot; uncovered ranges are shown as incomplete instead of triggering an expensive fallback. Intermediate craft skill gains are estimated using offline skill-color thresholds, not observed success rates.

The raw-material list is an estimate for the displayed static route. It does not subtract live inventory, and no auction or vendor values are used.

## Recipe colors and OneForAll data

Forever Profession Helper now includes `OneForAllSkillColors.lua`, a compact snapshot of 2,156 **numeric** recipe learning requirements and skill-color thresholds (yellow, green, gray), derived from [OneForAll Forever](https://github.com/smoergi/OneForAll_Forever/tree/main/OneForAll/Data/Professions). It does **not** require OneForAll to be installed and does not modify OneForAll. Recipe ingredients and trainer status come from LibProfessionDB; inventory is tracked separately.

The planner prefers orange/yellow recipes before green recipes. Green recipes only appear when no eligible orange/yellow trainer recipe with usable data is available at that skill level. Gray recipes are excluded. It displays the selected color and warns when green is used.

The data may become outdated if OneForAll or WoW Forever changes its recipes. This is an extracted snapshot, **not a runtime connection** to OneForAll. See [DATA_SOURCES.md](DATA_SOURCES.md) for attribution and extraction notes.

## Known limitations

- The leveling algorithm is a **greedy heuristic, not a globally optimal route**. Quantities and expected skill gains remain estimates.
- The UI offers a dropdown for profession selection but does not yet provide a full multi-tab interface. Gathering guidance is static and does not display map routes or live gathering nodes.
- Some trainer sources and skill requirements are borrowed from Vanilla and have not been verified against Forever. Recipes with unverified sources may be excluded.
- Learned-recipe detection can be inconclusive when the profession window is closed. Specialization restrictions may be incomplete.
- Some intermediate materials may not be producible with available trainer recipes; cross-profession crafting is excluded.
- No full in-game compatibility test has been performed. Include Lua errors and the output of `/fph db` when reporting a problem.

## Safety and item handling

The addon **does not** automatically buy, sell, mail, or move items. All inventory actions remain manual. A material not needed by the currently recorded professions may still have quest, trading, or other uses.
