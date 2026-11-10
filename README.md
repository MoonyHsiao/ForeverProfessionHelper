# Forever Profession Helper（永恆專業助手）

WoW Forever 1.60.1 專業材料管理、同伺服器跨角色庫存，以及專業技能升級路線輔助。

## v0.3.4 開發測試版

此版本已新增製造專業升級規劃的**第一階段實作**及採集專業文字指南。尚未經遊戲內實測，不保證資料庫 API 或畫面能在所有客戶端正常運作。完整規格見 [SPEC.md](SPEC.md)。

## 安裝前必須準備的插件

| 插件 | 必要性 | 說明 |
| --- | --- | --- |
| [LibProfessionDB](https://www.curseforge.com/wow/addons/libprofessiondb) | **必要** | 必須安裝 Forever 1.60.1 專用版本（例如 v1.9.1）；提供尚未學習的配方與材料資料 |
| [Ace3](https://www.curseforge.com/wow/addons/ace3) | **LibProfessionDB 相依套件** | 需確認能在 Forever 客戶端載入 |
| [LibVersionCheck](https://www.curseforge.com/wow/addons/versioncheck) | **LibProfessionDB 相依套件** | 需選 Forever 版本；遊戲中會顯示 Lib: VersionCheck-1.0 |
| [Auctionator](https://www.curseforge.com/wow/addons/auctionator) | **選用，成本推薦建議安裝** | 提供最後掃描的拍賣價格；必須有拍賣資料才能估算金幣 |

### 安裝與檢查

1. 在 CurseForge 選擇 Forever 1.60.1，安裝 LibProfessionDB；依賴 Ace3、LibVersionCheck 需能正常載入。不要只看 CurseForge 的「已安裝」標籤。
2. 將本儲存庫的 `*.lua` 與 `ForeverProfessionHelper.toc` 放進 `Interface/AddOns/ForeverProfessionHelper/`（切勿多包一層）。
3. 在角色選擇畫面勾選 **Lib: ProfessionDB Forever** 與本插件；若顯示「關聯功能短少」，先檢查 Ace3 / LibVersionCheck。
4. 載入遊戲輸入 `/fph db`，應顯示配方筆數與已覆蓋的專業 ID。資料庫正常註冊的驗證指令：
   ```lua
   /run print("Lib:", LibStub and LibStub("LibProfessionDB-1.0", true))
   ```
   顯示 `table` 是成功取得函式庫；`nil` 則尚未成功註冊。
5. 每個角色至少登入一次，並開啟銀行以更新銀行庫存。其他角色顯示最後快照。

## OneForAll 小地圖按鈕整合

v0.3.4 修正：在 .toc 註冊 MinimapButton.lua，修復 v0.3.3 按鈕完全未載入的問題。

已加入 32×32 的小地圖啟動按鈕，無須修改 OneForAll 或額外登記。左鍵開啟總覽、右鍵開啟升級推薦。OneForAll 的「Quality of Life → Collect minimap buttons」開啟後，會掃描小地圖上的普通按鈕並收入收集列。這個整合依據 OneForAll 6.2.2 原始碼製作，尚待遊戲內實測。

## 使用指令

- `/fph`：開啟角色和庫存概覽。
- `/fph plan`：開啟升級推薦，預設第一個已記錄的專業。
- `/fph plan 164`：指定專業 ID（例如 164 為鍛造）；視窗可按「切換專業」輪流查看已學的專業。
- `/fph db`：顯示配方資料庫載入狀態、解析筆數與專業 ID。
- `/fph scan`：重新掃描目前可讀的背包、銀行、專業。
- `/fph help`：查看指令。

## 已實作的功能

- 同伺服器所有已登入角色的專業與背包、銀行庫存快照。
- 物品 Tooltip 顯示跨角色庫存與專業用途。
- 配方資料庫的材料反向索引；資料不足時**不會標示「可賣」**。
- 根據目前技能、訓練師來源、配方材料與庫存產生逐級**近似最低額外花費**的製造路線。
- 使用 Auctionator 公開 API `Auctionator.API.v1.GetAuctionPriceByItemID` 取得已掃描單價。
- 按專業獨立估算所缺材料與已知價格部分的額外成本。
- 新增草藥學、採礦、剝皮的 1～300 文字採集指南（採集地圖與技能門檻為參考資料，Forever 實況待驗證）。
- 升級推薦加入學習狀態（已學會／尚未學會／未確認）、學習所需專業技能、訓練師姓名與已收錄地點。對沒有明確對應 NPC 的製皮配方提供同陣營的一般專業訓練師參考，**不保證該 NPC 教授指定配方**。舊版 Classic 坐標及借用 Vanilla 的 Forever 來源會註明待驗證。

## 已知限制（請先閱讀）

- **這是逐級貪婪近似規劃，不是全域最低成本最佳化器**；每級用預期成功率估算次數，不應當作精確購買數量。
- 已可輪流切換已學專業，但仍未提供正式的多分頁 UI；採集指南使用靜態區間、未動態讀取採集點。
- 部分配方的訓練師及技能條件借用 Vanilla 資料，尚未在 Forever 客戶端確認。來源不明時不列入成本推薦。
- Auctionator 無價格時不會把物品的**商人賣價**誤當作購買成本；這些材料會顯示價格未知。若全都缺乏價格會嘗試使用可用訓練師配方，但無法保證是最低成本。
- 已加入配方學習狀態的保守檢查，但未開啟相關專業視窗時可能回報未確認；專精限制仍不能保證完整判斷。
- 目前未自動把熔煉等中間製成品展開計算，也不會模擬拍賣稅與拍賣場供給數量。
- 沒有遊戲實測；錯誤回報請提供 Lua 錯誤及 `/fph db` 的資料。

## 資料安全

所有物品整理、存銀行、郵寄與出售均由玩家手動進行。插件不會自動購物、賣出或寄送。
