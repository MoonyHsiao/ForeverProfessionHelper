local _, ns = ...
local A = ns.A
-- LibProfessionDB is the source of truth. Never infer "safe to sell" from missing data.
local index, catalog, coverage = {}, {}, {}
local recipesParsed, reagentLinks = 0, 0
local SKILLS = {129,164,165,171,185,186,197,202,333,356,393,755,773}
local function NormalizeReagents(source)
  local out = {}
  if type(source) ~= "table" then return out end
  for key, value in pairs(source) do
    local id, count
    if type(value) == "table" then
      id = tonumber(value.itemID or value.itemId or value.id or value[1])
      count = tonumber(value.quantity or value.count or value.amount or value[2]) or 1
      if not id and type(key) == "number" and key > 100 then id = key end
    elseif type(key) == "number" and key > 100 then
      id, count = key, tonumber(value)
    end
    if id and id > 0 and count and count > 0 then out[id] = (out[id] or 0) + count end
  end
  return out
end

local function Decode(skillID, spellID, info, db)
  if type(info) ~= "table" then return end
  local reagents = NormalizeReagents(info.reagents)
  if not next(reagents) and type(db.GetReagents) == "function" then
    local ok, data = pcall(db.GetReagents, db, skillID, spellID)
    if ok then reagents = NormalizeReagents(data) end
  end
  if not next(reagents) then return end
  local sources, sourceKinds
  if type(db.GetRecipeSources) == "function" then
    local ok, value = pcall(db.GetRecipeSources, db, spellID)
    if ok then sources = value end
  end
  if type(db.GetRecipeSourceKinds) == "function" then
    local ok, value = pcall(db.GetRecipeSourceKinds, db, spellID)
    if ok then sourceKinds = value end
  end
  sourceKinds = type(sourceKinds) == "table" and sourceKinds or {}
  if type(sources) == "table" then
    for kind, entries in pairs(sources) do
      if type(entries) == "table" and (#entries > 0 or (entries.total or 0) > 0) then sourceKinds[kind] = true end
    end
  end
  local difficulty = info.difficulty or {}
  local recipe = {
    id = spellID, skillID = skillID, name = info.name or tostring(spellID),
    reagents = reagents, requiredSkill = tonumber(info.requiredSkill) or tonumber(difficulty[1]) or 1,
    difficulty = difficulty,
    craftedItemId = info.craftedItemId or info.craftedItemID,
    sourceKinds = sourceKinds,
    trainer = sourceKinds.trainer == true,
    trainerNames = {},
    borrowedSources = type(db.IsBorrowed) == "function" and db:IsBorrowed(spellID, "sources") ~= nil,
    requiredSpec = info.requiredSpec,
  }
  if type(sources) == "table" and type(sources.trainer) == "table" then
    for i = 1, math.min(#sources.trainer, 4) do
      local npc = sources.trainer[i]
      if type(npc) == "table" and npc.name then recipe.trainerNames[#recipe.trainerNames + 1] = npc.name end
    end
  end
  if type(db.IsHiddenRecipe) == "function" then
    local ok, hidden = pcall(db.IsHiddenRecipe, db, spellID)
    if ok and hidden then recipe.hidden = true end
  end
  local perSkill = catalog[skillID] or {}
  catalog[skillID] = perSkill
  perSkill[#perSkill + 1] = recipe
  recipesParsed = recipesParsed + 1
  for itemID in pairs(reagents) do
    local uses = index[itemID] or {}
    index[itemID] = uses
    uses[skillID] = true
    reagentLinks = reagentLinks + 1
  end
end

function A:LoadRecipeDatabase()
  index, catalog, coverage, recipesParsed, reagentLinks = {}, {}, {}, 0, 0
  local lib = LibStub and LibStub("LibProfessionDB-1.0", true)
  if not lib then
    self.recipeDatabaseReady = false
    self.recipeDatabaseStatus = "LibProfessionDB 未註冊（確認相依插件）"
    return false, self.recipeDatabaseStatus
  end
  if type(lib.IsReady) ~= "function" or not lib:IsReady() then
    self.recipeDatabaseReady = false
    self.recipeDatabaseStatus = "資料庫尚未就緒"
    return false, self.recipeDatabaseStatus
  end
  if type(lib.GetGameVersion) == "function" and lib:GetGameVersion() ~= "Forever" then
    self.recipeDatabaseReady = false
    self.recipeDatabaseStatus = "非 Forever 配方資料"
    return false, self.recipeDatabaseStatus
  end
  if type(lib.GetRecipes) ~= "function" or type(lib.GetRecipe) ~= "function" then
    self.recipeDatabaseReady = false
    self.recipeDatabaseStatus = "函式庫缺少 GetRecipes / GetRecipe"
    return false, self.recipeDatabaseStatus
  end
  for _, skillID in ipairs(SKILLS) do
    local ok, entries = pcall(lib.GetRecipes, lib, skillID)
    if ok and type(entries) == "table" then
      local before = recipesParsed
      for key, value in pairs(entries) do
        local spellID = type(value) == "number" and value or tonumber(key)
        local recipe = type(value) == "table" and value or nil
        if spellID and not recipe then
          local yes, data = pcall(lib.GetRecipe, lib, skillID, spellID)
          if yes then recipe = data end
        end
        if spellID then Decode(skillID, spellID, recipe, lib) end
      end
      coverage[skillID] = recipesParsed > before
    end
  end
  self.recipeCatalog = catalog
  self.recipeCoverage = coverage
  self.recipeCount = recipesParsed
  self.reagentCount = reagentLinks
  self.recipeDatabaseReady = recipesParsed > 0 and reagentLinks > 0
  self.recipeDatabaseStatus = self.recipeDatabaseReady and recipesParsed or "沒有解析到配方材料"
  self:Notify("recipeDB")
  return self.recipeDatabaseReady, self.recipeDatabaseStatus
end

function A:GetRecipesForSkill(skillID)
  return catalog[tonumber(skillID)] or {}
end

function A:RecipeUsers(itemID)
  local users, found, complete, hasProfession = {}, false, self.recipeDatabaseReady, false
  if not self.initialized then return "unknown", users end
  local uses = index[itemID] or {}
  for _, ch in pairs(self:Store().characters) do
    for id, skill in pairs(ch.professions or {}) do
      local skillID = tonumber(id)
      hasProfession = true
      if not coverage[skillID] and skillID ~= 182 and skillID ~= 393 and skillID ~= 356 then complete = false end
      if uses[skillID] then
        users[#users + 1] = (skill.name or tostring(skillID)) .. " (" .. (ch.name or "?") .. ")"
        found = true
      end
    end
  end
  if found then return "needed", users end
  if complete and hasProfession then return "not_needed", users end
  return "unknown", users
end
