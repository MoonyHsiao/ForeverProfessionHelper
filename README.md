# Forever Profession Helper

A profession leveling and inventory management addon for **World of Warcraft: Forever (1.60.1)**.

Track profession reagents and inventory across characters on the same realm, inspect item tooltips, and get estimated 1–300 profession leveling routes.

> **Development build — v0.4.1.** The addon has not been comprehensively tested in-game. Recipe metadata, trainer locations, price estimates, and UI behavior may be incomplete or inaccurate. See [SPEC.md](SPEC.md) for the agreed feature requirements.

## Requirements

| Addon | Required? | Purpose |
| --- | --- | --- |
| [LibProfessionDB](https://www.curseforge.com/wow/addons/libprofessiondb) | **Yes** | Forever-compatible recipes, including recipes not yet learned. Install the Forever 1.60.1 build (e.g. v1.9.1). |
| [Ace3](https://www.curseforge.com/wow/addons/ace3) | LibProfessionDB dependency | Must load successfully in the Forever client. |
| [LibVersionCheck](https://www.curseforge.com/wow/addons/versioncheck) | LibProfessionDB dependency | Use the Forever-compatible build (shown in-game as `Lib: VersionCheck-1.0`). |
| [Auctionator](https://www.curseforge.com/wow/addons/auctionator) | Optional | Supplies previously scanned auction prices for leveling cost estimates. |
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
| `/fph plan 164` | Open the planner for a specific profession ID (164 = Blacksmithing). The UI also provides a profession-switch button. |
| `/fph db` | Show library status, parsed recipe count, reagent links, and profession coverage. |
| `/fph scan` | Rescan currently accessible bags, bank, and professions. |
| `/fph lang [auto\|enUS\|zhTW\|zhCN]` | Change the addon language; omitting an argument cycles the choices. |
| `/fph help` | Show available commands. |

## Features in the current development build

- **Same-realm character tracking:** Save observed professions, bag inventory, and bank inventory snapshots. Offline inventory is not live.
- **Item tooltips:** Display recorded quantities by character and detected profession uses.
- **Conservative material classification:** Build a reverse reagent index from LibProfessionDB. Uncertain items are **not** labeled safe to sell.
- **Crafting route estimates:** Suggest trainer-sourced recipes based on current skill, known materials, and estimated additional spend using an approximate greedy algorithm.
- **Auctionator price lookup:** Use `Auctionator.API.v1.GetAuctionPriceByItemID` when prices are available.
- **Shopping estimates:** Show missing material quantities after subtracting recorded same-realm stock and subtotal the materials with known prices.
- **Gathering guides:** Text-only 1–300 guidance for Herbalism, Mining, and Skinning. Zones and skill thresholds are reference data and still need Forever-specific verification.
- **Trainer hints:** Show recipe learning status when detectable, required skill, trainer names when present in the data, and known location hints. Some locations are from Classic/Vanilla and may not be accurate for Forever. A fallback profession trainer is **not a guarantee** that the NPC teaches a particular recipe.

## Known limitations

- The leveling algorithm is a **greedy estimate, not a globally optimized cheapest path**. Craft counts depend on estimated skill-up chances; shopping quantities are not exact.
- The UI can cycle between professions but does not yet provide a full multi-tab interface. Gathering guidance is static and does not display map routes or live gathering nodes.
- Some trainer sources and skill requirements are borrowed from Vanilla and have not been verified against Forever. Recipes with unverified sources may be excluded.
- A vendor item's **sell price is not its purchase price**. If Auctionator has no usable price, the material is marked as unknown-cost; trainer recipes can still be suggested, but a minimum-cost claim cannot be guaranteed.
- Learned-recipe detection can be inconclusive when the profession window is closed. Specialization restrictions may be incomplete.
- Intermediate crafted reagents (such as smelted bars) are not automatically expanded into their inputs. Auction taxes and available auction quantities are not modeled.
- No full in-game compatibility test has been performed. Include Lua errors and the output of `/fph db` when reporting a problem.

## Safety and item handling

The addon **does not** automatically buy, sell, mail, or move items. All inventory actions remain manual. A material not needed by the currently recorded professions may still have quest, trading, or other uses.
