local _, ns = ...
local A = ns.A
local frame, body, activeMode, title, scanButton, planButton, cycleButton, languageButton = nil, nil, "overview"
local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
function A:BuildOverview()
  local lines = {
    self:T("REALM", self:Realm()),
    self:T("DATABASE", self.recipeDatabaseReady and self:T("DB_LOADED", tonumber(self.recipeCount) or 0) or self:T("DB_NOT_READY", tostring(self.recipeDatabaseStatus or self:T("UNKNOWN")))),
    self:T("DEV_WARNING"),
    "",
    self:T("CHARACTERS"),
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
    if not hasProfession then lines[#lines + 1] = self:T("NO_PROFESSION") end
    lines[#lines + 1] = self:T("SNAPSHOT", ch.bagsScanned and self:T("SCANNED") or self:T("UNSCANNED"), ch.bankScanned and self:T("SCANNED") or self:T("UNSCANNED"))
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = self:T("OVERVIEW_NOTE")
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
    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText(A:T("TITLE") .. " " .. A.version)
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
    scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanButton:SetSize(115, 23)
    scanButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 13)
    scanButton:SetText(A:T("SCAN"))
    scanButton:SetScript("OnClick", function()
      A:ScanBags()
      if A.bankOpen then A:ScanBank() end
      A:ScanProfessions()
      A:ScanKnownRecipes()
      activeMode = "overview"
      body:SetText(A:BuildOverview())
    end)
    planButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    planButton:SetSize(115, 23)
    planButton:SetPoint("RIGHT", scanButton, "LEFT", -6, 0)
    planButton:SetText(A:T("PLAN"))
    planButton:SetScript("OnClick", function()
      activeMode = "plan"
      body:SetText(A:GetPrimaryPlanText(A.selectedProfessionID))
    end)
    cycleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cycleButton:SetSize(115, 23)
    cycleButton:SetPoint("RIGHT", planButton, "LEFT", -6, 0)
    cycleButton:SetText(A:T("SWITCH"))
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
    languageButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    languageButton:SetSize(118, 23)
    languageButton:SetPoint("RIGHT", cycleButton, "LEFT", -6, 0)
    languageButton:SetScript("OnClick", function() A:CycleLanguage() end)
    self:RegisterView("overview", function()
      title:SetText(A:T("TITLE") .. " " .. A.version)
      scanButton:SetText(A:T("SCAN"))
      planButton:SetText(A:T("PLAN"))
      cycleButton:SetText(A:T("SWITCH"))
      languageButton:SetText(A:T("LANGUAGE") .. ": " .. (A.languageNames[A.db.language or "auto"] or "Auto"))
      if frame:IsShown() then
        body:SetText(activeMode == "plan" and A:GetPrimaryPlanText(A.selectedProfessionID) or A:BuildOverview())
      end
    end)
  end
  if title then
    title:SetText(self:T("TITLE") .. " " .. self.version)
    scanButton:SetText(self:T("SCAN"))
    planButton:SetText(self:T("PLAN"))
    cycleButton:SetText(self:T("SWITCH"))
    languageButton:SetText(self:T("LANGUAGE") .. ": " .. (self.languageNames[self.db.language or "auto"] or "Auto"))
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
