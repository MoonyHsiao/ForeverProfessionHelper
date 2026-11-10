local _, ns = ...
local A = ns.A

-- External Forever-aware recipe data: LibProfessionDB-1.0.
-- An absent or partially parsed catalog MUST NOT produce negative judgments.
local index, covered, records = {}, {}, 0
local nonCrafting = { [182]=true, [393]=true, [356]=true } -- herbalism, skinning, fishing

local function add(itemID, skillID, recipeName)
  itemID = tonumber(itemID)
  if not itemID or itemID < 1 then return end
  local perItem = index[itemID] or {}
  index[itemID] = perItem
  local names = perItem[skillID] or {}
  perItem[skillID] = names
  if #names < 3 then names[#names + 1] = tostring(recipeName or "?") end
end

local function addReagents(skillID, name, recipe)
  if type(recipe.reagents) ~= "table" then return end
  for key, reagent in pairs(recipe.reagents) do
    if type(reagent) == "number" and type(key) == "number" and key > 100 then
      -- Map-style { [itemID] = count }
      add(key, skillID, name)
    elseif type(reagent) == "table" then
      -- Array-style { { itemID=..., count=... }, ... }
      local id = reagent.itemID or reagent.itemId or reagent.id or reagent[1]
      if not id and type(key) == "number" and key > 100 then id = key end
      add(id, skillID, name)
    end
  end
end

function A:LoadRecipeDatabase()
  index, covered, records = {}, {}, 0
  local lib = LibStub and LibStub("LibProfessionDB-1.0", true)
  local status
  if not lib or not lib.IsReady or not lib:IsReady() then
    status = "請先安裝並啟用 LibProfessionDB"
  elseif lib.GetGameVersion and lib:GetGameVersion() ~= "Forever" then
    status = "資料庫並非《永恆》版本"
  elseif not lib.GetRecipes or not lib.GetProfessions then
    status = "LibProfessionDB 缺少必要 API"
  else
    local list = lib:GetProfessions()
    if type(list) == "table" then
      for key, meta in pairs(list) do
        local skillID = type(key) == "number" and key or nil
        if type(meta) == "table" then
          skillID = tonumber(meta.id or meta.skillLineID or meta.skillLineId or skillID)
        elseif type(meta) == "number" then
          skillID = meta
        end
        if skillID then
          local ok, recipes = pcall(lib.GetRecipes, lib, skillID)
          if ok and type(recipes) == "table" then
            local count = 0
            for spellID, entry in pairs(recipes) do
              local recipe = entry
              if type(entry) == "number" and lib.GetRecipe then
                local okRecipe, result = pcall(lib.GetRecipe, lib, skillID, entry)
                if okRecipe then recipe = result end
              end
              if type(recipe) == "table" then
                addReagents(skillID, recipe.name or tostring(spellID), recipe)
                count = count + 1
              end
            end
            if count > 0 then
              covered[skillID] = true
              records = records + count
            end
          end
        end
      end
    end
    if records == 0 then status = "配方索引為空；資料庫格式可能不相容" end
  end
  self.recipeDatabaseReady = records > 0
  self.recipeDatabaseStatus = self.recipeDatabaseReady and records or status
  self:Notify("recipeDB")
  return self.recipeDatabaseReady, self.recipeDatabaseStatus
end

function A:RecipeUsers(itemID)
  local users, found, complete, hasProfession = {}, false, self.recipeDatabaseReady, false
  if not self.initialized then return "unknown", users end
  local uses = index[itemID] or {}
  for _, ch in pairs(self:Store().characters) do
    for id, skill in pairs(ch.professions or {}) do
      hasProfession = true
      local skillID = tonumber(id)
      if not skillID or (not covered[skillID] and not nonCrafting[skillID]) then
        complete = false
      end
      if skillID and uses[skillID] then
        found = true
        users[#users + 1] = (skill.name or tostring(skillID)) .. " (" .. (ch.name or "?") .. ")"
      end
    end
  end
  if found then return "needed", users end
  if complete and hasProfession then return "not_needed", users end
  return "unknown", users
end
