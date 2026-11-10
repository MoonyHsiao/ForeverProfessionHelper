local _, ns = ...
local A = ns.A
local frame, body, activeMode = nil, nil, "overview"
local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
function A:BuildOverview()
  local lines = {
    "伺服器：" .. self:Realm(),
    "配方資料庫：" .. (self.recipeDatabaseReady and ("已載入 " .. tostring(self.recipeDatabaseStatus) .. " 個配方") or ("未就緒：" .. tostring(self.recipeDatabaseStatus or "未知"))),
    "此版本為開發測試版。未知用途材料不會標示為可賣。",
    "",
    "已記錄角色與專業：",
  }
  for _, id in ipairs(sortedKeys(self:Store().characters)) do
    local ch = self:Store().characters[id]
    lines[#lines + 1] = (ch.name or id) .. " [" .. (ch.faction or "?") .. "]"
    local hasProfession = false
    for _, skillID in ipairs(sortedKeys(ch.professions)) do
      local skill = ch.professions[skillID]
      lines[#lines + 1] = "  " .. skill.name .. " " .. (skill.rank or 0) .. "/" .. (skill.max or 0)
      hasProfession = true
    end
    if not hasProfession then lines[#lines + 1] = "  尚無專業掃描資料" end
    lines[#lines + 1] = "  背包：" .. (ch.bagsScanned and "已掃描" or "未掃描")
      .. "，銀行：" .. (ch.bankScanned and "已掃描" or "未掃描")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "待完成：完整配方、訓練師、最低成本路線、Auctionator、購物清單、採集指南。"
  return table.concat(lines, "\n")
end
function A:ShowWindow(showPlan)
  if not self.initialized then return end
  if not frame then
    frame = CreateFrame("Frame", "ForeverProfessionHelperWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(590, 420)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("永恆專業助手 0.3.3")
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -40)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)
    body = CreateFrame("EditBox", nil, scroll)
    body:SetMultiLine(true)
    body:SetFontObject(ChatFontNormal)
    body:SetWidth(510)
    body:SetHeight(700)
    body:SetScript("OnTextChanged", function(self)
      local _, count = self:GetText():gsub("\\n", "\\n")
      self:SetHeight(math.max(700, (count + 3) * 16))
    end)
    body:SetAutoFocus(false)
    body:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(body)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(115, 23)
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 13)
    button:SetText("重新掃描")
    button:SetScript("OnClick", function()
      A:ScanBags()
      if A.bankOpen then A:ScanBank() end
      A:ScanProfessions()
      A:ScanKnownRecipes()
      activeMode = "overview"
      body:SetText(A:BuildOverview())
    end)
    local planButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    planButton:SetSize(115, 23)
    planButton:SetPoint("RIGHT", button, "LEFT", -6, 0)
    planButton:SetText("升級推薦")
    planButton:SetScript("OnClick", function()
      activeMode = "plan"
      body:SetText(A:GetPrimaryPlanText(A.selectedProfessionID))
    end)
    local cycleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cycleButton:SetSize(115, 23)
    cycleButton:SetPoint("RIGHT", planButton, "LEFT", -6, 0)
    cycleButton:SetText("切換專業")
    cycleButton:SetScript("OnClick", function()
      local list = A:GetEligibleProfessions()
      if #list == 0 then return end
      local nextIndex = 1
      for i, skill in ipairs(list) do
        if skill.id == A.selectedProfessionID then
          nextIndex = i % #list + 1
          break
        end
      end
      A.selectedProfessionID = list[nextIndex].id
      activeMode = "plan"
      body:SetText(A:GetPrimaryPlanText(A.selectedProfessionID))
    end)
    self:RegisterView("overview", function()
      if frame:IsShown() then
        body:SetText(activeMode == "plan" and A:GetPrimaryPlanText(A.selectedProfessionID) or A:BuildOverview())
      end
    end)
  end
  if showPlan and self.GetPrimaryPlanText then
    activeMode = "plan"
    body:SetText(self:GetPrimaryPlanText(self.selectedProfessionID))
  else
    activeMode = "overview"
    body:SetText(self:BuildOverview())
  end
  frame:Show()
end
