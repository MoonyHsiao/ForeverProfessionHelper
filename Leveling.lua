local _, ns = ...
local A = ns.A
-- Approximate greedy planner: each step minimizes extra acquisition cost per
-- expected skill point. It is NOT a globally optimal shortest-path solver.
local function Copper(id)
  if Auctionator and Auctionator.API and Auctionator.API.v1 and
      type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function" then
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID,
      "ForeverProfessionHelper", tonumber(id))
    if ok and type(price) == "number" and price > 0 then return price, "auctionator" end
  end
  if GetItemInfo then
    local _, _, _, _, _, _, _, _, _, _, vendor = GetItemInfo(id)
    if type(vendor) == "number" and vendor > 0 then
      return vendor, "vendor-sell-value"
    end
  end
  return nil, "unknown"
end
function A:GetPrice(itemID)
  return Copper(itemID)
end
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
local function Holdings(self)
  local stock = {}
  for _, ch in pairs(self:Store().characters) do
    for _, place in ipairs({"bags", "bank"}) do
      for id, n in pairs(ch[place] or {}) do
        stock[id] = (stock[id] or 0) + n
      end
    end
  end
  return stock
end
local function Score(recipe, stock, producedStock, byItem, level)
  local chance, color = SkillChance(recipe, level)
  if not chance or chance == 0 then return nil end
  if recipe.hidden or recipe.requiredSpec or not recipe.trainer then return nil end
  local colors = A.GetOneForAllSkillThresholds and A:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
  local required = colors and colors[1] or recipe.requiredSkill
  if (required or 9999) > level then return nil end
  local estimate = A:SimulateCraftInputs(recipe, 1, stock, producedStock, byItem, level)
  local gain = estimate.skill - level
  -- Do not recommend crafting a gray parent recipe just because its
  -- prerequisites happen to award skill points.
  if gain <= 0 or (estimate.gainedFromMain or 0) <= 0 then return nil end
  return { cost = estimate.cost / gain, unknown = estimate.unknown,
    chance = chance, expectedGain = gain, missing = estimate.shopping,
    color = estimate.mainColor or color, tier = (estimate.mainColor or color) == "green" and 1 or 0 }
end
function A:PlanProfession(skillID, target)
  if not self.recipeDatabaseReady then return nil, self:T("PLAN_DB") end
  local skill = self:Character().professions[tonumber(skillID)]
  if not skill then return nil, self:T("PLAN_NOT_LEARNED_PROF") end
  local current = tonumber(skill.rank) or 1
  target = math.min(300, tonumber(target) or 300)
  local recipes = self:GetRecipesForSkill(skillID)
  if #recipes == 0 then return nil, self:T("PLAN_NO_RECIPES") end
  local stock = Holdings(self)
  local producedStock, reusedOutputs = {}, {}
  local craftingIndex = self:BuildCraftingIndex(recipes)
  local lines, shopping, steps, unresolved = {}, {}, 0, false
  local usedGreen = false
  local diagnostic = { available = #recipes, trainer = 0, learnable = 0, difficultyUnknown = 0 }
  local maxSteps = 300
  while current < target and steps < maxSteps do
    local best, bestScore
    for _, recipe in ipairs(recipes) do
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
      if score then
        -- Unknown prices are a fallback, not a reason to hide every recipe.
        if not bestScore or score.tier < bestScore.tier
          or (score.tier == bestScore.tier and score.unknown < bestScore.unknown)
          or (score.tier == bestScore.tier and score.unknown == bestScore.unknown and score.cost < bestScore.cost) then
          best, bestScore = recipe, score
        end
      end
    end
    if not best then break end
    if bestScore.unknown > 0 then unresolved = true end
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
      for recipeID, prep in pairs(simulated.preparations) do
        local entry = last.preparations[recipeID] or { recipe = prep.recipe, crafts = 0 }
        entry.crafts = entry.crafts + prep.crafts
        entry.expectedGain = (entry.expectedGain or 0) + (prep.expectedGain or 0)
        last.preparations[recipeID] = entry
      end
    else
      lines[#lines + 1] = {
        from = start, to = current, crafts = times, recipe = best,
        estimatedCostPerSkill = bestScore.cost,
        color = bestScore.color,
        preparations = simulated.preparations,
        prepGain = simulated.gainedFromPrep, mainGain = simulated.gainedFromMain,
      }
    end
  end
  local totalCost, unknownPrices = 0, {}
  for id, qty in pairs(shopping) do
    local price, source = Copper(id)
    if price and source == "auctionator" then totalCost = totalCost + price * qty
    else unknownPrices[#unknownPrices + 1] = id end
  end
  table.sort(unknownPrices)
  return {
    skillID = skillID, from = skill.rank, to = current, target = target,
    lines = lines, shopping = shopping, estimatedExtraCopper = totalCost,
    unknownPrices = unknownPrices,
    approximate = true, incomplete = current < target, missingPrices = unresolved,
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
function A:PlanSummary(skillID, target)
  local result, err = self:PlanProfession(skillID, target)
  if not result then return err end
  local textLines = {
    self:T("PLAN_HEADER", tostring(skillID), result.from, math.floor(result.to), result.target),
    self:T("PLAN_DISCLAIMER"),
  }
  for i, stage in ipairs(result.lines) do
    local preps = {}
    for _, preparation in pairs(stage.preparations or {}) do
      preps[#preps + 1] = preparation
    end
    table.sort(preps, function(a, b) return a.recipe.id < b.recipe.id end)
    for _, prep in ipairs(preps) do
      textLines[#textLines + 1] = self:T("CRAFT_PREREQUISITE_GAIN", prep.recipe.name, prep.crafts, prep.expectedGain or 0)
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
  textLines[#textLines + 1] = string.format(self:T("COST"),
    math.floor(result.estimatedExtraCopper / 10000),
    math.floor(result.estimatedExtraCopper % 10000 / 100),
    math.floor(result.estimatedExtraCopper % 100))
  if result.missingPrices then textLines[#textLines + 1] = self:T("PRICES_INCOMPLETE") end
  if #result.unknownPrices > 0 then
    textLines[#textLines + 1] = self:T("PRICE_NOTE", #result.unknownPrices)
  end
  return table.concat(textLines, "\n")
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
function A:GetPrimaryPlanText(skillID)
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
    self:PlanSummary(selection.id, 300)
  if guide then plan = plan .. "\n\n" .. guide end
  return plan
end
