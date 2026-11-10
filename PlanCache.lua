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

function A:GetEligibleProfessions()
  local valid = {}
  for id, skill in pairs(self:Character().professions or {}) do
    local skillID = tonumber(id)
    if skillID and (skillID == 182 or skillID == 186 or skillID == 393
      or #self:GetRecipesForSkill(skillID) > 0) then
      valid[#valid + 1] = {
        id = skillID, rank = skill.rank or 0,
        name = self:ProfessionName(skillID, skill.name),
      }
    end
  end
  table.sort(valid, function(a, b) return a.id < b.id end)
  return valid
end

function A:GetStaticPlanSections(skillID)
  if not self.initialized then
    return {route = self:T("CHAR_NOT_READY"), materials = self:T("CHAR_NOT_READY")}
  end
  local valid = self:GetEligibleProfessions()
  if #valid == 0 then
    return {route = self:T("NO_ELIGIBLE"), materials = self:T("NO_ELIGIBLE")}
  end
  local selected = valid[1]
  for _, prof in ipairs(valid) do
    if tonumber(skillID) == prof.id then selected = prof; break end
  end
  self.selectedProfessionID = selected.id
  local guide = self.GetGatheringGuide and self:GetGatheringGuide(selected.id, selected.rank)
  if selected.id == 182 or selected.id == 393 then
    return {route = guide or self:T("GUIDE_UNAVAILABLE"), materials = self:T("GUIDE_UNAVAILABLE")}
  end
  if not self.recipeDatabaseReady then
    return {route = self:T("PLAN_DB"), materials = self:T("PLAN_DB")}
  end

  local capNotice
  local skillState = self:Character().professions[selected.id]
  local rank = tonumber(selected.rank) or 0
  local cap = skillState and tonumber(skillState.max) or 0
  if cap == 75 or cap == 150 or cap == 225 then
    if rank >= cap then
      capNotice = self:T("SKILL_CAP_REACHED", cap)
    elseif rank >= cap - 5 then
      capNotice = self:T("SKILL_CAP_NEAR", cap - rank, cap)
    end
  end
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
    local prepEntries = {}
    for _, entry in ipairs(step[5] or {}) do
      local prepID, count, expected = entry[1], entry[2], entry[3]
      prepEntries[#prepEntries + 1] = {
        id = prepID, count = count, expected = expected,
      }
      prepGain = prepGain + expected
    end
    for _, material in ipairs(step[6] or {}) do
      local id, qty = material[1], material[2]
      materials[id] = (materials[id] or 0) + qty
    end
    local finish = math.min(300, projected + gain)
    local previous = rows[#rows]
    -- Aggregate adjacent levels using the same recipe and skill color.
    -- Keep prerequisite order stable and sum their craft counts/skill gains.
    if previous and previous.spell == spell and previous.color == colorName then
      previous.to = finish
      previous.crafts = previous.crafts + crafts
      for _, prep in ipairs(prepEntries) do
        local existing = previous.prepByID[prep.id]
        if existing then
          existing.count = existing.count + prep.count
          existing.expected = existing.expected + prep.expected
        else
          local combined = {id = prep.id, count = prep.count, expected = prep.expected}
          previous.preparations[#previous.preparations + 1] = combined
          previous.prepByID[prep.id] = combined
        end
      end
    else
      local stage = {from = projected, to = finish, name = name,
        crafts = crafts, color = colorName, preparations = {},
        prepByID = {}, recipe = recipe, spell = spell}
      for _, prep in ipairs(prepEntries) do
        local combined = {id = prep.id, count = prep.count, expected = prep.expected}
        stage.preparations[#stage.preparations + 1] = combined
        stage.prepByID[prep.id] = combined
      end
      rows[#rows + 1] = stage
    end
    projected = finish
    operations = operations + 1
  end

  local lines = {
    selected.name .. " " .. current .. "/300",
    "",
    self:T("PLAN_HEADER", tostring(selected.id), current, math.floor(projected), 300),
    self:T("PLAN_DISCLAIMER"),
  }
  if capNotice then table.insert(lines, 2, capNotice) end
  for i, stage in ipairs(rows) do
    if i > 35 then
      lines[#lines + 1] = self:T("MORE_STAGES")
      break
    end
    for _, entry in ipairs(stage.preparations) do
      local prep = index[entry.id]
      local prepName = (prep and prep.name) or
        (GetSpellInfo and GetSpellInfo(entry.id)) or tostring(entry.id)
      lines[#lines + 1] = self:T("CRAFT_PREREQUISITE_GAIN",
        prepName, entry.count, entry.expected)
    end
    lines[#lines + 1] = string.format("%d-%d: %s x%d [%s]",
      math.floor(stage.from), math.floor(stage.to), stage.name,
      stage.crafts, self:T("COLOR_" .. stage.color))
  end
  if prepGain > 0 then lines[#lines + 1] = self:T("TOTAL_PREP_GAIN", prepGain) end
  if hasGreen then lines[#lines + 1] = self:T("GREEN_FALLBACK") end
  if projected < 300 then lines[#lines + 1] = self:T("PLAN_INCOMPLETE") end

  if guide then lines[#lines + 1] = ""; lines[#lines + 1] = guide end
  local materialLines = {
    selected.name .. " " .. current .. "/300",
    "",
    self:T("SHOPPING"),
  }
  local ids = {}
  for id in pairs(materials) do ids[#ids + 1] = id end
  table.sort(ids)
  if #ids == 0 then
    materialLines[#materialLines + 1] = self:T("MATERIALS_EMPTY")
  end
  for _, id in ipairs(ids) do
    local itemName = (GetItemInfo and GetItemInfo(id)) or self:T("ITEM_FALLBACK", id)
    materialLines[#materialLines + 1] = string.format("  %s x%d", itemName, materials[id])
  end
  return {
    route = table.concat(lines, "\n"),
    materials = table.concat(materialLines, "\n"),
    stages = rows,
    skillCapNotice = capNotice,
    professionName = selected.name,
    currentSkill = current,
    projectedSkill = projected,
    professionID = selected.id,
  }
end

function A:GetCachedPrimaryPlanText(skillID)
  local sections = self:GetStaticPlanSections(skillID)
  return sections.route
end


-- Retain no-op compatibility with older Core.lua callers. Neither function
-- starts calculations, registers workers, or invalidates any generated routes.
function A:InvalidatePlanCache() end
function A:PreparePlanCache() end
