local _, ns = ...
local A = ns.A
local frame, body, activeMode, title, scanButton, cycleButton, languageButton, languageMenu, professionMenu = nil, nil, "inventory"
local tabs = {}
local UpdateView
-- The three tabs only read saved inventory or the offline static route.
local function SelectTab(mode)
  activeMode = mode
  if UpdateView then UpdateView() end
end
local function StartPlan()
  if activeMode ~= "materials" then activeMode = "route" end
  if UpdateView then UpdateView() end
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
function A:BuildInventoryView()
  local lines = {self:BuildOverview(), "", self:T("INVENTORY_TAB_HEADER")}
  local any = false
  for _, charID in ipairs(sortedKeys(self:Store().characters)) do
    local ch = self:Store().characters[charID]
    local ids = {}
    local union = {}
    for id in pairs(ch.bags or {}) do union[tonumber(id) or id] = true end
    for id in pairs(ch.bank or {}) do union[tonumber(id) or id] = true end
    for id in pairs(union) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids > 0 then
      any = true
      lines[#lines + 1] = ""
      lines[#lines + 1] = (ch.name or charID) .. " (" .. tostring(#ids) .. ")"
      for i, id in ipairs(ids) do
        local bagCount, bankCount = (ch.bags or {})[id] or 0, (ch.bank or {})[id] or 0
        local itemName = (GetItemInfo and GetItemInfo(id)) or self:T("ITEM_FALLBACK", id)
        lines[#lines + 1] = string.format("  %s: %s", itemName,
          self:T("INVENTORY_LINE", bagCount, bankCount))
        if i >= 100 then
          lines[#lines + 1] = self:T("INVENTORY_TAB_MORE")
          break
        end
      end
    end
  end
  if not any then lines[#lines + 1] = self:T("INVENTORY_TAB_EMPTY") end
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
    scroll:SetPoint("TOPLEFT", 18, -79)
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
    local tabModes = {"route", "materials", "inventory"}
    local tabKeys = {route = "TAB_ROUTE", materials = "TAB_MATERIALS",
      inventory = "TAB_INVENTORY"}
    for i, mode in ipairs(tabModes) do
      local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
      tab:SetSize(150, 25)
      tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 19 + (i - 1) * 157, -38)
      tab:SetScript("OnClick", function() SelectTab(mode) end)
      tabs[mode] = tab
    end
    UpdateView = function()
      if not frame or not body then return end
      for mode, tab in pairs(tabs) do
        local selected = mode == activeMode
        tab:SetText((selected and "|cff55ccaa" or "")
          .. A:T(tabKeys[mode]) .. (selected and "|r" or ""))
      end
      if activeMode == "inventory" then
        body:SetText(A:BuildInventoryView())
      else
        local sections = A:GetStaticPlanSections(A.selectedProfessionID)
        body:SetText(sections[activeMode] or sections.route)
      end
    end
    scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanButton:SetSize(115, 23)
    scanButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 13)
    scanButton:SetText(A:T("SCAN"))
    scanButton:SetScript("OnClick", function()
      A:ScanBags()
      if A.bankOpen then A:ScanBank() end
      A:ScanProfessions()
      A:ScanKnownRecipes()
      UpdateView()
    end)
    cycleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cycleButton:SetSize(115, 23)
    cycleButton:SetPoint("RIGHT", scanButton, "LEFT", -6, 0)
    cycleButton:SetText(A:T("SWITCH"))
    -- Rebuild options on open: learned professions and locale can change.
    -- Keep buttons around instead of allocating new frames each click.
    professionMenu = CreateFrame("Frame", nil, frame)
    professionMenu:SetFrameStrata("DIALOG")
    professionMenu:SetFrameLevel(frame:GetFrameLevel() + 30)
    professionMenu:SetWidth(210)
    professionMenu:SetPoint("BOTTOMLEFT", cycleButton, "TOPLEFT", 0, 3)
    local professionBackground = professionMenu:CreateTexture(nil, "BACKGROUND")
    professionBackground:SetAllPoints()
    professionBackground:SetColorTexture(0.07, 0.07, 0.08, 0.97)
    local professionOptions = {}
    local function RefreshProfessionMenu()
      local list = A:GetEligibleProfessions()
      for i, profession in ipairs(list) do
        local option = professionOptions[i]
        if not option then
          option = CreateFrame("Button", nil, professionMenu)
          option:SetSize(206, 26)
          option:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 27)
          option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
          option.label = option:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          option.label:SetPoint("LEFT", 9, 0)
          option.label:SetPoint("RIGHT", -8, 0)
          option.label:SetJustifyH("LEFT")
          professionOptions[i] = option
        end
        option.label:SetText(profession.name .. " " .. tostring(profession.rank) .. "/300"
          .. (profession.id == A.selectedProfessionID and " |cff55ccaa*|r" or ""))
        local selectedID = profession.id
        option:SetScript("OnClick", function()
          professionMenu:Hide()
          A.selectedProfessionID = selectedID
          StartPlan()
        end)
        option:Show()
      end
      for i = #list + 1, #professionOptions do
        professionOptions[i]:Hide()
      end
      professionMenu:SetHeight(math.max(4, #list * 27 + 4))
      return #list > 0
    end
    professionMenu:Hide()
    cycleButton:SetScript("OnClick", function()
      if professionMenu:IsShown() then
        professionMenu:Hide()
      elseif RefreshProfessionMenu() then
        if languageMenu then languageMenu:Hide() end
        professionMenu:Show()
      end
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
      if languageMenu:IsShown() then
        languageMenu:Hide()
      else
        if professionMenu then professionMenu:Hide() end
        languageMenu:Show()
      end
    end)
    frame:HookScript("OnHide", function()
      languageMenu:Hide()
      professionMenu:Hide()
    end)
    self:RegisterView("overview", function(reason)
      title:SetText(A:T("TITLE") .. " " .. A.version)
      scanButton:SetText(A:T("SCAN"))
      cycleButton:SetText(A:T("SWITCH"))
      languageButton:SetText(A:T("LANGUAGE") .. ": " .. (A.languageNames[A.db.language or "auto"] or "Auto"))
      if frame:IsShown() then UpdateView() end
    end)
  end
  if title then
    title:SetText(self:T("TITLE") .. " " .. self.version)
    scanButton:SetText(self:T("SCAN"))
    cycleButton:SetText(self:T("SWITCH"))
    languageButton:SetText(self:T("LANGUAGE") .. ": " .. (self.languageNames[self.db.language or "auto"] or "Auto"))
  end
  if showPlan then
    SelectTab("route")
  else
    SelectTab("inventory")
  end
  frame:Show()
end
