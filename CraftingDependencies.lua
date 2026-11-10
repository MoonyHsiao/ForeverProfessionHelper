local _, ns = ...
local A = ns.A

-- Trial-only inventory planner. Nothing here changes real bag or bank items.
-- A producer may be used for an intermediate reagent only if it is a
-- trainer recipe that the current profession level can learn/use.
local function CopyMap(source)
  local out = {}
  for k, v in pairs(source or {}) do out[k] = v end
  return out
end
local function CopyState(s)
  local sequence = {}
  for i, event in ipairs(s.sequence or {}) do
    sequence[i] = { recipe = event.recipe, gain = event.gain }
  end
  local preparations = {}
  for id, row in pairs(s.preparations or {}) do
    preparations[id] = { recipe = row.recipe, crafts = row.crafts, expectedGain = row.expectedGain or 0 }
  end
  return {
    stock = CopyMap(s.stock),
    produced = CopyMap(s.produced),
    shopping = CopyMap(s.shopping),
    reused = CopyMap(s.reused),
    preparations = preparations,
    sequence = sequence,
    skill = s.skill,
    gainedFromPrep = s.gainedFromPrep,
    gainedFromMain = s.gainedFromMain,
    mainColor = s.mainColor,
  }
end
local function ProducerValid(recipe, level)
  if not recipe.trainer or recipe.hidden or recipe.requiredSpec then return false end
  local thresholds = A.GetOneForAllSkillThresholds and
    A:GetOneForAllSkillThresholds(recipe.skillID, recipe.id)
  local required = thresholds and thresholds[1] or recipe.requiredSkill
  return required and required <= level
end

function A:BuildCraftingIndex(recipes)
  local byItem = {}
  for _, recipe in ipairs(recipes or {}) do
    local itemID = tonumber(recipe.craftedItemId)
    if itemID and itemID > 0 and next(recipe.reagents or {}) then
      byItem[itemID] = byItem[itemID] or {}
      byItem[itemID][#byItem[itemID] + 1] = recipe
    end
  end
  return byItem
end

-- Returns an isolated simulation of raw-material needs, intermediate crafts,
-- simulated crafting outputs and their reuse. No external stock or price inputs.
function A:SimulateCraftInputs(recipe, times, initialStock, initialProduced, byItem, skillLevel)
  local state = {
    stock = CopyMap(initialStock), produced = CopyMap(initialProduced),
    shopping = {}, reused = {}, preparations = {}, sequence = {},
    skill = tonumber(skillLevel) or 1,
    gainedFromPrep = 0, gainedFromMain = 0, mainColor = nil,
  }
  local acquire, craft
  acquire = function(s, itemID, need, depth, active)
    itemID, need = tonumber(itemID), tonumber(need) or 0
    if not itemID or need <= 0 then return s end
    local held = math.min(s.stock[itemID] or 0, need)
    s.stock[itemID] = (s.stock[itemID] or 0) - held
    local reused = math.min(s.produced[itemID] or 0, held)
    s.produced[itemID] = (s.produced[itemID] or 0) - reused
    if reused > 0 then s.reused[itemID] = (s.reused[itemID] or 0) + reused end
    need = need - held
    if need <= 0 then return s end

    -- No market pricing or real inventory is consulted. Craft eligible
    -- same-profession intermediates before the parent recipe; select a
    -- producer by expected skill gain, then raw material quantity.
    local best, bestGain, bestUnits = nil, -1, math.huge
    if depth < 3 and not active[itemID] then
      for _, producer in ipairs((byItem and byItem[itemID]) or {}) do
        if ProducerValid(producer, s.skill) then
          local outputCount = math.max(1, math.floor(tonumber(producer.craftedQuantity) or 1))
          local operations = math.ceil(need / outputCount)
          local trial = CopyState(s)
          active[itemID] = true
          trial = craft(trial, producer, operations, depth + 1, active, true)
          active[itemID] = nil
          if trial and (trial.stock[itemID] or 0) >= need then
            trial.stock[itemID] = trial.stock[itemID] - need
            trial.produced[itemID] = math.max(0, (trial.produced[itemID] or 0) - need)
            trial.reused[itemID] = (trial.reused[itemID] or 0) + need
            local gained = trial.skill - s.skill
            local units = 0
            for _, qty in pairs(trial.shopping) do units = units + qty end
            if not best or gained > bestGain or
              (gained == bestGain and units < bestUnits) then
              best, bestGain, bestUnits = trial, gained, units
            end
          end
        end
      end
    end
    if best then return best end
    s.shopping[itemID] = (s.shopping[itemID] or 0) + need
    return s
  end
  craft = function(s, targetRecipe, operations, depth, active, preparation)
    for _ = 1, operations do
      for id, quantity in pairs(targetRecipe.reagents or {}) do
        s = acquire(s, id, quantity, depth, active)
      end
      -- Prerequisites are crafted BEFORE the parent recipe. They may award
      -- skill points, affecting the color/chance of every subsequent craft.
      local probability, color
      if A.EstimateSkillChance then
        probability, color = A:EstimateSkillChance(targetRecipe, math.floor(s.skill))
      end
      local gain = probability or 0
      s.skill = s.skill + gain
      if preparation then
        s.gainedFromPrep = s.gainedFromPrep + gain
      else
        s.gainedFromMain = s.gainedFromMain + gain
        s.mainColor = color or "unknown"
      end
      local resultID = tonumber(targetRecipe.craftedItemId)
      if resultID and resultID > 0 then
        local count = math.max(1, math.floor(tonumber(targetRecipe.craftedQuantity) or 1))
        s.stock[resultID] = (s.stock[resultID] or 0) + count
        s.produced[resultID] = (s.produced[resultID] or 0) + count
      end
      if preparation then
        local id = targetRecipe.id
        local record = s.preparations[id] or { recipe = targetRecipe, crafts = 0, expectedGain = 0 }
        record.crafts = record.crafts + 1
        record.expectedGain = record.expectedGain + gain
        s.preparations[id] = record
        s.sequence[#s.sequence + 1] = { recipe = targetRecipe, gain = gain }
      end
    end
    return s
  end
  return craft(state, recipe, times, 0, {}, false)
end
