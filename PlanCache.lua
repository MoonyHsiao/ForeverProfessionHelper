local _, ns = ...
local A = ns.A

-- No background planner, coroutine, OnUpdate handler or runtime route solver.
-- Recommendations come from StaticRoutes.lua (generated outside WoW).
-- The current skill is the only character-specific input.
local recipeIndexes = {}

local function RecipeIndex(skillID)
  local recipes = A:GetRecipesForSkill(skillID)
  local cached = recipeIndexes[skillID]
  if cached and cached.source == recipes then return cached.bySpell end
  local bySpell = {}
  for _, recipe in ipairs(recipes) do bySpell[tonumber(recipe.id)] = recipe end
  recipeIndexes[skillID] = {source = recipes, bySpell = bySpell}
  return bySpell
end

function A:GetCachedPrimaryPlanText(skillID)
  if not self.initialized then return self:T("CHAR_NOT_READY") end
  local valid = self:GetEligibleProfessions()
  if #valid == 0 then return self:T("NO_ELIGIBLE") end
  local selected = valid[1]
  for _, prof in ipairs(valid) do
    if tonumber(skillID) == prof.id then selected = prof; break end
  end
  self.selectedProfessionID = selected.id
  local guide = self.GetGatheringGuide and self:GetGatheringGuide(selected.id, selected.rank)
  if selected.id == 182 or selected.id == 393 then
    return guide or self:T("GUIDE_UNAVAILABLE")
  end
  if not self.recipeDatabaseReady then return self:T("PLAN_DB") end

  local index = RecipeIndex(selected.id)
  local current = tonumber(selected.rank) or 1
  local projected = current
  local rows, materials = {}, {}
  local hasGreen, prepGain = false, 0
  local operations = 0
  while projected < 300 and operations < 350 do
    local step = self:GetStaticLevelingStep(selected.id, projected)
    if not step then break end
    local spell, crafts, gain, color = step[1], step[2], step[3], step[4]
    if not gain or gain <= 0 then break end
    -- The fixed guide deliberately never re-ranks choices based on bags,
    -- banks, prices, or user interactions.
    local recipe = index[spell]
    local name = (recipe and recipe.name) or
      (GetSpellInfo and GetSpellInfo(spell)) or tostring(spell)
    local colorName = ({"ORANGE", "YELLOW", "GREEN"})[color] or "UNKNOWN"
    if color == 3 then hasGreen = true end
    local prepLines = {}
    for _, entry in ipairs(step[5] or {}) do
      local prepID, count, expected = entry[1], entry[2], entry[3]
      local prep = index[prepID]
      local prepName = (prep and prep.name) or
        (GetSpellInfo and GetSpellInfo(prepID)) or tostring(prepID)
      prepLines[#prepLines + 1] = self:T("CRAFT_PREREQUISITE_GAIN",
        prepName, count, expected)
      prepGain = prepGain + expected
    end
    for _, material in ipairs(step[6] or {}) do
      local id, qty = material[1], material[2]
      materials[id] = (materials[id] or 0) + qty
    end
    local finish = math.min(300, projected + gain)
    rows[#rows + 1] = {from = projected, to = finish, name = name,
      crafts = crafts, color = colorName, preparations = prepLines,
      recipe = recipe, spell = spell}
    projected = finish
    operations = operations + 1
  end

  local lines = {
    selected.name .. " " .. current .. "/300",
    "",
    self:T("PLAN_HEADER", tostring(selected.id), current, math.floor(projected), 300),
    self:T("PLAN_DISCLAIMER"),
  }
  for i, stage in ipairs(rows) do
    for _, prepLine in ipairs(stage.preparations) do
      lines[#lines + 1] = prepLine
    end
    lines[#lines + 1] = string.format("%d-%d: %s x%d [%s]",
      math.floor(stage.from), math.floor(stage.to), stage.name,
      stage.crafts, self:T("COLOR_" .. stage.color))
    if i >= 35 then
      lines[#lines + 1] = self:T("MORE_STAGES")
      break
    end
  end
  if prepGain > 0 then lines[#lines + 1] = self:T("TOTAL_PREP_GAIN", prepGain) end
  if hasGreen then lines[#lines + 1] = self:T("GREEN_FALLBACK") end
  if projected < 300 then lines[#lines + 1] = self:T("PLAN_INCOMPLETE") end

  lines[#lines + 1] = self:T("SHOPPING")
  local ids = {}
  for id in pairs(materials) do ids[#ids + 1] = id end
  table.sort(ids)
  for i, id in ipairs(ids) do
    local itemName = (GetItemInfo and GetItemInfo(id)) or self:T("ITEM_FALLBACK", id)
    lines[#lines + 1] = string.format("  %s x%d", itemName, materials[id])
    if i >= 35 then
      lines[#lines + 1] = self:T("SHOPPING_MORE")
      break
    end
  end
  if guide then lines[#lines + 1] = ""; lines[#lines + 1] = guide end
  return table.concat(lines, "\n")
end

-- Retain no-op compatibility with older Core.lua callers. Neither function
-- starts calculations, registers workers, or invalidates any generated routes.
function A:InvalidatePlanCache() end
function A:PreparePlanCache() end
