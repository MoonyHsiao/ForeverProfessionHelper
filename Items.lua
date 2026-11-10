local _, ns = ...
local A = ns.A
-- Unknown items must never be declared safe to sell without full recipe data.
function A:Classify(itemID)
  if not itemID then return "unknown", {} end
  local status, users = self:RecipeUsers(itemID)
  if status == "needed" then return status, users end
  local observed = self:ObservedItemUsers(itemID)
  if #observed > 0 then return "needed", observed end
  if status == "not_needed" and GetItemInfoInstant then
    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    if classID == 7 then return "notneeded", {} end
  end
  return "unknown", {}
end

local function addTooltip(tooltip)
  if not A.initialized or not tooltip or not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  local id = link and tonumber(link:match("item:(%d+)"))
  if not id then return end
  local status, users = A:Classify(id)
  local rows, total = A:ItemHoldings(id)
  tooltip:AddLine(" ")
  tooltip:AddLine(A:T("TITLE"), 0.35, 0.8, 0.65)
  if status == "needed" then
    tooltip:AddLine(A:T("NEEDED"), 0.3, 1, 0.3)
    for i = 1, math.min(4, #users) do tooltip:AddLine("  " .. users[i], 0.8, 0.9, 0.8) end
  elseif status == "notneeded" then
    tooltip:AddLine(A:T("NOT_NEEDED"), 1, 0.35, 0.35)
    tooltip:AddLine(A:T("OTHER_USES"), 1, 0.7, 0.25)
  else
    tooltip:AddLine(A:T("UNKNOWN_ITEM"), 1, 0.75, 0.25)
  end
  tooltip:AddLine(A:T("INVENTORY_TOTAL", total), 0.8, 0.8, 1)
  for i = 1, math.min(10, #rows) do
    local row = rows[i]
    tooltip:AddDoubleLine("  " .. row.name, A:T("INVENTORY_LINE", row.bags, row.bank))
  end
  if not A:InventoryComplete() then
    tooltip:AddLine(A:T("INCOMPLETE_BANKS"), 1, 0.65, 0.2)
  end
  tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addTooltip)
elseif GameTooltip then
  GameTooltip:HookScript("OnTooltipSetItem", addTooltip)
end

local function decorate(button)
  if not button or not button.GetID then return end
  local id = button.GetItemID and button:GetItemID()
  local parent = button:GetParent()
  local bag, slot = parent and parent:GetID(), button:GetID()
  if not id and C_Container and C_Container.GetContainerItemID and bag and slot then
    local ok, value = pcall(C_Container.GetContainerItemID, bag, slot)
    if ok then id = value end
  end
  if not button.FPHMark then
    local mark = button:CreateTexture(nil, "OVERLAY")
    mark:SetSize(10, 10)
    mark:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    mark:SetColorTexture(0.2, 1, 0.3, 0.85)
    button.FPHMark = mark
  end
  local status = id and A:Classify(id) or "unknown"
  if status == "needed" then
    button.FPHMark:SetColorTexture(0.2, 1, 0.3, 0.85)
    button.FPHMark:Show()
  elseif status == "notneeded" then
    button.FPHMark:SetColorTexture(1, 0.2, 0.2, 0.85)
    button.FPHMark:Show()
  else
    button.FPHMark:Hide()
  end
end
if type(ContainerFrame_Update) == "function" then
  hooksecurefunc("ContainerFrame_Update", function(frame)
    if not A.initialized then return end
    local name = frame and frame:GetName()
    if not name then return end
    for i = 1, (frame.size or 36) do
      local button = _G[name .. "Item" .. i]
      if button then decorate(button) end
    end
  end)
end
A:RegisterView("bagMarks", function()
  for index = 1, (NUM_CONTAINER_FRAMES or 13) do
    local frame = _G["ContainerFrame" .. index]
    if frame and frame:IsShown() then
      for i = 1, (frame.size or 36) do
        local button = _G[frame:GetName() .. "Item" .. i]
        if button then decorate(button) end
      end
    end
  end
end)
