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
  return {
    stock = CopyMap(s.stock),
    produced = CopyMap(s.produced),
    shopping = CopyMap(s.shopping),
    reused = CopyMap(s.reused),
    preparations = CopyMap(s.preparations),
    cost = s.cost,
    unknown = s.unknown,
  }
end
local function Price(itemID)
  if not A.GetPrice then return nil end
  local price, source = A:GetPrice(itemID)
  if source == "auctionator" and type(price) == "number" and price > 0 then
    return price
  end
  return nil
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

-- Returns an isolated trial state, including purchases, intermediate crafts,
-- newly crafted inventory and intermediate output reuse.
function A:SimulateCraftInputs(recipe, times, initialStock, initialProduced, byItem, skillLevel)
  local state = {
    stock = CopyMap(initialStock), produced = CopyMap(initialProduced),
    shopping = {}, reused = {}, preparations = {}, cost = 0, unknown = 0,
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

    -- Direct purchase or unknown-price sourcing.
    local buy = CopyState(s)
    buy.shopping[itemID] = (buy.shopping[itemID] or 0) + need
    local price = Price(itemID)
    if price then buy.cost = buy.cost + price * need
    else buy.unknown = buy.unknown + 1 end
    local best = buy

    -- Shallow recursive make-vs-buy comparison. No cycles or unlearnable
    -- recipes; never choose a producer with only a vendor/drop recipe source.
    if depth < 3 and not active[itemID] then
      for _, producer in ipairs((byItem and byItem[itemID]) or {}) do
        if ProducerValid(producer, skillLevel) then
          local count = math.max(1, math.floor(tonumber(producer.craftedQuantity) or 1))
          local operations = math.ceil(need / count)
          local trial = CopyState(s)
          active[itemID] = true
          trial = craft(trial, producer, operations, depth + 1, active, true)
          active[itemID] = nil
          if trial and (trial.stock[itemID] or 0) >= need then
            trial.stock[itemID] = trial.stock[itemID] - need
            trial.reused[itemID] = (trial.reused[itemID] or 0) + need
            trial.produced[itemID] = math.max(0, (trial.produced[itemID] or 0) - need)
            if trial.unknown < best.unknown or
              (trial.unknown == best.unknown and trial.cost < best.cost) then
              best = trial
            end
          end
        end
      end
    end
    return best
  end
  craft = function(s, targetRecipe, operations, depth, active, preparation)
    for _ = 1, operations do
      for id, quantity in pairs(targetRecipe.reagents or {}) do
        s = acquire(s, id, quantity, depth, active)
      end
      local resultID = tonumber(targetRecipe.craftedItemId)
      if resultID and resultID > 0 then
        local count = math.max(1, math.floor(tonumber(targetRecipe.craftedQuantity) or 1))
        s.stock[resultID] = (s.stock[resultID] or 0) + count
        s.produced[resultID] = (s.produced[resultID] or 0) + count
      end
      if preparation then
        local id = targetRecipe.id
        local record = s.preparations[id] or { recipe = targetRecipe, crafts = 0 }
        record.crafts = record.crafts + 1
        s.preparations[id] = record
      end
    end
    return s
  end
  return craft(state, recipe, times, 0, {}, false)
end
