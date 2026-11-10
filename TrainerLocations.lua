local _, ns = ...
local A = ns.A

-- Classic-era coordinates. Forever trainer locations may differ.
-- Only show a location when the exact NPC name is matched.
local NPCS = {
  ["Simon Tanner"] = {"暴風城／舊城區", "67.6, 49.4"},
  ["Fimble Finespindle"] = {"鐵爐堡", "39.8, 33.6"},
  ["Telonis"] = {"達納蘇斯／工匠區", "64.6, 21.6"},
  ["Drakk Stonehand"] = {"辛特蘭／鷹巢山", "13.4, 43.4"},
  ["Nadyia Maneweaver"] = {"泰達希爾", "41.8, 49.6"},
  ["Adele Fielder"] = {"艾爾文森林／閃金鎮", "46.6, 62.2"},
  ["Karolek"] = {"奧格瑪", "62.8, 44.6"},
  ["Arthur Moore"] = {"幽暗城", "70.6, 58.6"},
  ["Una"] = {"雷霆崖", "41.8, 42.6"},
}
local FALLBACK = {
  [165] = {
    Alliance = "暴風城：Simon Tanner（舊城區）；鐵爐堡：Fimble Finespindle；達納蘇斯：Telonis",
    Horde = "奧格瑪：Karolek；幽暗城：Arthur Moore；雷霆崖：Una",
  },
}
local EN_NPCS = {
  ["Simon Tanner"] = "Stormwind / Old Town",
  ["Fimble Finespindle"] = "Ironforge",
  ["Telonis"] = "Darnassus / Craftsmen's Terrace",
  ["Drakk Stonehand"] = "The Hinterlands / Aerie Peak",
  ["Nadyia Maneweaver"] = "Teldrassil",
  ["Adele Fielder"] = "Elwynn Forest / Goldshire",
  ["Karolek"] = "Orgrimmar",
  ["Arthur Moore"] = "Undercity",
  ["Una"] = "Thunder Bluff",
}
local CN_NPCS = {
  ["Simon Tanner"] = "暴风城／旧城区",
  ["Fimble Finespindle"] = "铁炉堡",
  ["Telonis"] = "达纳苏斯／工匠区",
  ["Drakk Stonehand"] = "辛特兰／鹰巢山",
  ["Nadyia Maneweaver"] = "泰达希尔",
  ["Adele Fielder"] = "艾尔文森林／闪金镇",
  ["Karolek"] = "奥格瑞玛",
  ["Arthur Moore"] = "幽暗城",
  ["Una"] = "雷霆崖",
}
local FALLBACK_EN = {
  Alliance = "Stormwind: Simon Tanner (Old Town); Ironforge: Fimble Finespindle; Darnassus: Telonis",
  Horde = "Orgrimmar: Karolek; Undercity: Arthur Moore; Thunder Bluff: Una",
}
local FALLBACK_CN = {
  Alliance = "暴风城：Simon Tanner（旧城区）；铁炉堡：Fimble Finespindle；达纳苏斯：Telonis",
  Horde = "奥格瑞玛：Karolek；幽暗城：Arthur Moore；雷霆崖：Una",
}
function A:TrainerLocation(skillID, npcName)
  local entry = npcName and NPCS[npcName]
  if entry then
    local locale = self:GetLanguage()
    local zone = entry[1]
    if locale == "enUS" then zone = EN_NPCS[npcName] or zone
    elseif locale == "zhCN" then zone = CN_NPCS[npcName] or zone end
    return self:T("TRAINER_LOCATION_CLASSIC", zone, entry[2])
  end
  return self:T("TRAINER_LOCATION_MISSING")
end
function A:TrainerFallback(skillID)
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  if tonumber(skillID) ~= 165 then return nil end
  local locale = self:GetLanguage()
  if locale == "enUS" then return FALLBACK_EN[faction]
  elseif locale == "zhCN" then return FALLBACK_CN[faction] end
  return FALLBACK[165][faction]
end

function A:RecipeLearned(spellID)
  local func = IsPlayerSpell or IsSpellKnown
  if type(func) == "function" then
    local ok, learned = pcall(func, spellID)
    if ok and learned then return true end
  end
  if C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
    if ok and type(info) == "table" and type(info.learned) == "boolean" then
      return info.learned
    end
  end
  -- No complete known-recipe API is guaranteed outside an open trade window.
  return nil
end
