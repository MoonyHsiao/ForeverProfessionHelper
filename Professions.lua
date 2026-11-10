local _, ns = ...
local A = ns.A
function A:ScanProfessions()
  if not self.initialized or not GetProfessions or not GetProfessionInfo then return end
  local indexes = { GetProfessions() }
  local found = {}
  for i = 1, 5 do
    local index = indexes[i]
    if index then
      local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
      if name and skillLine then
        found[skillLine] = { name = name, rank = rank or 0, max = maxRank or 0 }
      end
    end
  end
  local ch = self:Character()
  ch.professions = found
  ch.professionUpdated = self:Time()
  self:Notify("professions")
end
-- Only records recipe ingredients actually exposed by the client.
-- It is NOT a complete 1–300 catalog.
function A:ScanKnownRecipes()
  if not self.initialized then return end
  local api = C_TradeSkillUI
  if not api or not api.GetAllRecipeIDs or not api.GetRecipeInfo or not api.GetRecipeSchematic then return end
  local ok, recipes = pcall(api.GetAllRecipeIDs)
  if not ok or type(recipes) ~= "table" then return end
  local observed = {}
  for _, recipeID in ipairs(recipes) do
    local okInfo, info = pcall(api.GetRecipeInfo, recipeID)
    if okInfo and type(info) == "table" and info.learned and info.professionID then
      local okScheme, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
      if okScheme and type(schematic) == "table" then
        for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
          for _, reagent in ipairs(slot.reagents or {}) do
            if reagent.itemID then
              observed[reagent.itemID] = observed[reagent.itemID] or {}
              observed[reagent.itemID][info.professionID] = true
            end
          end
        end
      end
    end
  end
  self:Character().observedReagents = observed
  self:Notify("recipes")
end
function A:ObservedItemUsers(itemID)
  local users = {}
  if not self.initialized then return users end
  for _, ch in pairs(self:Store().characters) do
    for skillID, isReagent in pairs((ch.observedReagents or {})[itemID] or {}) do
      if isReagent and ch.professions and ch.professions[skillID] then
        users[#users + 1] = self:ProfessionName(skillID, ch.professions[skillID].name) .. " (" .. (ch.name or "?") .. ")"
      end
    end
  end
  return users
end
