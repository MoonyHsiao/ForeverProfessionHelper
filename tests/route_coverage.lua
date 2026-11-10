-- Run from repository root: lua tests/route_coverage.lua
-- No WoW client or LibProfessionDB required. This checks static table coverage.
local ns = { A = {} }
local A = ns.A
assert(loadfile("StaticRoutes.lua"))("ForeverProfessionHelper", ns)
assert(loadfile("RouteFallbacks.lua"))("ForeverProfessionHelper", ns)

local skills = {
  [129] = "First Aid", [164] = "Blacksmithing",
  [165] = "Leatherworking", [171] = "Alchemy",
  [185] = "Cooking", [197] = "Tailoring",
  [202] = "Engineering", [333] = "Enchanting",
}
local exceptions = {
  [129] = {from = 210, through = 239, recipe = 10840, item = 16113},
  [164] = {from = 295, through = 299, recipe = 16730, item = 12715},
  [165] = {from = 265, through = 269, recipe = 19066, item = 15740},
  [185] = {from = 280, through = 284, recipe = 18244, item = 13946},
}
local checked, fallbackCount = 0, 0
for skillID, name in pairs(skills) do
  for level = 1, 299 do
    local entry = A:GetStaticLevelingStep(skillID, level)
    assert(entry, string.format("%s missing level %d", name, level))
    assert(type(entry[1]) == "number" and entry[1] > 0,
      string.format("%s invalid spell at %d", name, level))
    assert(type(entry[2]) == "number" and entry[2] >= 1,
      string.format("%s invalid craft count at %d", name, level))
    assert(type(entry[3]) == "number" and entry[3] > 0,
      string.format("%s no expected skill gain at %d", name, level))
    assert(type(entry[5]) == "table" and type(entry[6]) == "table",
      string.format("%s missing input records at %d", name, level))
    local ex = exceptions[skillID]
    local expected = ex and level >= ex.from and level <= ex.through
    if expected then
      assert(entry[7] and entry[1] == ex.recipe and entry[7][1] == ex.item,
        string.format("%s missing non-trainer disclosure at %d", name, level))
      fallbackCount = fallbackCount + 1
    else
      assert(not entry[7],
        string.format("%s unexpected non-trainer step at %d", name, level))
    end
    checked = checked + 1
  end
end
assert(checked == 2392, "expected eight professions times 299 levels")
assert(fallbackCount == 45, "expected exactly 45 source-marked exceptions")
print("Route coverage passed: 2392/2392 levels, 45 sourced exceptions.")
