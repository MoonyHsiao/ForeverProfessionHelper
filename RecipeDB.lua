local _, ns = ...
local A = ns.A

-- External Forever-aware recipe data: LibProfessionDB-1.0.
-- An absent or partially parsed catalog MUST NOT produce negative judgments.
local index, covered, records, ingredients = {}, {}, 0, 0
local nonCrafting = { [182]=true, [393]=true, [356]=true } -- herbalism, skinning, fishing

local function add(itemID, skillID, recipeName)
  itemID = tonumber(itemID)
  if not itemID or itemID < 1 then return end
  local perItem = index[itemID] or {}
  index[itemID] = perItem
  local names = perItem[skillID] or {}
  perItem[skillID] = names
  if #names < 3 then names[#names + 1] = tostring(recipeName or "?") end
  ingredients = ingredients + 1
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
  index, covered, records, ingredients = {}, {}, 0, 0
  -- ProfessionDB is the addon folder name; LibProfessionDB-1.0 is its library key.
  -- Never register a third-party library ourselves, as that would mask a missing addon.
  local addonLoaded = false
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    addonLoaded = C_AddOns.IsAddOnLoaded("ProfessionDB")
  elseif IsAddOnLoaded then
    addonLoaded = IsAddOnLoaded("ProfessionDB")
  end
  if not addonLoaded then
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "ProfessionDB") end
  end
  local lib = LibStub and LibStub("LibProfessionDB-1.0", true)
  local status
  if type(LibStub) ~= "function" and type(LibStub) ~= "table" then
    status = "未偵測到 LibStub：請確認 Ace3 及資料庫依賴已啟用"
  elseif not lib then
    status = "找不到 LibProfessionDB-1.0：確認 AddOns 中 ProfessionDB 已啟用、版本為 Forever；插件目錄應為 ProfessionDB"
  elseif type(lib.IsReady) ~= "function" then
    status = "找到資料庫，但缺少 IsReady API（版本不相容）"
  elseif not lib:IsReady() then
    status = "找到 LibProfessionDB，但尚未載入配方資料；請確認安裝 Forever 對應版本"
  elseif lib.GetGameVersion and lib:GetGameVersion() ~= "Forever" then
    status = "資料庫並非《永恆》版本"
  elseif not lib.GetRecipes or not lib.GetProfessions then
    status = "LibProfessionDB 缺少必要 API"
  else
    -- GetProfessions() may return an array, map, or keyed metadata.
    -- Prefer the stable Classic skill-line ids, then supplement from the library.
    local ids = {
      [129]=true, [164]=true, [165]=true, [171]=true, [185]=true,
      [186]=true, [197]=true, [202]=true, [333]=true, [356]=true,
      [393]=true, [755]=true, [773]=true,
    }
    local okList, list = pcall(lib.GetProfessions, lib)
    if okList and type(list) == "table" then
      for key, meta in pairs(list) do
        local candidate
        if type(meta) == "number" then candidate = meta
        elseif type(meta) == "table" then
          candidate = tonumber(meta.id or meta.skillLineID or meta.skillLineId or meta.professionID)
        end
        if candidate then ids[candidate] = true end
        if type(key) == "number" and key > 100 then ids[key] = true end
      end
    end
    for skillID in pairs(ids) do
      local ok, recipes = pcall(lib.GetRecipes, lib, skillID)
      if ok and type(recipes) == "table" then
        local count, before = 0, ingredients
        for spellID, entry in pairs(recipes) do
          local actualSpellID = type(entry) == "number" and entry or tonumber(spellID)
          local recipe = type(entry) == "table" and entry or nil
          if not recipe and actualSpellID and lib.GetRecipe then
            local okRecipe, result = pcall(lib.GetRecipe, lib, skillID, actualSpellID)
            if okRecipe then recipe = result end
          end
          if type(recipe) == "table" then
            -- Some versions expose ingredients through GetReagents rather than inline.
            if type(recipe.reagents) ~= "table" and actualSpellID and lib.GetReagents then
              local okReagents, reagents = pcall(lib.GetReagents, lib, skillID, actualSpellID)
              if okReagents then
                recipe = { name = recipe.name, reagents = reagents }
              end
            end
            addReagents(skillID, recipe.name or tostring(actualSpellID or spellID), recipe)
            count = count + 1
          end
        end
        if count > 0 and ingredients > before then
          covered[skillID] = true
          records = records + count
        end
      end
    end
    if records == 0 then status = "未解析到配方材料；請輸入 /fph db 查看診斷" end
  end
  -- A catalog that yields no usable ingredient ids is not safe for negative labels.
  self.recipeDatabaseReady = records > 0 and ingredients > 0
  self.recipeCount, self.reagentCount = records, ingredients
  self.recipeCoverage = covered
  self.recipeDatabaseStatus = self.recipeDatabaseReady and records or status
  self:Notify("recipeDB")
  return self.recipeDatabaseReady, self.recipeDatabaseStatus
end

function A:RecipeUsers(itemID)
  local users, found, complete, hasProfession = {}, false, self.recipeDatabaseReady and records >= 2000, false
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
