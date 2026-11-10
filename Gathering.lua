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
function A:GetGatheringGuide(skillID, current)
  skillID, current = tonumber(skillID), tonumber(current) or 1
  local stages = guides[skillID]
  if not stages then return nil end
  local name = ({[182]="草藥學",[186]="採礦",[393]="剝皮"})[skillID]
  local lines = {name .. " " .. current .. "/300（純文字採集指南）"}
  if current >= 300 then return lines[1] .. "\n已達到預設目標。" end
  for _, stage in ipairs(stages) do
    if stage[2] > current then
      lines[#lines+1] = string.format("%d～%d：%s", math.max(stage[1],current), stage[2],stage[3])
      lines[#lines+1] = "  建議區域：" .. stage[4]
    end
  end
  lines[#lines+1] = "技能上限達 75／150／225 前，記得找專業訓練師提升上限。"
  lines[#lines+1] = "區域為參考建議；採集點與怪物分布需在永恆伺服器實際確認。"
  if skillID == 186 then
    lines[#lines+1] = "採礦：熔煉也可提升技能，配方與可用爐具請以遊戲內顯示為準。"
  elseif skillID == 393 then
    lines[#lines+1] = "剝皮：技能 100 以上通常可剝取最高約技能／5 等級的野獸（Classic 規則，永恆待驗證）。"
  end
  return table.concat(lines, "\n")
end
