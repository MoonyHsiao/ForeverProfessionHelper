local _, ns = ...
local A = ns.A
local function readContainer(bag)
  local api = C_Container
  if not api or not api.GetContainerNumSlots or not api.GetContainerItemInfo then return nil end
  local ok, slots = pcall(api.GetContainerNumSlots, bag)
  if not ok or type(slots) ~= "number" then return nil end
  local counts = {}
  for slot = 1, slots do
    local success, info = pcall(api.GetContainerItemInfo, bag, slot)
    if success and info then
      local id = info.itemID
      if not id and info.hyperlink then id = tonumber(info.hyperlink:match("item:(%d+)")) end
      if id then counts[id] = (counts[id] or 0) + (info.stackCount or 1) end
    end
  end
  return counts
end
local function merge(target, source)
  for id, count in pairs(source) do target[id] = (target[id] or 0) + count end
end
function A:ScanBags()
  if not self.initialized then return end
  local counts = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local source = readContainer(bag)
    if not source then return end
    merge(counts, source)
  end
  local ch = self:Character()
  ch.bags = counts
  ch.bagsScanned = true
  ch.bagUpdated = self:Time()
  self:Notify("bags")
end
function A:ScanBank()
  if not self.initialized or not self.bankOpen then return end
  local counts = {}
  local main = readContainer(BANK_CONTAINER or -1)
  if not main then return end
  merge(counts, main)
  local first = (NUM_BAG_SLOTS or 4) + 1
  for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do
    local source = readContainer(bag)
    if not source then return end
    merge(counts, source)
  end
  local ch = self:Character()
  ch.bank = counts
  ch.bankScanned = true
  ch.bankUpdated = self:Time()
  self:Notify("bank")
end
function A:ItemHoldings(itemID)
  if not self.initialized then return {}, 0 end
  local rows, total = {}, 0
  for id, ch in pairs(self:Store().characters) do
    local bags = (ch.bags and ch.bags[itemID]) or 0
    local bank = (ch.bank and ch.bank[itemID]) or 0
    if bags + bank > 0 then
      rows[#rows + 1] = { name = ch.name or id, bags = bags, bank = bank }
      total = total + bags + bank
    end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows, total
end
function A:InventoryComplete()
  if not self.initialized then return false end
  for _, ch in pairs(self:Store().characters) do
    if not ch.bagsScanned or not ch.bankScanned then return false end
  end
  return true
end
