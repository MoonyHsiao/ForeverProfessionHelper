local _, ns = ...
local A = ns.A

-- OneForAll's minimap collector scans clickable 18-48 px named buttons
-- parented directly to Minimap, MinimapBackdrop, or MinimapCluster.
-- No OneForAll registration or dependency is necessary.
local button = CreateFrame("Button", "FPHMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -9, -9)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local backdrop = button:CreateTexture(nil, "BACKGROUND")
backdrop:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
backdrop:SetSize(54, 54)
backdrop:SetPoint("CENTER", button, "CENTER", 11, -11)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

button:SetScript("OnClick", function(_, mouseButton)
  if not A.initialized then return end
  if mouseButton == "RightButton" then
    A:ShowWindow(true)
  else
    A:ShowWindow()
  end
end)
button:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(A:T("TITLE"))
  GameTooltip:AddLine(A:T("LEFT_CLICK"), 1, 1, 1)
  GameTooltip:AddLine(A:T("RIGHT_CLICK"), 1, 1, 1)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Do not call SetPoint or reparent after creation: OneForAll temporarily
-- replaces those methods when it moves the button into its collection.
A.minimapButton = button
