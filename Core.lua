local addonName, ns = ...
local A = CreateFrame("Frame")
ns.A = A
A.version = "0.2.0"
A.listeners = {}

function A:Print(message)
  print("|cff55ccaa永恆專業助手|r " .. tostring(message))
end
function A:Realm()
  local name = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "UNKNOWN"
  return name:gsub("%s+", "")
end
function A:Identity() return (UnitName("player") or "UNKNOWN") .. "-" .. self:Realm() end
function A:Store() return self.db.realms[self:Realm()] end
function A:Character() return self:Store().characters[self:Identity()] end
function A:Time() return time and time() or 0 end

function A:RegisterView(name, handler) self.listeners[name] = handler end
function A:Notify(reason)
  if self.refreshPending then return end
  self.refreshPending = true
  local function flush()
    self.refreshPending = false
    for _, handler in pairs(self.listeners) do
      local ok, err = pcall(handler, reason)
      if not ok then A:Print("UI error: " .. tostring(err)) end
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.3, flush) else flush() end
end

function A:Initialize()
  if type(ForeverProfessionHelperDB) ~= "table" then ForeverProfessionHelperDB = {} end
  self.db = ForeverProfessionHelperDB
  local db = self.db
  db.schema = 1
  db.realms = db.realms or {}
  local realm = self:Realm()
  db.realms[realm] = db.realms[realm] or { characters = {} }
  local id = self:Identity()
  local chars = db.realms[realm].characters
  chars[id] = chars[id] or {}
  local ch = chars[id]
  ch.bags = ch.bags or {}
  ch.bank = ch.bank or {}
  ch.professions = ch.professions or {}
  ch.name = UnitName("player")
  ch.realm = realm
  ch.faction = UnitFactionGroup("player") or "Unknown"
  ch.lastLogin = self:Time()
  self.initialized = true
  self:ScanProfessions()
  self:LoadRecipeDatabase()
  self:ScanBags()
  self:Print("已載入。輸入 /fph 開啟視窗。")
end

for _, event in ipairs({
  "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "SKILL_LINES_CHANGED",
  "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED",
}) do A:RegisterEvent(event) end

A:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then self:Initialize(); return end
  if not self.initialized then return end
  if event == "BANKFRAME_OPENED" then
    self.bankOpen = true
    self:ScanBank()
  elseif event == "BANKFRAME_CLOSED" then
    self.bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    if self.bankOpen then self:ScanBank() end
  elseif event == "BAG_UPDATE_DELAYED" then
    self:ScanBags()
    if self.bankOpen then self:ScanBank() end
  elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
    self:ScanProfessions()
    self:ScanKnownRecipes()
  end
end)

SLASH_FOREVERPROFESSIONHELPER1 = "/fph"
SlashCmdList.FOREVERPROFESSIONHELPER = function(message)
  message = (message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if not A.initialized then return end
  if message == "db" then
    local ready, status = A:LoadRecipeDatabase()
    A:Print("配方資料庫：" .. (ready and "已載入 " or "無法載入：") .. tostring(status))
    A:Print("已解析配方 " .. tostring(A.recipeCount or 0) .. " 筆；材料關聯 " .. tostring(A.reagentCount or 0) .. " 筆")
    local ids = {}
    for id in pairs(A.recipeCoverage or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    A:Print("已覆蓋專業 ID：" .. (#ids > 0 and table.concat(ids, ", ") or "無"))
  elseif message == "scan" then
    A:ScanBags()
    if A.bankOpen then A:ScanBank() end
    A:ScanProfessions()
    A:ScanKnownRecipes()
    A:Print("已重新掃描當前可讀資料。")
  elseif message == "help" then
    A:Print("/fph 開啟視窗；/fph scan 重新掃描；/fph help 顯示指令。")
  else
    A:ShowWindow()
  end
end
