local _, ns = ...
local A = ns.A
local frame, body, activeMode, title, scanButton, cycleButton, languageButton, languageMenu, professionMenu = nil, nil, "inventory"
local tabs = {}
local UpdateView
local routeScroll, routeContent, routeRows, routeHeader, routeFooter = nil, nil, {}, nil, nil
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
        local itemName = self:DisplayItemName(id)
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

-- Show game-native details where the client supports them. Some crafting
-- spells have no item output (enchanting); use a spell tooltip or a readable
-- fallback with the LibProfessionDB ingredient list.
local function ShowRecipeTooltip(button, stage)
  if not GameTooltip or not stage then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  local recipe = stage.recipe
  local itemID = recipe and tonumber(recipe.craftedItemId)
  if not itemID and A.GetOneForAllCraftOutput then
    itemID = A:GetOneForAllCraftOutput(stage.spell)
  end
  local shown = false
  if itemID and GameTooltip.SetHyperlink then
    shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. itemID)
  end
  if not shown and stage.spell and GameTooltip.SetSpellByID then
    shown = pcall(GameTooltip.SetSpellByID, GameTooltip, stage.spell)
  end
  if not shown then
    GameTooltip:ClearLines()
    GameTooltip:AddLine(stage.name or tostring(stage.spell), 1, 0.82, 0.1)
  end
  if recipe and type(recipe.reagents) == "table" and next(recipe.reagents) then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(A:T("TOOLTIP_REAGENTS"), 1, 0.82, 0.1)
    local ids = {}
    for id in pairs(recipe.reagents) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local name = A:DisplayItemName(id)
      GameTooltip:AddLine(string.format("  %s x%d", name, recipe.reagents[id]), 1, 1, 1)
    end
  end
  GameTooltip:Show()
end

local function RenderInteractiveRoute(sections)
  if not routeScroll or not routeContent then return end
  local stages = sections.stages or {}
  local hasRows = #stages > 0
  if not hasRows then
    routeScroll:Hide()
    return false
  end

  local y = 8
  local headerText = (sections.professionName or "") .. " "
    .. tostring(sections.currentSkill or 0) .. "/300"
  if sections.skillCapNotice then
    headerText = headerText .. "\n|cffff6644" .. sections.skillCapNotice .. "|r"
  end
  if sections.hasNonTrainerFallback then
    headerText = headerText .. "\n|cffffaa55" .. A:T("ROUTE_RECIPE_EXCEPTION_NOTICE") .. "|r"
  end
  headerText = headerText .. "\n" .. A:T("PLAN_DISCLAIMER")
    .. "\n" .. A:T("RECIPE_TOOLTIP_HINT")
  routeHeader:SetText(headerText)
  local headerHeight = math.max(65, routeHeader:GetStringHeight() + 12)
  routeHeader:SetHeight(headerHeight)
  y = y + headerHeight + 6

  local limit = math.min(35, #stages)
  for i = 1, limit do
    local stage = stages[i]
    local row = routeRows[i]
    if not row then
      row = CreateFrame("Button", nil, routeContent)
      row:SetWidth(480)
      row:SetPoint("TOPLEFT", routeContent, "TOPLEFT", 3, 0)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.text:SetPoint("TOPLEFT", 11, -8)
      row.text:SetWidth(452)
      row.text:SetJustifyH("LEFT")
      row.text:SetJustifyV("TOP")
      local background = row:CreateTexture(nil, "BACKGROUND")
      background:SetAllPoints()
      row.background = background
      local highlight = row:CreateTexture(nil, "HIGHLIGHT")
      highlight:SetAllPoints()
      highlight:SetColorTexture(1, 1, 1, 0.09)
      routeRows[i] = row
    end
    local title = string.format("%d-%d: %s x%d [%s]",
      math.floor(stage.from), math.floor(stage.to), stage.name, stage.crafts,
      A:T("COLOR_" .. stage.color))
    local lines = {}
    if i == 1 then
      lines[#lines + 1] = "|cff55ff88" .. A:T("CURRENT_RECIPE") .. "|r"
    end
    lines[#lines + 1] = title
    if stage.sourceNotice then
      lines[#lines + 1] = "|cffffaa55" .. stage.sourceNotice .. "|r"
    end
    for _, entry in ipairs(stage.preparations or {}) do
      local name = (GetSpellInfo and GetSpellInfo(entry.id)) or tostring(entry.id)
      lines[#lines + 1] = A:T("CRAFT_PREREQUISITE_GAIN", name, entry.count, entry.expected)
    end
    row.text:SetText(table.concat(lines, "\n"))
    local height = math.max(36, row.text:GetStringHeight() + 17)
    row:SetHeight(height)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", routeContent, "TOPLEFT", 3, -y)
    if i == 1 then
      row.background:SetColorTexture(0.08, 0.33, 0.17, 0.48)
    else
      row.background:SetColorTexture(0.12, 0.12, 0.12, 0.40)
    end
    row:SetScript("OnEnter", function(self) ShowRecipeTooltip(self, stage) end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row:Show()
    y = y + height + 5
  end
  for i = limit + 1, #routeRows do routeRows[i]:Hide() end

  local footerLines = {}
  if #stages > 35 then footerLines[#footerLines + 1] = A:T("MORE_STAGES") end
  if (sections.projectedSkill or 0) < 300 then
    footerLines[#footerLines + 1] = A:T("PLAN_INCOMPLETE")
  end
  routeFooter:SetText(table.concat(footerLines, "\n"))
  routeFooter:SetHeight(math.max(1, routeFooter:GetStringHeight() + 4))
  routeFooter:ClearAllPoints()
  routeFooter:SetPoint("TOPLEFT", routeContent, "TOPLEFT", 8, -y)
  routeContent:SetHeight(math.max(1, y + routeFooter:GetHeight() + 18))
  routeScroll:Show()
  return true
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
      local _, count = self:GetText():gsub(string.char(10), "")
      self:SetHeight(math.max(700, (count + 3) * 16))
    end)
    body:SetAutoFocus(false)
    body:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(body)
    routeScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    routeScroll:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    routeScroll:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    routeContent = CreateFrame("Frame", nil, routeScroll)
    routeContent:SetWidth(480)
    routeContent:SetHeight(1)
    routeScroll:SetScrollChild(routeContent)
    routeHeader = routeContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    routeHeader:SetPoint("TOPLEFT", routeContent, "TOPLEFT", 9, -8)
    routeHeader:SetWidth(465)
    routeHeader:SetJustifyH("LEFT")
    routeHeader:SetJustifyV("TOP")
    routeFooter = routeContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    routeFooter:SetWidth(465)
    routeFooter:SetJustifyH("LEFT")
    routeScroll:Hide()
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
        routeScroll:Hide()
        scroll:Show()
        body:SetText(A:BuildInventoryView())
      else
        local sections = A:GetStaticPlanSections(A.selectedProfessionID)
        if activeMode == "route" and RenderInteractiveRoute(sections) then
          scroll:Hide()
        else
          routeScroll:Hide()
          scroll:Show()
          body:SetText(sections[activeMode] or sections.route)
        end
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
