# 生成美術資產

目前執行中的 `stock_*` 素材以「深藍交易所、綠色上漲、紅色下跌、暖金 K 線與
投資金庫」為核心，讓背景、道路、召喚、合成、攻擊、Boss 護盾與 HUD 都共享
同一套股市語言。原本 `assets/characters/` 的口袋吉祥物與階級裝備保持不變。

## 目前使用中的股市素材

| 檔案 | 用途 | 格式說明 |
|---|---|---|
| `stock_market_background.png` | 交易所戰場背景 | 不透明直式背景 |
| `stock_t_path_overlay.png` | 股市 T 型道路 | 透明背景，完整 T 型道路 |
| `stock_junction_core.png` | 多空匯流核心 | 透明背景，單一特效 |
| `stock_summon_effect.png` | 買入／召喚特效 | 透明背景，單一特效 |
| `stock_merge_effect.png` | 合併部位升階特效 | 透明背景，單一特效 |
| `stock_combat_effects_sheet.png` | 三種守衛攻擊 | 透明背景，三欄 spritesheet |
| `stock_bear_enemy_sheet.png` | 七階熊市敵人 | 透明背景，七欄 spritesheet |
| `stock_market_ui_sheet.png` | 股市 HUD 圖示 | 透明背景，4×3 圖示表 |
| `stock_vault_states_sheet.png` | 投資金庫狀態 | 透明背景，五狀態圖表 |
| `stock_boss_shield_states.png` | Boss熊股市護盾 | 透明背景，四狀態圖表 |

## 舊版素材

| 檔案 | 用途 | 格式說明 |
|---|---|---|
| `battlefield_background.png` | 戰場背景候選 | 不透明直式背景 |
| `t_path_overlay.png` | T 型道路候選 | 透明背景，完整 T 型道路 |
| `junction_core.png` | 中央匯流點 | 透明背景，單一特效 |
| `summon_effect.png` | 召喚特效 | 透明背景，單一特效 |
| `merge_effect.png` | 合成升階特效 | 透明背景，單一特效 |
| `attack_effects_sheet.png` | 三種守衛攻擊 | 透明背景，三欄 spritesheet |
| `enemy_sheet.png` | 四種敵人設計 | 透明背景，四角色設計稿 |
| `ui_icons_sheet.png` | HUD 圖示 | 透明背景，4×3 圖示表 |
| `vault_states_sheet.png` | 金庫狀態 | 透明背景，五狀態圖表 |
| `boss_shield_states.png` | Boss 暈眩盾 | 透明背景，四狀態圖表 |

舊版檔案保留作為歷史參考與 fallback，不再是目前場景的執行素材。

## 接入方式

除背景、召喚與合成單圖外，其餘圖檔多數是「素材表」而不是最終單張貼圖。
本專案在 Godot 內以 `AtlasTexture` 依格線裁切，避免複製出大量重複 PNG；
七階熊、HUD、Boss 護盾、金庫與攻擊效果都由圖集裁切使用。不要把整張圖集
直接指定給單一 Sprite2D。

所有圖檔均為 PNG。透明素材保留 RGBA alpha；背景圖則為不透明 RGB。
