-- Run from the repository root using Lua 5.1+:
--   lua tests/planner_prerequisites.lua
-- The live WoW client is not required for this isolated planner regression.
local ns = { A = {} }
local A = ns.A
local prices = { [4246] = 100, [2318] = 10, [2320] = 1 }
function A:GetPrice(id) return prices[id], "auctionator" end
function A:GetOneForAllSkillThresholds(skillID, spellID)
  if spellID == 3763 then return {55,85,100,115} end
  if spellID == 3766 then return {100,125,137,150} end
end
function A:EstimateSkillChance(recipe, level)
  local row = self:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
  if level < row[1] or level >= row[4] then return nil, "gray" end
  if level < row[2] then return 1.0, "orange" end
  if level < row[3] then return 0.75, "yellow" end
  return 0.25, "green"
end
local file = assert(loadfile("CraftingDependencies.lua"))
file("ForeverProfessionHelper", ns)
local fineBelt = {
  id = 3763, skillID = 165, name = "Fine Leather Belt", trainer = true,
  craftedItemId = 4246, craftedQuantity = 1,
  reagents = { [2318] = 6, [2320] = 2 }, requiredSkill = 55,
}
local darkBelt = {
  id = 3766, skillID = 165, name = "Dark Leather Belt", trainer = true,
  craftedItemId = 4249, craftedQuantity = 1,
  reagents = { [4246] = 1 }, requiredSkill = 100,
}
local index = A:BuildCraftingIndex({fineBelt, darkBelt})

local made = A:SimulateCraftInputs(darkBelt, 1, {}, {}, index, 100)
assert(made.preparations[3763] and made.preparations[3763].crafts == 1,
  "expected a self-crafted Fine Leather Belt")
assert(math.abs(made.gainedFromPrep - 0.25) < 0.001,
  "a green prerequisite should contribute expected skill")
assert(math.abs(made.gainedFromMain - 1) < 0.001,
  "the following orange parent craft should contribute skill")
assert(math.abs(made.skill - 101.25) < 0.001, "skill progression must include both crafts")
assert(not made.shopping[4246], "do not buy a previously crafted prerequisite")
assert(made.shopping[2318] == 6 and made.shopping[2320] == 2,
  "buy only the prerequisite's raw materials")
assert(#made.sequence == 1 and made.sequence[1].recipe.id == 3763,
  "display prerequisite before parent craft")

prices[4246] = 1
local bought = A:SimulateCraftInputs(darkBelt, 1, {}, {}, index, 100)
assert(not bought.preparations[3763], "use a sufficiently cheap purchased belt")
assert(bought.shopping[4246] == 1, "shopping list should include purchased belt")
assert(math.abs(bought.skill - 101) < 0.001,
  "no prerequisite skill gain when the belt is purchased")

prices[4246] = 100
local grayProducer = {
  id = 3763, skillID = 165, trainer = true, craftedItemId = 4246,
  reagents = {[2318] = 1}, requiredSkill = 55,
}
local grayIndex = A:BuildCraftingIndex({grayProducer, darkBelt})
local gray = A:SimulateCraftInputs(darkBelt, 1, {}, {}, grayIndex, 120)
assert(not gray.gainedFromPrep or gray.gainedFromPrep == 0,
  "gray prerequisite must never award skill")

print("Prerequisite-crafting regression scenarios passed.")
