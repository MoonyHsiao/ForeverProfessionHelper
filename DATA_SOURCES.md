# Profession skill color data attribution

The numeric threshold records in `OneForAllSkillColors.lua` were extracted from:

- [OneForAll Forever](https://github.com/smoergi/OneForAll_Forever), by Smoergi.
- [OneForAll profession source directory](https://github.com/smoergi/OneForAll_Forever/tree/main/OneForAll/Data/Professions)
- Source license: [GPL-3.0-or-later](https://github.com/smoergi/OneForAll_Forever/blob/main/OneForAll/LICENSE.txt).
- Source files: Alchemy.lua, Tailoring.lua, Blacksmithing.lua, Leatherworking.lua, Engineering.lua, Enchanting.lua, Cooking.lua, FirstAid.lua.

The source contains game-data facts for recipe spell IDs and skill requirements, including `req`, `y` (yellow threshold), `g` (green threshold), and `gr` (gray threshold). The extracted file contains **only numeric identifiers and thresholds**, not OneForAll's recipe descriptions, UI, or program logic.

Extraction: one row per recipe with all numeric fields present and monotonically ordered; invalid/incomplete rows were skipped. There are **2,156 valid records** across eight crafting professions in the source snapshot.

Forever Profession Helper does not use a private OneForAll API, copy its addon files at runtime, or require it as a dependency. These extracted facts should be periodically compared with updates to OneForAll and the Forever game data. Attribution to OneForAll is retained; the original author's GPL-3.0-or-later license governs their original work.

Skill-color logic: required skill is the minimum available level; skill below `y` is orange, from `y` to below `g` is yellow, from `g` to below `gr` is green, and `gr` or above is gray.
