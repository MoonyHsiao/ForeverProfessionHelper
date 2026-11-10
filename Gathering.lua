local _, ns = ...
local A = ns.A
-- Text-only gathering recommendations for Forever 1.60.1.
-- Zone suggestions are informational, not a guaranteed route or current spawn map.
local guides = {
  [182] = {
    {1,70,"寧神花、銀葉草、地根草","艾爾文森林／杜洛塔／提里斯法林地"},
    {70,115,"魔皇草、石南草、跌打草","黑海岸／貧瘠之地"},
    {115,170,"跌打草、野鋼花、皇血草、活根草","濕地／希爾斯布萊德丘陵"},
    {170,205,"枯葉草、金棘草、卡德加的鬍鬚","荊棘谷／阿拉希高地"},
    {205,230,"紫蓮花、火焰花","塔納利斯／灼熱峽谷"},
    {230,270,"太陽草、盲目草、黃金蔘","辛特蘭／菲拉斯"},
    {270,300,"夢葉草、山鼠草、瘟疫花","費伍德森林／艾薩拉"},
  },
  [186] = {
    {1,65,"銅礦脈（可搭配熔煉銅錠）","艾爾文森林／丹莫洛／洛克莫丹"},
    {65,125,"錫礦、銀礦（搭配青銅錠熔煉）","赤脊山／暮色森林／濕地"},
    {125,175,"鐵礦、金礦（可搭配鐵錠熔煉）","阿拉希高地／千針石林／荊棘谷"},
    {175,245,"秘銀礦、真銀礦","荒蕪之地／塔納利斯／菲拉斯"},
    {245,300,"瑟銀礦、富瑟銀礦","安戈洛環形山／燃燒平原／冬泉谷"},
  },
  [393] = {
    {1,51,"剝取約 1～15 級野獸","艾爾文森林／丹莫洛／杜洛塔"},
    {51,151,"剝取約 15～30 級野獸","西部荒野／貧瘠之地／濕地"},
    {151,181,"剝取約 30～36 級野獸","梣谷／濕地"},
    {181,206,"剝取約 36～41 級野獸","淒涼之地／千針石林"},
    {206,236,"剝取約 41～47 級野獸","塵泥沼澤／荊棘谷"},
    {236,300,"剝取約 47～60 級野獸","塔納利斯／菲拉斯／安戈洛環形山"},
  },
}
local english = {
  [182] = {
    {"Peacebloom, Silverleaf, Earthroot","Elwynn Forest / Durotar / Tirisfal Glades"},
    {"Mageroyal, Briarthorn, Bruiseweed","Darkshore / The Barrens"},
    {"Bruiseweed, Wild Steelbloom, Kingsblood, Liferoot","Wetlands / Hillsbrad Foothills"},
    {"Fadeleaf, Goldthorn, Khadgar's Whisker","Stranglethorn Vale / Arathi Highlands"},
    {"Purple Lotus, Firebloom","Tanaris / Searing Gorge"},
    {"Sungrass, Blindweed, Golden Sansam","The Hinterlands / Feralas"},
    {"Dreamfoil, Mountain Silversage, Plaguebloom","Felwood / Azshara"},
  },
  [186] = {
    {"Copper Vein (can smelt Copper Bars)","Elwynn Forest / Dun Morogh / Loch Modan"},
    {"Tin and Silver Ore (can smelt Bronze Bars)","Redridge Mountains / Duskwood / Wetlands"},
    {"Iron and Gold Ore (can smelt Iron Bars)","Arathi Highlands / Thousand Needles / Stranglethorn Vale"},
    {"Mithril and Truesilver Ore","Badlands / Tanaris / Feralas"},
    {"Thorium and Rich Thorium Veins","Un'Goro Crater / Burning Steppes / Winterspring"},
  },
  [393] = {
    {"Skin beasts around level 1-15","Elwynn Forest / Dun Morogh / Durotar"},
    {"Skin beasts around level 15-30","Westfall / The Barrens / Wetlands"},
    {"Skin beasts around level 30-36","Ashenvale / Wetlands"},
    {"Skin beasts around level 36-41","Desolace / Thousand Needles"},
    {"Skin beasts around level 41-47","Dustwallow Marsh / Stranglethorn Vale"},
    {"Skin beasts around level 47-60","Tanaris / Feralas / Un'Goro Crater"},
  },
}
local professionNames = {
  enUS = {[182]="Herbalism",[186]="Mining",[393]="Skinning"},
  zhTW = {[182]="草藥學",[186]="採礦",[393]="剝皮"},
  zhCN = {[182]="草药学",[186]="采矿",[393]="剥皮"},
}
function A:GetGatheringGuide(skillID, current)
  skillID, current = tonumber(skillID), tonumber(current) or 1
  local stages = guides[skillID]
  if not stages then return nil end
  local locale = self:GetLanguage()
  local name = (professionNames[locale] or professionNames.enUS)[skillID]
  local lines = {self:T("GATHERING_HEADER", name, current)}
  if current >= 300 then return lines[1] .. "\n" .. self:T("TARGET_REACHED") end
  for index, stage in ipairs(stages) do
    if stage[2] > current then
      local names, zones = stage[3], stage[4]
      if locale == "enUS" and english[skillID] and english[skillID][index] then
        names, zones = english[skillID][index][1], english[skillID][index][2]
      end
      lines[#lines+1] = string.format("%d-%d: %s", math.max(stage[1], current), stage[2], names)
      lines[#lines+1] = self:T("GATHERING_ZONE", zones)
    end
  end
  lines[#lines+1] = self:T("GATHERING_TRAINER")
  lines[#lines+1] = self:T("GATHERING_CAUTION")
  if skillID == 186 then
    lines[#lines+1] = self:T("MINING_NOTE")
  elseif skillID == 393 then
    lines[#lines+1] = self:T("SKINNING_NOTE")
  end
  return table.concat(lines, "\n")
end
