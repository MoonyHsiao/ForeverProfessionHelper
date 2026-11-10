local _, ns = ...
local A = ns.A

-- Explicit, isolated exceptions for holes in the strictly trainer-only guide.
-- Derived from OneForAll Forever recipe IDs, skill thresholds and reagents.
-- All four require learning a manual/pattern/quest plan; NEVER label them trainer recipes.
-- {spellID, crafts, expectedGain, colorCode, prerequisites, rawMaterials,
--  {recipeItemID, acquisitionSource}}
local fallback = {}
local function Fill(skillID, fromLevel, throughLevel, recipe)
  fallback[skillID] = fallback[skillID] or {}
  for level = fromLevel, throughLevel do
    fallback[skillID][level] = recipe
  end
end

-- First Aid: Mageweave Bandage; manual sold by Deneb Walker or Balai Lok'Wein.
Fill(129, 210, 239, {10840, 2, 1.5, 2, {}, {{4338, 2}},
  {16113, "Manual: Mageweave Bandage — Deneb Walker / Balai Lok'Wein"}})

-- Blacksmithing: Imperial Plate Leggings, rewarded by its associated quest.
Fill(164, 295, 299, {16730, 1, 1, 1, {}, {{12359, 44}, {7910, 2}},
  {12715, "Quest: Imperial Plate Leggings"}})

-- Leatherworking: Frostsaber Boots; pattern vendor Qia, Winterspring.
Fill(165, 265, 269, {19066, 1, 1, 1, {},
  {{8170, 4}, {15422, 6}, {14341, 1}},
  {15740, "Pattern: Frostsaber Boots — Qia, Winterspring"}})

-- Cooking: Poached Sunscale Salmon; recipe vendor Gikkix, Tanaris.
Fill(185, 280, 284, {18244, 1, 1, 1, {}, {{13760, 1}},
  {13946, "Recipe: Poached Sunscale Salmon — Gikkix, Tanaris"}})

function A:GetRouteFallback(skillID, skillLevel)
  local profession = fallback[tonumber(skillID)]
  return profession and profession[math.floor(tonumber(skillLevel) or 0)]
end
