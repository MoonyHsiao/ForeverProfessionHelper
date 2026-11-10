local _, ns = ...
local A = ns.A

-- Prefer localized client data. An offline English label is supplied when the
-- client does not yet know the item (including items from the fixed route).
-- Lookup never needs inventory or Auctionator and never changes the route.
local requested, unresolved = {}, {}
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local function LiveName(id)
  if type(GetItemInfo) ~= "function" then return nil end
  local ok, name = pcall(GetItemInfo, id)
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

function A:DisplayItemName(itemID)
  local id = tonumber(itemID)
  if not id then return tostring(itemID or "") end
  local name = LiveName(id)
  if name then
    unresolved[id] = nil
    return name
  end
  if not requested[id] then
    requested[id] = true
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
      pcall(C_Item.RequestLoadItemDataByID, id)
    elseif type(GetItemInfo) == "function" then
      -- A second link lookup works on clients that load by item hyperlink.
      pcall(GetItemInfo, "item:" .. id)
    end
  end
  unresolved[id] = true
  return (self.GetOfflineItemName and self:GetOfflineItemName(id))
    or self:T("ITEM_FALLBACK", id)
end

watcher:SetScript("OnEvent", function(_, _, itemID, success)
  local id = tonumber(itemID)
  if id and unresolved[id] and success ~= false then
    if LiveName(id) then
      unresolved[id] = nil
      if A.initialized then A:Notify("itemInfo") end
    end
  end
end)
