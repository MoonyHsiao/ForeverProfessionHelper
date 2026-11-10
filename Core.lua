local addonName, ns = ...
local A = CreateFrame("Frame")
ns.A = A
A.version = "1.1.0-dev"
A.listeners = {}

function A:Print(message)
  print("|cff55ccaa" .. (self.T and self:T("TITLE") or "Forever Profession Helper") .. "|r " .. tostring(message))
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
  self:Print(self:T("LOAD_MESSAGE"))
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
  if message == "plan" or message:match("^plan%s+%d+$") then
    local skillID = tonumber(message:match("^plan%s+(%d+)$"))
    if skillID then A.selectedProfessionID = skillID end
    A:ShowWindow(true)
  elseif message == "lang" or message:match("^lang%s+") then
    local code = message:match("^lang%s+(%S+)$")
    if code and (code == "auto" or code == "enUS" or code == "zhTW" or code == "zhCN" or code == "enus" or code == "zhtw" or code == "zhcn") then
      local normalized = ({enus="enUS",zhtw="zhTW",zhcn="zhCN"})[code] or code
      A:SetLanguage(normalized)
    else
      A:CycleLanguage()
    end
    A:Print(A:T("LANGUAGE") .. ": " .. (A.languageNames[A.db.language or "auto"] or "Auto"))
  elseif message == "db" then
    local ready, status = A:LoadRecipeDatabase()
    A:Print(A:T("CHAT_DB", tostring(status)))
    A:Print(A:T("CHAT_PARSED", A.recipeCount or 0, A.reagentCount or 0))
    local ids = {}
    for id in pairs(A.recipeCoverage or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    A:Print(A:T("CHAT_COVERAGE", #ids > 0 and table.concat(ids, ", ") or A:T("CHAT_NONE")))
  elseif message == "scan" then
    A:ScanBags()
    if A.bankOpen then A:ScanBank() end
    A:ScanProfessions()
    A:ScanKnownRecipes()
    A:Print(A:T("RESCANNED"))
  elseif message == "help" then
    A:Print(A:T("CHAT_HELP"))
  else
    A:ShowWindow()
  end
end
