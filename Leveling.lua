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
local function SkillChance(recipe, level)
  local d = recipe.difficulty or {}
  local orange, yellow, green, grey = tonumber(d[1]), tonumber(d[2]), tonumber(d[3]), tonumber(d[4])
  if not orange or not yellow or not green or not grey then return nil end
  if level < orange then return 1 end
  if level < yellow then return 1 end
  if level < green then return 0.65 end
  if level < grey then return 0.3 end
  return 0
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
local function Score(recipe, stock, level)
  local chance = SkillChance(recipe, level)
  if not chance or chance == 0 then return nil end
  if recipe.hidden or recipe.requiredSpec or not recipe.trainer then return nil end
  if (recipe.requiredSkill or 9999) > level then return nil end
  local total, unknown, missing = 0, 0, {}
  for id, qty in pairs(recipe.reagents) do
    local deficit = math.max(0, qty - (stock[id] or 0))
    if deficit > 0 then
      missing[id] = deficit
      local price, source = Copper(id)
      if not price then unknown = unknown + 1
      elseif source == "vendor-sell-value" then
        -- Vendor sell value is NOT a known purchase price.
        unknown = unknown + 1
      else total = total + price * deficit end
    end
  end
  if unknown > 0 then return { unknown = unknown, chance = chance, missing = missing } end
  return { cost = total / chance, chance = chance, missing = missing }
end
function A:PlanProfession(skillID, target)
  if not self.recipeDatabaseReady then return nil, "配方資料庫未就緒" end
  local skill = self:Character().professions[tonumber(skillID)]
  if not skill then return nil, "目前角色尚未學習這個專業" end
  local current = tonumber(skill.rank) or 1
  target = math.min(300, tonumber(target) or 300)
  local recipes = self:GetRecipesForSkill(skillID)
  if #recipes == 0 then return nil, "沒有可用的製造配方；採集專業請參考文字指南" end
  local stock = Holdings(self)
  local lines, shopping, steps, unresolved = {}, {}, 0, false
  local maxSteps = 300
  while current < target and steps < maxSteps do
    local best, bestScore, unknownCount
    for _, recipe in ipairs(recipes) do
      local score = Score(recipe, stock, current)
      if score and score.cost and (not bestScore or score.cost < bestScore.cost) then
        best, bestScore = recipe, score
      elseif score and score.unknown then
        unknownCount = (unknownCount or 0) + 1
      end
    end
    if not best then
      unresolved = (unknownCount or 0) > 0
      break
    end
    local times = math.max(1, math.ceil(1 / bestScore.chance))
    local start = current
    for _ = 1, times do
      for id, qty in pairs(best.reagents) do
        local onHand = math.min(stock[id] or 0, qty)
        stock[id] = (stock[id] or 0) - onHand
        local need = qty - onHand
        if need > 0 then shopping[id] = (shopping[id] or 0) + need end
      end
    end
    current = current + 1 -- expected skill gain; recipe counts are estimates
    steps = steps + 1
    local last = lines[#lines]
    if last and last.recipe.id == best.id then
      last.to = current
      last.crafts = last.crafts + times
    else
      lines[#lines + 1] = {
        from = start, to = current, crafts = times, recipe = best,
        estimatedCostPerSkill = bestScore.cost,
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
  }
end
function A:PlanSummary(skillID, target)
  local result, err = self:PlanProfession(skillID, target)
  if not result then return err end
  local textLines = {
    "專業 " .. tostring(skillID) .. "，預估 " .. result.from .. " → " .. result.to .. " / " .. result.target,
    "規劃：貪婪估算，非全域最佳解；技能機率與材料數皆為預估。",
  }
  for i, stage in ipairs(result.lines) do
    local r = stage.recipe
    local trainer = #r.trainerNames > 0 and table.concat(r.trainerNames, "、") or "訓練師位置未確認"
    if r.borrowedSources then trainer = trainer .. "（來源借用 Vanilla，待驗證）" end
    textLines[#textLines + 1] = string.format("%d～%d：%s ×%d；%s",
      stage.from, stage.to, r.name, stage.crafts, trainer)
    if i >= 35 then
      textLines[#textLines + 1] = "其餘階段未顯示；可提高專業等級後重新查看。"
      break
    end
  end
  if result.incomplete then
    textLines[#textLines + 1] = "路線未完成：缺可學訓練師配方、價格未知或技能區間無法覆蓋。"
  end
  textLines[#textLines + 1] = "缺少材料（跨角色庫存已扣除）："
  local ids = {}
  for id in pairs(result.shopping) do ids[#ids + 1] = id end
  table.sort(ids)
  for i, id in ipairs(ids) do
    textLines[#textLines + 1] = string.format("  %s ×%d", (GetItemInfo and GetItemInfo(id)) or ("物品 " .. id), result.shopping[id])
    if i >= 35 then textLines[#textLines + 1] = "購物清單較長，僅顯示前 35 項"; break end
  end
  textLines[#textLines + 1] = string.format("已知 Auctionator 額外成本：%dg %ds %dc",
    math.floor(result.estimatedExtraCopper / 10000),
    math.floor(result.estimatedExtraCopper % 10000 / 100),
    math.floor(result.estimatedExtraCopper % 100))
  if #result.unknownPrices > 0 then
    textLines[#textLines + 1] = "注意：" .. #result.unknownPrices .. " 種材料價格未知，以上不是總成本。"
  end
  return table.concat(textLines, "\n")
end
