local _, ns = ...
local A = ns.A
-- Approximate greedy planner: each step minimizes extra acquisition cost per
-- expected skill point. It is NOT a globally optimal shortest-path solver.
-- Prefer Forever-specific thresholds from OneForAll. Fall back to
-- LibProfessionDB difficulty data for recipes absent from the numeric dataset.
local function SkillChance(recipe, level)
  local color, required
  if A.GetOneForAllSkillColor then
    color, required = A:GetOneForAllSkillColor(recipe.skillID, recipe.id, level)
  end
  if color == "locked" or color == "gray" then return nil end
  if color == "orange" then return 1.0, "orange" end
  if color == "yellow" then return 0.75, "yellow" end
  if color == "green" then return 0.25, "green" end

  local d = recipe.difficulty or {}
  local orange, yellow, green, grey = tonumber(d[1]), tonumber(d[2]), tonumber(d[3]), tonumber(d[4])
  if not orange or not yellow or not green or not grey then return nil end
  if level < (recipe.requiredSkill or 1) then return nil end
  if level < yellow then return 1.0, "orange" end
  if level < green then return 0.75, "yellow" end
  if level < grey then return 0.25, "green" end
  return nil
end
function A:EstimateSkillChance(recipe, level)
  return SkillChance(recipe, level)
end
-- Static leveling heuristic: optimize skill-ups and reagent quantities,
-- independent of any character inventory or Auctionator pricing.
local function Score(recipe, simulatedStock, produced, craftingIndex, level)
  local chance, color = SkillChance(recipe, level)
  if not chance or recipe.hidden or recipe.requiredSpec or not recipe.trainer then return nil end
  local levels = A.GetOneForAllSkillThresholds and A:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
  local required = levels and levels[1] or recipe.requiredSkill
  if not required or required > level then return nil end
  local estimated = A:SimulateCraftInputs(recipe, 1, simulatedStock, produced, craftingIndex, level)
  local gain = estimated.skill - level
  if gain <= 0 or estimated.gainedFromMain <= 0 then return nil end
  local materialUnits = 0
  for _, quantity in pairs(estimated.shopping) do materialUnits = materialUnits + quantity end
  local actualColor = estimated.mainColor or color
  return {effort = materialUnits / gain, expectedGain = gain,
    tier = actualColor == "green" and 1 or 0, color = actualColor}
end

-- Candidate lists are stable for a given profession/skill level. Build them
-- once; changing stock/prices never requires rescanning all recipe metadata.
local candidateIndex = {}
function A:GetLevelingCandidates(skillID, recipes, level)
  skillID = tonumber(skillID)
  local bucket = candidateIndex[skillID]
  if not bucket or bucket.source ~= recipes then
    bucket = {source = recipes, levels = {}}
    candidateIndex[skillID] = bucket
  end
  local key = math.floor(level)
  local candidates = bucket.levels[key]
  if candidates then return candidates end
  candidates = {}
  for _, recipe in ipairs(recipes) do
    if recipe.trainer and not recipe.hidden and not recipe.requiredSpec then
      local required = self.GetOneForAllSkillThresholds
        and self:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
      local minSkill = required and required[1] or recipe.requiredSkill
      if minSkill and minSkill <= key and SkillChance(recipe, key) then
        candidates[#candidates + 1] = recipe
      end
    end
  end
  bucket.levels[key] = candidates
  return candidates
end

function A:PlanProfession(skillID, target, progressYield)
  if not self.recipeDatabaseReady then return nil, self:T("PLAN_DB") end
  local skill = self:Character().professions[tonumber(skillID)]
  if not skill then return nil, self:T("PLAN_NOT_LEARNED_PROF") end
  local current = tonumber(skill.rank) or 1
  target = math.min(300, tonumber(target) or 300)
  local recipes = self:GetRecipesForSkill(skillID)
  if #recipes == 0 then return nil, self:T("PLAN_NO_RECIPES") end
  local stock = {} -- Only simulated crafting outputs; never actual character stock.
  local producedStock, reusedOutputs = {}, {}
  local craftingIndex = self:BuildCraftingIndex(recipes)
  local lines, shopping, steps = {}, {}, 0
  local usedGreen = false
  local diagnostic = { available = #recipes, trainer = 0, learnable = 0, difficultyUnknown = 0 }
  local maxSteps = 300
  while current < target and steps < maxSteps do
    local best, bestScore
    for _, recipe in ipairs(self:GetLevelingCandidates(skillID, recipes, current)) do
      if steps == 0 and recipe.trainer and not recipe.hidden and not recipe.requiredSpec then
        diagnostic.trainer = diagnostic.trainer + 1
        if (recipe.requiredSkill or 9999) <= current then
          diagnostic.learnable = diagnostic.learnable + 1
          if not recipe.difficulty or #recipe.difficulty < 4 then
            diagnostic.difficultyUnknown = diagnostic.difficultyUnknown + 1
          end
        end
      end
      local score = Score(recipe, stock, producedStock, craftingIndex, current)
      if progressYield then progressYield(1, current, target) end
      if score then
        if not bestScore or score.tier < bestScore.tier
          or (score.tier == bestScore.tier and score.effort < bestScore.effort)
          or (score.tier == bestScore.tier and score.effort == bestScore.effort and recipe.id < best.id) then
          best, bestScore = recipe, score
        end
      end
    end
    if not best then break end
    if bestScore.color == "green" then usedGreen = true end
    local times = math.max(1, math.min(20, math.ceil(1 / bestScore.expectedGain)))
    local start = current
    local simulated = self:SimulateCraftInputs(best, times, stock, producedStock, craftingIndex, current)
    stock, producedStock = simulated.stock, simulated.produced
    for id, qty in pairs(simulated.shopping) do
      shopping[id] = (shopping[id] or 0) + qty
    end
    for id, qty in pairs(simulated.reused) do
      reusedOutputs[id] = (reusedOutputs[id] or 0) + qty
    end

    local gain = math.max(0, simulated.skill - current)
    if gain <= 0 then break end
    current = math.min(target, simulated.skill)
    steps = steps + 1
    local last = lines[#lines]
    if last and last.recipe.id == best.id and last.color == bestScore.color then
      last.to = current
      last.crafts = last.crafts + times
      last.prepGain = (last.prepGain or 0) + simulated.gainedFromPrep
      last.mainGain = (last.mainGain or 0) + simulated.gainedFromMain
      last.sequence = last.sequence or {}
      for _, event in ipairs(simulated.sequence or {}) do
        last.sequence[#last.sequence + 1] = event
      end
      for recipeID, prep in pairs(simulated.preparations) do
        local entry = last.preparations[recipeID] or { recipe = prep.recipe, crafts = 0 }
        entry.crafts = entry.crafts + prep.crafts
        entry.expectedGain = (entry.expectedGain or 0) + (prep.expectedGain or 0)
        last.preparations[recipeID] = entry
      end
    else
      lines[#lines + 1] = {
        from = start, to = current, crafts = times, recipe = best,
        color = bestScore.color,
        preparations = simulated.preparations,
        sequence = simulated.sequence,
        prepGain = simulated.gainedFromPrep, mainGain = simulated.gainedFromMain,
      }
    end
  end
  return {
    skillID = skillID, from = skill.rank, to = current, target = target,
    lines = lines, shopping = shopping,
    approximate = true, incomplete = current < target,
    diagnostics = diagnostic,
    usedGreen = usedGreen,
    reusedOutputs = reusedOutputs,
    expectedSkillFromPreparations = (function()
      local total = 0
      for _, stage in ipairs(lines) do total = total + (stage.prepGain or 0) end
      return total
    end)(),
  }
end
function A:RenderPlanSummary(skillID, result)
  if not result then return self:T("PLAN_DB") end
  local textLines = {
    self:T("PLAN_HEADER", tostring(skillID), result.from, math.floor(result.to), result.target),
    self:T("PLAN_DISCLAIMER"),
  }
  for i, stage in ipairs(result.lines) do
    -- Show dependency crafts in execution order (nested prerequisites first).
    -- Consecutive repeats are grouped without changing their order.
    local ordered = {}
    for _, event in ipairs(stage.sequence or {}) do
      local last = ordered[#ordered]
      if last and last.recipe.id == event.recipe.id then
        last.crafts = last.crafts + 1
        last.gain = last.gain + (event.gain or 0)
      else
        ordered[#ordered + 1] = {
          recipe = event.recipe, crafts = 1, gain = event.gain or 0,
        }
      end
    end
    for _, prep in ipairs(ordered) do
      textLines[#textLines + 1] = self:T("CRAFT_PREREQUISITE_GAIN", prep.recipe.name, prep.crafts, prep.gain)
    end
    local r = stage.recipe
    textLines[#textLines + 1] = string.format("%d～%d：%s ×%d [%s]",
      math.floor(stage.from), math.floor(stage.to), r.name, stage.crafts, self:T("COLOR_" .. string.upper(stage.color or "unknown")))
    local learned = self:RecipeLearned(r.id)
    if learned == true then
      textLines[#textLines + 1] = self:T("LEARNED")
    else
      local state = learned == false and self:T("NOT_LEARNED") or self:T("LEARN_UNKNOWN")
      textLines[#textLines + 1] = "  " .. state .. "; " .. self:T("TRAINER_RECIPE")
      textLines[#textLines + 1] = self:T("SKILL_REQUIREMENT", tostring(r.requiredSkill or "?"))
      local shown = 0
      for _, name in ipairs(r.trainerNames or {}) do
        textLines[#textLines + 1] = self:T("TRAINER_AT", name, self:TrainerLocation(r.skillID, name))
        shown = shown + 1
      end
      if shown == 0 then
        local fallback = self:TrainerFallback(r.skillID)
        textLines[#textLines + 1] = self:T("TRAINER_UNCONFIRMED")
        if fallback then
          textLines[#textLines + 1] = self:T("TRAINER_SUGGEST", fallback)
        end
      end
      if r.borrowedSources then
        textLines[#textLines + 1] = self:T("TRAINER_BORROWED")
      end
    end
    if i >= 35 then
      textLines[#textLines + 1] = self:T("MORE_STAGES")
      break
    end
  end
  if (result.expectedSkillFromPreparations or 0) > 0 then
    textLines[#textLines + 1] = self:T("TOTAL_PREP_GAIN", result.expectedSkillFromPreparations)
  end
  if result.usedGreen then textLines[#textLines + 1] = self:T("GREEN_FALLBACK") end
  if result.incomplete then
    textLines[#textLines + 1] = self:T("PLAN_INCOMPLETE")
    local d = result.diagnostics or {}
    textLines[#textLines + 1] = string.format(self:T("PLAN_DIAGNOSTIC"), d.available or 0, d.trainer or 0, d.learnable or 0, d.difficultyUnknown or 0)
  end
  if next(result.reusedOutputs or {}) then
    textLines[#textLines + 1] = self:T("REUSED_OUTPUTS")
    local reusedIDs = {}
    for id in pairs(result.reusedOutputs) do reusedIDs[#reusedIDs + 1] = id end
    table.sort(reusedIDs)
    for _, id in ipairs(reusedIDs) do
      local name = (GetItemInfo and GetItemInfo(id)) or self:T("ITEM_FALLBACK", id)
      textLines[#textLines + 1] = string.format("  %s x%d", name, result.reusedOutputs[id])
    end
  end
  textLines[#textLines + 1] = self:T("SHOPPING")
  local ids = {}
  for id in pairs(result.shopping) do ids[#ids + 1] = id end
  table.sort(ids)
  for i, id in ipairs(ids) do
    textLines[#textLines + 1] = string.format("  %s ×%d", (GetItemInfo and GetItemInfo(id)) or (self:T("ITEM_FALLBACK", id)), result.shopping[id])
    if i >= 35 then textLines[#textLines + 1] = self:T("SHOPPING_MORE"); break end
  end
  return table.concat(textLines, "\n")
end

function A:PlanSummary(skillID, target, progressYield)
  local result, err = self:PlanProfession(skillID, target, progressYield)
  if not result then return err end
  return self:RenderPlanSummary(skillID, result)
end

-- Choose a profession by ID from /fph plan <skillID>, or cycle in UI.
function A:GetEligibleProfessions()
  local valid = {}
  for id, skill in pairs(self:Character().professions or {}) do
    local skillID = tonumber(id)
    if skillID and (#self:GetRecipesForSkill(skillID) > 0 or
      skillID == 182 or skillID == 186 or skillID == 393) then
      valid[#valid + 1] = {
        id = skillID, rank = skill.rank or 0, name = self:ProfessionName(skillID, skill.name),
      }
    end
  end
  table.sort(valid, function(a, b) return a.id < b.id end)
  return valid
end
function A:GetPrimaryPlanText(skillID, progressYield)
  if not self.initialized then return self:T("CHAR_NOT_READY") end
  local valid = self:GetEligibleProfessions()
  if #valid == 0 then return self:T("NO_ELIGIBLE") end
  local selection
  for _, profession in ipairs(valid) do
    if tonumber(skillID) == profession.id then selection = profession; break end
  end
  selection = selection or valid[1]
  self.selectedProfessionID = selection.id
  local guide = self.GetGatheringGuide and self:GetGatheringGuide(selection.id, selection.rank)
  if selection.id == 182 or selection.id == 393 then
    return guide or self:T("GUIDE_UNAVAILABLE")
  end
  local plan = selection.name .. " " .. selection.rank .. "/300\n\n" ..
    self:PlanSummary(selection.id, 300, progressYield)
  if guide then plan = plan .. "\n\n" .. guide end
  return plan
end
