# 角色素材對照

基礎角色沿用原本模型，待機與攻擊分開使用：

| 角色 | 待機圖 | 攻擊圖 | 戰鬥定位 |
|---|---|---|---|
| 紅牛 | `red_bull.png` | `red_bull_attack.png` | 單體重擊 |
| 橘壁虎 | `gecko.png` | `gecko_attack.png` | 快速連射 |
| 綠恐龍 | `dino.png` | `dino_attack.png` | 範圍濺射 |

滿階融合角色同樣各有待機與攻擊圖：

| 配方 | 融合角色 | 待機圖 | 攻擊圖 |
|---|---|---|---|
| 紅牛 + 橘壁虎 | 雙人連擊 | `fusion_duo_shooter.png` | `fusion_duo_shooter_attack.png` |
| 紅牛 + 綠恐龍 | 市場戰車 | `fusion_market_tank.png` | `fusion_market_tank_attack.png` |
| 橘壁虎 + 綠恐龍 | 牛市飛機 | `fusion_bull_market_plane.png` | `fusion_bull_market_plane_attack.png` |

基礎角色的階級外觀使用 `tiers/*_tiers.png` 四格圖集；融合角色以專用單張圖呈現，
在盤面上用 `EX` 角標標示。中性棋盤格背景會由 `shaders/checkerboard_cutout.gdshader`
處理透明化。
