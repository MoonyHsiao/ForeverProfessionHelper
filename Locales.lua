local _, ns = ...
local A = ns.A

-- Default: follow the WoW client locale. An account-wide override can be
-- changed without reloading. Other WoW locales fall back to English.
local dictionaries = {
  enUS = {
    TITLE = "Forever Profession Helper",
    LANGUAGE = "Language",
    AUTO = "Auto",
    SCAN = "Rescan",
    PLAN = "Leveling Guide",
    SWITCH = "Switch Profession",
    REALM = "Realm: %s",
    DATABASE = "Recipe database: %s",
    DB_LOADED = "%d recipes loaded",
    DB_NOT_READY = "Not ready: %s",
    DEV_WARNING = "Development build. Unknown materials are never marked safe to sell.",
    CHARACTERS = "Recorded characters and professions:",
    NO_PROFESSION = "  No profession data scanned",
    SNAPSHOT = "  Bags: %s, Bank: %s",
    SCANNED = "scanned",
    UNSCANNED = "not scanned",
    OVERVIEW_NOTE = "Leveling routes and trainer data are estimates; verify them in-game.",
    NEEDED = "Needed for a profession recipe",
    NOT_NEEDED = "Not needed by recorded professions' recipes",
    OTHER_USES = "May still have quest, trade, or other uses",
    UNKNOWN_ITEM = "Use unknown (recipe coverage incomplete or not a common reagent)",
    INVENTORY_TOTAL = "Recorded same-realm inventory: %d",
    INVENTORY_LINE = "Bags %d / Bank %d",
    INCOMPLETE_BANKS = "Some characters' banks have not been scanned; total may be low.",
    LEFT_CLICK = "Left-click: Character and inventory overview",
    RIGHT_CLICK = "Right-click: Profession leveling recommendations",
    READY = "Loaded",
    UNKNOWN = "Unknown",
    DB_MISSING = "LibProfessionDB is not registered (check dependencies)",
    DB_WAIT = "Recipe database is not ready",
    DB_WRONG = "Not a Forever recipe database",
    DB_API = "Library is missing GetRecipes / GetRecipe",
    DB_EMPTY = "No recipe reagents parsed",
    PLAN_DB = "Recipe database is not ready",
    PLAN_NOT_LEARNED_PROF = "This character has not learned the profession",
    PLAN_NO_RECIPES = "No usable crafting recipes; gathering professions use text guides",
    PLAN_HEADER = "Profession %s, estimated %d -> %d / %d",
    PLAN_DISCLAIMER = "Greedy estimate, not globally optimal; skill-ups and quantities are approximate.",
    LEARNED = "Learned",
    NOT_LEARNED = "Not learned",
    LEARN_UNKNOWN = "Learning status unknown (open your profession window for better detection)",
    TRAINER_RECIPE = "trainer recipe",
    SKILL_REQUIREMENT = "  Requires profession skill: %s",
    TRAINER_AT = "  Trainer %s: %s",
    TRAINER_UNCONFIRMED = "  Specific trainer for this recipe is unconfirmed.",
    TRAINER_SUGGEST = "  Try a profession trainer: %s (Classic reference; recipe availability not guaranteed)",
    TRAINER_BORROWED = "  Trainer source borrowed from Vanilla; not verified in Forever.",
    MORE_STAGES = "Additional stages omitted; level your profession and check again.",
    PLAN_INCOMPLETE = "Incomplete route: no eligible trainer recipe with usable skill-up data.",
    PLAN_DIAGNOSTIC = "Diagnostics: recipes %d, trainer sources %d, learnable %d, missing skill ranges %d",
    SHOPPING = "Missing materials (same-realm stock deducted):",
    ITEM_FALLBACK = "Item %d",
    SHOPPING_MORE = "Shopping list truncated at 35 entries.",
    COST = "Known Auctionator extra cost (excluding unknown prices): %dg %ds %dc",
    PRICES_INCOMPLETE = "Some prices are unknown; this route is not guaranteed cheapest.",
    PRICE_NOTE = "Note: %d reagent prices unknown; total cost is not available.",
    CHAR_NOT_READY = "Character data not ready",
    NO_ELIGIBLE = "No eligible professions or recipe database unavailable.",
    GUIDE_UNAVAILABLE = "Gathering guide unavailable",
    TRAINER_LOCATION_MISSING = "Trainer location not recorded",
    TRAINER_LOCATION_CLASSIC = "%s (%s) [Classic location, unverified in Forever]",
    GATHERING_HEADER = "%s %d/300 (text-only gathering guide)",
    TARGET_REACHED = "Default target reached.",
    GATHERING_ZONE = "  Suggested zones: %s",
    GATHERING_TRAINER = "Visit a trainer to raise your skill cap before 75/150/225.",
    GATHERING_CAUTION = "Zones are suggestions; validate nodes and mobs on Forever.",
    MINING_NOTE = "Mining: smelting can also raise skill. Verify recipes and furnaces in-game.",
    SKINNING_NOTE = "Skinning: above 100 skill, the maximum beast level is roughly skill/5 (Classic rule, unverified in Forever).",
  },
  zhTW = {
    TITLE = "永恆專業助手", LANGUAGE = "語言", AUTO = "自動",
    SCAN = "重新掃描", PLAN = "升級推薦", SWITCH = "切換專業",
    REALM = "伺服器：%s", DATABASE = "配方資料庫：%s",
    DB_LOADED = "已載入 %d 個配方", DB_NOT_READY = "未就緒：%s",
    DEV_WARNING = "開發測試版。未知材料不會標示為可出售。",
    CHARACTERS = "已記錄角色與專業：", NO_PROFESSION = "  尚無專業掃描資料",
    SNAPSHOT = "  背包：%s，銀行：%s", SCANNED = "已掃描", UNSCANNED = "未掃描",
    OVERVIEW_NOTE = "升級路線與訓練師資料為估算，請在遊戲內確認。",
    NEEDED = "需要（專業配方材料）", NOT_NEEDED = "不需要（同服目前專業配方未用到）",
    OTHER_USES = "不代表沒有任務／交易等其他用途",
    UNKNOWN_ITEM = "用途未確認（配方資料不足或非一般材料）",
    INVENTORY_TOTAL = "同伺服器已記錄庫存：%d", INVENTORY_LINE = "背包 %d / 銀行 %d",
    INCOMPLETE_BANKS = "部分角色銀行尚未掃描，總數可能偏低。",
    LEFT_CLICK = "左鍵：角色與庫存總覽", RIGHT_CLICK = "右鍵：專業升級推薦",
    READY = "已載入", UNKNOWN = "未知",
    DB_MISSING = "LibProfessionDB 未註冊（確認相依插件）",
    DB_WAIT = "資料庫尚未就緒", DB_WRONG = "非 Forever 配方資料",
    DB_API = "函式庫缺少 GetRecipes / GetRecipe", DB_EMPTY = "沒有解析到配方材料",
    PLAN_DB = "配方資料庫未就緒", PLAN_NOT_LEARNED_PROF = "目前角色尚未學習這個專業",
    PLAN_NO_RECIPES = "沒有可用的製造配方；採集專業請參考文字指南",
    PLAN_HEADER = "專業 %s，預估 %d → %d / %d",
    PLAN_DISCLAIMER = "規劃：貪婪估算，非全域最佳解；技能機率與材料數皆為預估。",
    LEARNED = "已學會", NOT_LEARNED = "尚未學會",
    LEARN_UNKNOWN = "尚未確認是否學會（開啟專業視窗可改善偵測）",
    TRAINER_RECIPE = "訓練師配方", SKILL_REQUIREMENT = "  學習條件：專業技能至少 %s",
    TRAINER_AT = "  找 %s：%s", TRAINER_UNCONFIRMED = "  無法確認此配方的指定訓練師。",
    TRAINER_SUGGEST = "  可先詢問同專業訓練師：%s（Classic 資料，不能保證教授此配方）",
    TRAINER_BORROWED = "  注意：訓練師來源沿用 Vanilla，永恆版本尚未確認。",
    MORE_STAGES = "其餘階段未顯示；可提高專業等級後重新查看。",
    PLAN_INCOMPLETE = "路線未完成：無符合條件且具備技能機率的訓練師配方。",
    PLAN_DIAGNOSTIC = "診斷：配方 %d、訓練師來源 %d、目前可學 %d、技能區間缺漏 %d",
    SHOPPING = "缺少材料（跨角色庫存已扣除）：", ITEM_FALLBACK = "物品 %d",
    SHOPPING_MORE = "購物清單較長，僅顯示前 35 項",
    COST = "已知 Auctionator 額外成本（不含未知價格）：%dg %ds %dc",
    PRICES_INCOMPLETE = "部分材料價格未知，推薦結果不保證最低成本。",
    PRICE_NOTE = "注意：%d 種材料價格未知，以上不是總成本。",
    CHAR_NOT_READY = "角色資料尚未就緒",
    NO_ELIGIBLE = "沒有可規劃的專業，或配方資料庫尚未就緒。",
    GUIDE_UNAVAILABLE = "採集指南尚未就緒",
    TRAINER_LOCATION_MISSING = "該訓練師位置尚未收錄",
    TRAINER_LOCATION_CLASSIC = "%s（%s）[Classic 位置，永恆待驗證]",
    GATHERING_HEADER = "%s %d/300（純文字採集指南）",
    TARGET_REACHED = "已達到預設目標。",
    GATHERING_ZONE = "  建議區域：%s",
    GATHERING_TRAINER = "技能上限達 75／150／225 前，記得找專業訓練師提升上限。",
    GATHERING_CAUTION = "區域為參考建議；採集點與怪物分布需在永恆伺服器實際確認。",
    MINING_NOTE = "採礦：熔煉也可提升技能，配方與可用爐具請以遊戲內顯示為準。",
    SKINNING_NOTE = "剝皮：技能 100 以上通常可剝取最高約技能／5 等級的野獸（Classic 規則，永恆待驗證）。",
  },
}
-- Simplified Chinese currently falls back to Traditional for any untranslated
-- keys. Keep key names stable so adding translations is straightforward.
dictionaries.zhCN = {
  TITLE = "永恒专业助手", LANGUAGE = "语言", AUTO = "自动",
  SCAN = "重新扫描", PLAN = "升级推荐", SWITCH = "切换专业",
  REALM = "服务器：%s", CHARACTERS = "已记录角色与专业：",
  NEEDED = "需要（专业配方材料）", NOT_NEEDED = "不需要（当前专业配方未使用）",
  UNKNOWN_ITEM = "用途未确认（配方数据不足）",
  LEFT_CLICK = "左键：角色与库存", RIGHT_CLICK = "右键：专业升级推荐",
}

A.languageCodes = {"auto", "zhTW", "zhCN", "enUS"}
A.languageNames = {auto = "Auto / 自動", zhTW = "繁體中文", zhCN = "简体中文", enUS = "English"}

function A:GetLanguage()
  local setting = self.db and self.db.language or "auto"
  if setting ~= "auto" then return dictionaries[setting] and setting or "enUS" end
  local locale = GetLocale and GetLocale() or "enUS"
  return dictionaries[locale] and locale or "enUS"
end

function A:T(key, ...)
  local locale = self:GetLanguage()
  local dict = dictionaries[locale] or dictionaries.enUS
  local template = dict[key] or (locale == "zhCN" and dictionaries.zhTW[key]) or dictionaries.enUS[key] or key
  if select("#", ...) == 0 then return template end
  local ok, output = pcall(string.format, template, ...)
  return ok and output or template
end

function A:SetLanguage(code)
  if not self.db or (code ~= "auto" and not dictionaries[code]) then return end
  self.db.language = code
  self:Notify("language")
end

function A:CycleLanguage()
  local codes = self.languageCodes
  local selected = (self.db and self.db.language) or "auto"
  local index = 1
  for i, code in ipairs(codes) do if code == selected then index = i; break end end
  self:SetLanguage(codes[index % #codes + 1])
end
