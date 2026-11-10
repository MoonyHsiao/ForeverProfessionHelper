local _, ns = ...
local A = ns.A
local frame, body, activeMode, title, scanButton, planButton, cycleButton, languageButton, languageMenu = nil, nil, "overview"
-- The 1-300 planner is expensive. Run its coroutine across UI frames instead
-- of blocking WoW's main thread in a single click callback.
local planJob, planGeneration = nil, 0
local function CancelPlan()
  planGeneration = planGeneration + 1
  planJob = nil
  if frame then frame:SetScript("OnUpdate", nil) end
end
local function StartPlan()
  if not frame or not body then return end
  CancelPlan()
  activeMode = "plan"
  local token = planGeneration
  local job = { evaluations = 0, current = 0, target = 300, elapsed = 0 }
  job.thread = coroutine.create(function()
    return A:GetPrimaryPlanText(A.selectedProfessionID, function(count, current, target)
      job.evaluations = job.evaluations + (count or 1)
      job.current = math.floor(current or 0)
      job.target = target or 300
      if job.evaluations % 4 == 0 then coroutine.yield() end
    end)
  end)
  planJob = job
  body:SetText(A:T("PLAN_CALCULATING", job.current, job.target))
  frame:SetScript("OnUpdate", function(self, elapsed)
    if planJob ~= job or planGeneration ~= token then
      self:SetScript("OnUpdate", nil)
      return
    end
    -- One coroutine slice per rendered frame; the planner yields every four
    -- recipe evaluations to preserve UI responsiveness.
    local ok, outcome = coroutine.resume(job.thread)
    if not ok then
      body:SetText(A:T("PLAN_ERROR", tostring(outcome)))
      CancelPlan()
      return
    end
    if coroutine.status(job.thread) == "dead" then
      body:SetText(tostring(outcome or ""))
      planJob = nil
      self:SetScript("OnUpdate", nil)
      return
    end
    job.elapsed = job.elapsed + (elapsed or 0)
    if job.elapsed > 0.3 then
      job.elapsed = 0
      body:SetText(A:T("PLAN_CALCULATING", job.current, job.target))
    end
  end)
end
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
      lines[#lines + 1] = "  " .. self:ProfessionName(skillID, skill.name) .. " " .. (skill.rank or 0) .. "/" .. (skill.max or 0)
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
      CancelPlan()
      activeMode = "overview"
      body:SetText(A:BuildOverview())
    end)
    planButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    planButton:SetSize(115, 23)
    planButton:SetPoint("RIGHT", scanButton, "LEFT", -6, 0)
    planButton:SetText(A:T("PLAN"))
    planButton:SetScript("OnClick", function()
      StartPlan()
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
      StartPlan()
    end)
    languageButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    languageButton:SetSize(118, 23)
    languageButton:SetPoint("RIGHT", cycleButton, "LEFT", -6, 0)
    -- A self-contained dropdown, independent of client-specific UIDropDownMenu templates.
    languageMenu = CreateFrame("Frame", nil, frame)
    languageMenu:SetSize(158, 112)
    languageMenu:SetFrameStrata("DIALOG")
    languageMenu:SetFrameLevel(frame:GetFrameLevel() + 30)
    languageMenu:SetPoint("BOTTOMLEFT", languageButton, "TOPLEFT", 0, 3)
    local bg = languageMenu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.07, 0.08, 0.97)
    local border = languageMenu:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.55, 0.42, 0.18, 0.35)
    local inset = languageMenu:CreateTexture(nil, "ARTWORK")
    inset:SetPoint("TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(0.07, 0.07, 0.08, 0.97)
    for i, code in ipairs(A.languageCodes) do
      local option = CreateFrame("Button", nil, languageMenu)
      option:SetSize(154, 26)
      option:SetPoint("TOPLEFT", 2, -(i - 1) * 27 - 2)
      local label = option:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetPoint("LEFT", 9, 0)
      label:SetText(A.languageNames[code])
      option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      option:SetScript("OnClick", function()
        languageMenu:Hide()
        A:SetLanguage(code)
      end)
    end
    languageMenu:Hide()
    languageButton:SetScript("OnClick", function()
      if languageMenu:IsShown() then languageMenu:Hide() else languageMenu:Show() end
    end)
    frame:HookScript("OnHide", function() languageMenu:Hide(); CancelPlan() end)
    self:RegisterView("overview", function(reason)
      title:SetText(A:T("TITLE") .. " " .. A.version)
      scanButton:SetText(A:T("SCAN"))
      planButton:SetText(A:T("PLAN"))
      cycleButton:SetText(A:T("SWITCH"))
      languageButton:SetText(A:T("LANGUAGE") .. ": " .. (A.languageNames[A.db.language or "auto"] or "Auto"))
      if frame:IsShown() then
        if activeMode == "plan" then
          -- Inventory and skill changes invalidate a running plan. Debounce
          -- recalculation so BAG_UPDATE events cannot restart on every item.
          if reason == "language" then
            StartPlan()
          elseif reason == "bags" or reason == "bank" or reason == "professions" or reason == "recipes" or reason == "recipeDB" then
            if not A.planDebouncePending then
              A.planDebouncePending = true
              if C_Timer and C_Timer.After then
                C_Timer.After(0.8, function()
                  A.planDebouncePending = false
                  if frame and frame:IsShown() and activeMode == "plan" then StartPlan() end
                end)
              else
                A.planDebouncePending = false
              end
            end
          end
        else
          body:SetText(A:BuildOverview())
        end
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
    StartPlan()
  else
    CancelPlan()
    activeMode = "overview"
    body:SetText(self:BuildOverview())
  end
  frame:Show()
end
