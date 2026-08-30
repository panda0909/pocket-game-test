# 資產處理

程式化產生舊版敵人與金庫的遊戲貼圖。守衛用的三隻吉祥物沿用前作 Game1
已去背的 PNG；目前執行中的股市戰場、七種熊、角色攻擊／待機圖、融合角色、
特效、HUD 與狀態素材另存於 `assets/characters/`、`assets/characters/tiers/`
與 `assets/generated/stock_*.png`，不在本腳本重建範圍。

## 重建環境

`tools/.venv/` 不進版控，換一台機器要重建：

    python3 -m venv tools/.venv
    tools/.venv/bin/pip install Pillow

## 執行

    tools/.venv/bin/python tools/prepare_assets.py

輸出到 `assets/enemies/` 與 `assets/vault.png`。腳本可重複執行，
相同輸入永遠得到相同輸出。

## 為什麼用程式畫而不是手繪

顏色與尺寸都是腳本裡的常數，要調整平衡或辨識度時改一個數字重跑即可，
不必回頭找繪圖檔。四倍尺寸繪製再縮小是為了得到平滑邊緣。

大盜的紅披風就是這樣調出來的：第一版的多邊形幾乎整片被身體橢圓蓋住，
只要把左緣往外拉到 `x = 0.02` 就明顯了。辨識度是玩家能不能反應過來的
前提，值得為此多跑一次腳本。
