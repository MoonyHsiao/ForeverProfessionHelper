# Planner regression scenarios

These are expected behaviors for the **develop** planner implementation. They are manually specified regression scenarios; this file is not an automated WoW-client test.

## Fine Leather Belt -> Dark Leather Belt

The Forever Leatherworking recipe data includes:

- Fine Leather Belt, crafted item ID `4246`, spell ID `3763`.
- Dark Leather Belt, spell ID `3766`, reagent item ID `4246` ×1.

Example: the planned route crafts **3 Fine Leather Belts**, then **2 Dark Leather Belts**, starting with no Fine Leather Belts in character inventory.

Expected simulated stock changes:

| Action | Fine Leather Belt stock | Additional Fine Leather Belt purchases |
| --- | ---: | ---: |
| Initial | 0 | 0 |
| Craft 3 Fine Leather Belts | 3 | 0 |
| Craft 2 Dark Leather Belts | 1 | 0 |

The planner should record **2 reused crafted belts**, not list two Fine Leather Belts as missing materials.

If a later stage requires **4** Fine Leather Belts instead, only the shortage of **1** should appear in the shopping list (unless additional belts are crafted along the route).

## Rules

1. Start with a snapshot of all recorded same-realm bags and bank inventory.
2. Simulate consuming reagents for each planned craft.
3. Add output items to simulated stock **only when the recipe has a valid crafted item ID**.
4. Track how many of these generated outputs later get reused.
5. Keep the original stock snapshot untouched; no actual in-game actions are performed.
6. Items with missing output IDs are **not** credited. Craft quantities and skill-up probabilities are still estimates.
7. Evaluate up to three layers of same-profession prerequisites using a make-versus-buy heuristic. These choices and skill estimates are not a global optimum.

Reference: [OneForAll Forever Leatherworking data](https://github.com/smoergi/OneForAll_Forever/blob/main/OneForAll/Data/Professions/Leatherworking.lua).

## Intermediate crafts that also level the profession

When crafting **Fine Leather Belt** at skill 100 (green), assume an estimated **0.25** skill gain, followed by **Dark Leather Belt** (orange), assumed to award **1.00** skill.

Expected sequence:

1. Craft one Fine Leather Belt (expected +0.25).
2. Use it to craft one Dark Leather Belt (expected +1.00).
3. The model advances from **100 to 101.25** expected skill, not 101.
4. Recalculate recipe color and availability at the new expected skill before the next planned craft.
5. If the Fine Leather Belt is much cheaper to buy, buying may win the make-versus-buy comparison; no prerequisite gain is credited in that case.
6. If the prerequisite is gray at the current skill, it yields **0** expected skill but can still supply an intermediate material.
7. Do not treat a prerequisite from another profession as craftable. Existing stock from another character remains usable.

**Probability model**: orange 1.0, yellow 0.75, green 0.25, gray 0. These are approximate expectations, not deterministic guaranteed skill-ups.

Regression script: `tests/planner_prerequisites.lua`. It is written for Lua 5.1+ with mocked profession records; it must be run separately and is not a WoW addon file.
