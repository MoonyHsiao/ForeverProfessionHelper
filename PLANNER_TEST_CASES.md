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
7. Do not make assumptions that the optimal earlier craft will always produce the needed ingredient; this fix links **already selected stages**, but is not a full dependency optimizer.

Reference: [OneForAll Forever Leatherworking data](https://github.com/smoergi/OneForAll_Forever/blob/main/OneForAll/Data/Professions/Leatherworking.lua).
