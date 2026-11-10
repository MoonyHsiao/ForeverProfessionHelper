-- Run: lua tests/planner_prerequisites.lua (Lua 5.1+)
local ns = { A = {} }
local A = ns.A
function A:GetOneForAllSkillThresholds(skillID, spellID)
  if spellID == 3763 then return {55,85,100,115} end
  if spellID == 3766 then return {100,125,137,150} end
end
function A:EstimateSkillChance(recipe, level)
  local row = self:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
  if not row or level < row[1] or level >= row[4] then return nil, "gray" end
  if level < row[2] then return 1, "orange" end
  if level < row[3] then return 0.75, "yellow" end
  return 0.25, "green"
end
local file = assert(loadfile("CraftingDependencies.lua"))
file("ForeverProfessionHelper", ns)
local fine = {id=3763, skillID=165, name="Fine Leather Belt", trainer=true,
  craftedItemId=4246, craftedQuantity=1, reagents={[2318]=6,[2320]=2},requiredSkill=55}
local dark = {id=3766, skillID=165, name="Dark Leather Belt", trainer=true,
  craftedItemId=4249, craftedQuantity=1,reagents={[4246]=1},requiredSkill=100}
local index = A:BuildCraftingIndex({fine,dark})
local made = A:SimulateCraftInputs(dark, 1, {}, {}, index, 100)
assert(made.preparations[3763] and made.preparations[3763].crafts==1)
assert(math.abs(made.gainedFromPrep-0.25)<0.001)
assert(math.abs(made.gainedFromMain-1)<0.001)
assert(math.abs(made.skill-101.25)<0.001)
assert(not made.shopping[4246])
assert(made.shopping[2318]==6 and made.shopping[2320]==2)
assert(#made.sequence==1 and made.sequence[1].recipe.id==3763)
-- Simulated inventory can supply an intermediate; it is not a live bag read.
local existing = A:SimulateCraftInputs(dark, 1, {[4246]=1}, {}, index, 100)
assert(not existing.preparations[3763])
assert(existing.gainedFromPrep==0)
assert(existing.skill==101)
-- A gray prerequisite can still be made, but awards no skill.
local gray = A:SimulateCraftInputs(dark, 1, {}, {}, index, 120)
assert(gray.gainedFromPrep==0)
print("Prerequisite simulation tests passed.")
