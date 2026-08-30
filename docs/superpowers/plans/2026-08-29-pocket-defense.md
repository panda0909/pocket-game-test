# 《口袋守衛戰》實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出以口袋吉祥物為主角的隨機合成塔防網頁遊戲：隨機召喚守衛、同階合成升級且種類隨機、抵擋無限波次的小偷。

**Architecture:** 所有遊戲規則抽成 `scripts/` 下六個不繼承 `Node` 的純類別，接受可注入的亂數產生器，因此能在沒有場景樹的情況下完整單元測試。節點只負責畫面與輸入：`Main` 管流程、`BoardView` 管拖曳、`UnitView` 索敵開火、`Enemy` 沿 `PathFollow2D` 前進、`HUD` 顯示。跨節點溝通一律用訊號，方向由子節點往上送給 `Main`。

**Tech Stack:** Godot 4.7.2 stable、GDScript、GUT 9.7.1、Python 3 + Pillow。

**Spec:** [docs/superpowers/specs/2026-08-29-pocket-defense-design.md](../specs/2026-08-29-pocket-defense-design.md)

## Global Constraints

- Godot 執行檔：`/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot`
- 專案根目錄：`/Users/hongming/SourceCode/Personal/Pocket/Game2`，所有指令在此執行
- 前作專案（工具與資產來源）：`/Users/hongming/SourceCode/Personal/Pocket/Game1`
- 解析度 720×1280 直式；`window/stretch/mode="canvas_items"`、`window/stretch/aspect="keep"`
- 算繪後端固定 `gl_compatibility`（HTML5 匯出的必要條件）
- 守衛格：4 欄 × 3 列，格子邊長 130，第一格中心 `(165, 465)`
- 軌道：起點 `(60, 300)` → `(60, 900)` → `(660, 900)` → 終點 `(660, 300)`
- 階級上限 7；傷害倍率 `2.4^(階級-1)`；射程加成 `15 × (階級-1)`
- 敵人生命成長 `1.28^(波次-1)`
- 起始金幣 60、起始生命 20、召喚費用 `20 + 4 × 已召喚次數`
- 擊殺獎勵 `2 + floor(波次/3)`、過關獎勵 `10 + 2 × 波次`
- GDScript 縮排使用 **Tab**
- 所有註解與 UI 文字使用繁體中文
- 每個任務結束都要 commit

## 驗證指令

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
```

| 用途 | 指令 |
|---|---|
| 完整驗證（語法＋單元＋整合） | `tools/verify_game.sh` |
| 只跑單元測試 | `tools/run_tests.sh` |
| 擷取畫面 | `$GODOT --path . tools/capture.tscn -- /tmp/shot.png 300` |

**不要直接呼叫 `gut_cmdln.gd`**：GUT 遇到剖析失敗的測試檔會靜默略過並回報「全部通過」，結束碼也是 0。`tools/run_tests.sh` 會比對載入檔數與磁碟檔數來擋下這種情況。

---

### Task 1: 專案骨架與工具移植

建立可執行的 Godot 專案，並把前作驗證過的工具鏈搬過來。這個任務結束時還沒有遊戲，但三層驗證必須跑得通。

**Files:**
- Create: `project.godot`、`.gutconfig.json`
- Copy: `addons/gut/`、`tools/run_tests.sh`、`tools/capture.gd`、`tools/capture.tscn`、`assets/fonts/NotoSansTC-Bold.otf`、`assets/theme.tres`（皆自 Game1）
- Create: `test/unit/test_smoke.gd`

**Interfaces:**
- Produces: 可執行的 `tools/run_tests.sh`（供後續所有任務驗證）；`assets/theme.tres` 提供中文字型與配色

- [ ] **Step 1: 從前作複製工具與資產**

```bash
cd /Users/hongming/SourceCode/Personal/Pocket/Game2
SRC=/Users/hongming/SourceCode/Personal/Pocket/Game1
mkdir -p addons tools assets/fonts assets/characters test/unit scripts scenes
cp -R "$SRC/addons/gut" addons/gut
cp "$SRC/tools/run_tests.sh" "$SRC/tools/capture.gd" "$SRC/tools/capture.tscn" tools/
cp "$SRC/assets/fonts/NotoSansTC-Bold.otf" assets/fonts/
cp "$SRC/assets/theme.tres" assets/
cp "$SRC/assets/characters/red_bull.png" "$SRC/assets/characters/gecko.png" "$SRC/assets/characters/dino.png" assets/characters/
chmod +x tools/run_tests.sh
ls addons/gut/gut_cmdln.gd assets/theme.tres assets/characters/
```

預期：三個檔案路徑都存在，`assets/characters/` 有三張 PNG。

- [ ] **Step 2: 寫 project.godot**

按鍵碼與輸入對應表寫法在前作已實測驗證。本作不需要方向鍵，但保留 `ui_accept` 之外不另外定義輸入動作——操作全靠滑鼠／觸控。

```
config_version=5

[application]

config/name="口袋守衛戰"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://assets/characters/red_bull.png"

[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 3: 寫 GUT 設定檔**

建立 `.gutconfig.json`：

```json
{
	"dirs": ["res://test/unit"],
	"include_subdirs": true,
	"log_level": 1,
	"should_exit": true
}
```

- [ ] **Step 4: 寫冒煙測試**

建立 `test/unit/test_smoke.gd`：

```gdscript
extends GutTest

## 只確認 GUT 本身跑得起來。加入真正的測試後就刪掉。
func test_gut_is_working() -> void:
	assert_eq(1 + 1, 2, "GUT 測試環境正常")
```

- [ ] **Step 5: 執行測試確認環境可用**

```bash
tools/run_tests.sh
```

預期：`測試檔 1/1 載入　通過 1　失敗 0`、`全部通過`，結束碼 0。

- [ ] **Step 6: 建立 .gitignore 以外的目錄結構並 commit**

```bash
git add -A
git commit -m "建立專案骨架，移植前作的測試工具與字型資產"
```

---

### Task 2: 敵人與金庫美術產生

用與前作相同的 Pillow 管線程式化產生小偷與金庫的圖。程式化而非手繪，是為了維持「相同輸入永遠得到相同輸出」，並讓調整顏色與尺寸只需改一個數字。

**Files:**
- Create: `tools/prepare_assets.py`、`tools/README.md`
- Create（由腳本產生）：`assets/enemies/thief.png`、`runner.png`、`brute.png`、`boss.png`、`assets/vault.png`

**Interfaces:**
- Produces: 五張 PNG。`WaveTable.texture_path()`（Task 5）會引用 `res://assets/enemies/{thief,runner,brute,boss}.png`

- [ ] **Step 1: 建立 Python 環境**

```bash
cd /Users/hongming/SourceCode/Personal/Pocket/Game2
python3 -m venv tools/.venv
tools/.venv/bin/pip install -q Pillow
tools/.venv/bin/python -c "import PIL; print('Pillow', PIL.__version__)"
```

預期：印出 `Pillow 12.x`。

- [ ] **Step 2: 寫資產產生腳本**

建立 `tools/prepare_assets.py`：

```python
"""程式化產生小偷與金庫的遊戲貼圖。

執行方式：
    tools/.venv/bin/python tools/prepare_assets.py

所有圖都以四倍尺寸繪製再縮小，藉此得到平滑邊緣。
相同輸入永遠產生相同輸出，可以安全地重複執行。
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY_DIR = os.path.join(ROOT, "assets", "enemies")
ASSET_DIR = os.path.join(ROOT, "assets")

SUPERSAMPLE = 4
OUTLINE = (20, 20, 24, 255)

# 名稱 -> (輸出尺寸, 身體顏色, 是否加披風)
ENEMIES = {
    "thief": (96, (58, 68, 110, 255), False),
    "runner": (80, (72, 132, 148, 255), False),
    "brute": (120, (46, 52, 78, 255), False),
    "boss": (140, (38, 40, 62, 255), True),
}


def draw_thief(size, body_color, cape):
    """小偷：深色圓身、白色蒙面橫帶、背上米色錢袋。"""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline_width = max(2, int(big * 0.035))

    if cape:
        # 披風畫在身體後面，往左後方甩出去
        draw.polygon(
            [
                (big * 0.42, big * 0.28),
                (big * 0.08, big * 0.62),
                (big * 0.20, big * 0.88),
                (big * 0.46, big * 0.72),
            ],
            fill=(196, 42, 52, 255),
            outline=OUTLINE,
        )

    # 錢袋背在右後方
    sack = (big * 0.62, big * 0.30, big * 0.96, big * 0.66)
    draw.ellipse(sack, fill=(228, 206, 160, 255), outline=OUTLINE, width=outline_width)
    draw.line(
        [(big * 0.70, big * 0.31), (big * 0.88, big * 0.31)],
        fill=OUTLINE,
        width=outline_width,
    )

    # 身體
    body = (big * 0.14, big * 0.22, big * 0.78, big * 0.94)
    draw.ellipse(body, fill=body_color, outline=OUTLINE, width=outline_width)

    # 蒙面橫帶
    band_top = big * 0.38
    band_bottom = big * 0.50
    draw.rectangle(
        (big * 0.18, band_top, big * 0.74, band_bottom),
        fill=(246, 246, 250, 255),
    )
    # 兩顆眼睛
    eye_y = (band_top + band_bottom) / 2
    eye_r = big * 0.035
    for eye_x in (big * 0.34, big * 0.56):
        draw.ellipse(
            (eye_x - eye_r, eye_y - eye_r, eye_x + eye_r, eye_y + eye_r),
            fill=OUTLINE,
        )

    return image.resize((size, size), Image.LANCZOS)


def draw_vault(size=160):
    """金庫：深灰保險箱、金色轉盤與門縫。"""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline_width = max(2, int(big * 0.03))

    pad = big * 0.08
    draw.rounded_rectangle(
        (pad, pad, big - pad, big - pad),
        radius=big * 0.10,
        fill=(84, 88, 100, 255),
        outline=OUTLINE,
        width=outline_width,
    )
    inner = big * 0.18
    draw.rounded_rectangle(
        (inner, inner, big - inner, big - inner),
        radius=big * 0.06,
        fill=(108, 112, 126, 255),
        outline=OUTLINE,
        width=outline_width,
    )

    # 轉盤
    center = big / 2
    dial = big * 0.14
    draw.ellipse(
        (center - dial, center - dial, center + dial, center + dial),
        fill=(255, 196, 0, 255),
        outline=OUTLINE,
        width=outline_width,
    )
    spoke = big * 0.20
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        draw.line(
            [(center, center), (center + dx * spoke, center + dy * spoke)],
            fill=OUTLINE,
            width=outline_width,
        )

    return image.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ENEMY_DIR, exist_ok=True)

    for name, (size, color, cape) in sorted(ENEMIES.items()):
        path = os.path.join(ENEMY_DIR, name + ".png")
        draw_thief(size, color, cape).save(path)
        print(f"敵人 {name}.png ({size}, {size})")

    vault_path = os.path.join(ASSET_DIR, "vault.png")
    draw_vault().save(vault_path)
    print("金庫 vault.png (160, 160)")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: 執行腳本**

```bash
tools/.venv/bin/python tools/prepare_assets.py
```

預期：五行輸出，尺寸分別為 thief 96、runner 80、brute 120、boss 140、vault 160。

- [ ] **Step 4: 驗證輸出**

```bash
tools/.venv/bin/python -c "
from PIL import Image
import glob, sys
fail = False
for f in sorted(glob.glob('assets/**/*.png', recursive=True)):
    im = Image.open(f)
    transparent = sum(1 for p in im.getchannel('A').tobytes() if p == 0)
    total = im.width * im.height
    print(f, im.size, im.mode, f'透明 {transparent * 100 // total}%')
    if im.mode != 'RGBA' or transparent == 0:
        print('  ^^ 失敗：沒有透明區域'); fail = True
sys.exit(1 if fail else 0)
"
echo "結束碼: $?"
```

預期：所有 PNG 皆為 RGBA 且透明比例大於 0，結束碼 0。

- [ ] **Step 5: 目視確認四種敵人與金庫**

用 Read 工具開啟 `assets/enemies/thief.png`、`assets/enemies/boss.png`、`assets/vault.png`，確認：小偷看得出是蒙面人形且背著錢袋、大盜有紅色披風可辨識、金庫看得出是保險箱。若形狀難以辨認就調整 `draw_thief` 的比例數值後重跑。

- [ ] **Step 6: 寫 tools/README.md**

```markdown
# 資產處理

程式化產生小偷與金庫的遊戲貼圖。守衛用的三隻吉祥物沿用前作 Game1
已去背的 PNG，直接複製過來，不在本腳本處理範圍。

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
```

- [ ] **Step 7: Commit**

```bash
git add tools assets
git commit -m "新增敵人與金庫的程式化美術產生腳本"
```

---

### Task 3: 守衛數值與經濟（TDD）

先寫測試再寫實作。這兩個類別是遊戲的數值核心，完全不依賴場景樹。

**Files:**
- Create: `scripts/unit_stats.gd`、`scripts/economy.gd`
- Create: `test/unit/test_unit_stats.gd`、`test/unit/test_economy.gd`
- Delete: `test/unit/test_smoke.gd`

**Interfaces:**
- Produces:
  - `UnitStats.Kind`（列舉 `BULL`、`GECKO`、`DINO`）、`UnitStats.MAX_TIER`（7）
  - `UnitStats.damage(kind: int, tier: int) -> float`
  - `UnitStats.attack_interval(kind: int) -> float`
  - `UnitStats.attack_range(kind: int, tier: int) -> float`
  - `UnitStats.splash_radius(kind: int) -> float`
  - `UnitStats.texture_path(kind: int) -> String`
  - `Economy` 實例屬性 `gold: int`、`lives: int`、`summons_done: int`
  - `Economy.reset()`、`summon_cost() -> int`、`can_afford_summon() -> bool`、`pay_summon()`、`add_gold(int)`、`lose_lives(int)`、`is_defeated() -> bool`
  - `Economy.kill_reward(wave: int) -> int`、`Economy.wave_reward(wave: int) -> int`（靜態）

- [ ] **Step 1: 寫失敗的測試**

建立 `test/unit/test_unit_stats.gd`：

```gdscript
extends GutTest

func test_tier_one_damage_matches_base() -> void:
	assert_almost_eq(UnitStats.damage(UnitStats.Kind.BULL, 1), 12.0, 0.001)
	assert_almost_eq(UnitStats.damage(UnitStats.Kind.GECKO, 1), 4.0, 0.001)
	assert_almost_eq(UnitStats.damage(UnitStats.Kind.DINO, 1), 7.0, 0.001)

func test_each_tier_multiplies_damage() -> void:
	var t1 := UnitStats.damage(UnitStats.Kind.BULL, 1)
	var t2 := UnitStats.damage(UnitStats.Kind.BULL, 2)
	assert_almost_eq(t2 / t1, 2.4, 0.001, "每升一階傷害應為 2.4 倍")

func test_max_tier_damage_beats_two_of_previous_tier() -> void:
	# 合成消耗兩隻低階換一隻高階。若倍率不大於 2，合成就只是把兩格併成
	# 一格而沒有變強，玩家沒有動機合成——這個測試守住這個設計前提。
	for tier in range(1, UnitStats.MAX_TIER):
		var lower := UnitStats.damage(UnitStats.Kind.DINO, tier)
		var higher := UnitStats.damage(UnitStats.Kind.DINO, tier + 1)
		assert_gt(higher, lower * 2.0, "第 %d 階合成後應強於兩隻低階相加" % tier)

func test_range_grows_with_tier() -> void:
	var base := UnitStats.attack_range(UnitStats.Kind.BULL, 1)
	assert_almost_eq(base, 340.0, 0.001)
	assert_almost_eq(UnitStats.attack_range(UnitStats.Kind.BULL, 3), base + 30.0, 0.001)

func test_attack_interval_does_not_change_with_tier() -> void:
	assert_almost_eq(UnitStats.attack_interval(UnitStats.Kind.GECKO), 0.35, 0.001)

func test_only_dino_has_splash() -> void:
	assert_eq(UnitStats.splash_radius(UnitStats.Kind.BULL), 0.0)
	assert_eq(UnitStats.splash_radius(UnitStats.Kind.GECKO), 0.0)
	assert_almost_eq(UnitStats.splash_radius(UnitStats.Kind.DINO), 70.0, 0.001)

func test_texture_paths_exist() -> void:
	for kind in [UnitStats.Kind.BULL, UnitStats.Kind.GECKO, UnitStats.Kind.DINO]:
		var path := UnitStats.texture_path(kind)
		assert_true(ResourceLoader.exists(path), "找不到貼圖 %s" % path)
```

建立 `test/unit/test_economy.gd`：

```gdscript
extends GutTest

var economy: Economy

func before_each() -> void:
	economy = Economy.new()

func test_starting_values() -> void:
	assert_eq(economy.gold, 60)
	assert_eq(economy.lives, 20)
	assert_eq(economy.summons_done, 0)

func test_summon_cost_increases_each_summon() -> void:
	assert_eq(economy.summon_cost(), 20)
	economy.pay_summon()
	assert_eq(economy.summon_cost(), 24)
	economy.pay_summon()
	assert_eq(economy.summon_cost(), 28)

func test_pay_summon_deducts_gold() -> void:
	economy.pay_summon()
	assert_eq(economy.gold, 40, "60 減去第一次的 20")

func test_cannot_afford_when_gold_below_cost() -> void:
	economy.gold = 19
	assert_false(economy.can_afford_summon())
	economy.gold = 20
	assert_true(economy.can_afford_summon())

func test_kill_reward_grows_every_three_waves() -> void:
	assert_eq(Economy.kill_reward(1), 2)
	assert_eq(Economy.kill_reward(3), 3)
	assert_eq(Economy.kill_reward(9), 5)

func test_wave_reward_formula() -> void:
	assert_eq(Economy.wave_reward(1), 12)
	assert_eq(Economy.wave_reward(10), 30)

func test_losing_all_lives_is_defeat() -> void:
	assert_false(economy.is_defeated())
	economy.lose_lives(20)
	assert_true(economy.is_defeated())

func test_lives_never_go_below_zero() -> void:
	# 大盜一次偷 3 點，剩 1 點生命時不該變成負數，否則 HUD 會顯示負值
	economy.lives = 1
	economy.lose_lives(3)
	assert_eq(economy.lives, 0)

func test_reset_restores_starting_state() -> void:
	economy.pay_summon()
	economy.lose_lives(5)
	economy.reset()
	assert_eq(economy.gold, 60)
	assert_eq(economy.lives, 20)
	assert_eq(economy.summons_done, 0)
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
tools/run_tests.sh
```

預期：結束碼 1，訊息顯示有測試檔沒載入，原因是 `UnitStats` 與 `Economy` 尚未宣告。**先看到失敗再往下寫，才能確定測試真的有在驗東西。**

- [ ] **Step 3: 寫 UnitStats**

建立 `scripts/unit_stats.gd`：

```gdscript
class_name UnitStats
extends RefCounted

## 守衛的數值表。不繼承 Node，測試不必建立場景樹。

enum Kind { BULL, GECKO, DINO }

const MAX_TIER := 7
## 每升一階的傷害倍率。刻意大於 2：合成要消耗兩隻低階，倍率若只有 2，
## 合成就只是把兩格併成一格而沒有變強，玩家沒有動機去合。
const TIER_DAMAGE_MULTIPLIER := 2.4
const RANGE_PER_TIER := 15.0

const BASE := {
	Kind.BULL: {
		"damage": 12.0, "interval": 1.2, "range": 340.0, "splash": 0.0,
		"texture": "res://assets/characters/red_bull.png",
	},
	Kind.GECKO: {
		"damage": 4.0, "interval": 0.35, "range": 320.0, "splash": 0.0,
		"texture": "res://assets/characters/gecko.png",
	},
	Kind.DINO: {
		"damage": 7.0, "interval": 1.0, "range": 330.0, "splash": 70.0,
		"texture": "res://assets/characters/dino.png",
	},
}


static func damage(kind: int, tier: int) -> float:
	return float(BASE[kind]["damage"]) * pow(TIER_DAMAGE_MULTIPLIER, tier - 1)


## 攻擊間隔只由種類決定，不隨階級改變——升階加傷害不加攻速，
## 這樣三個種類的定位差異在後期才不會被抹平。
static func attack_interval(kind: int) -> float:
	return float(BASE[kind]["interval"])


static func attack_range(kind: int, tier: int) -> float:
	return float(BASE[kind]["range"]) + RANGE_PER_TIER * (tier - 1)


static func splash_radius(kind: int) -> float:
	return float(BASE[kind]["splash"])


static func texture_path(kind: int) -> String:
	return String(BASE[kind]["texture"])
```

- [ ] **Step 4: 寫 Economy**

建立 `scripts/economy.gd`：

```gdscript
class_name Economy
extends RefCounted

## 金幣、生命與召喚費用。整個遊戲的難度旋鈕都集中在這裡，
## 試玩後要調手感只需要動這個檔案。

const STARTING_GOLD := 60
const STARTING_LIVES := 20
const SUMMON_BASE_COST := 20
const SUMMON_COST_STEP := 4

var gold: int = STARTING_GOLD
var lives: int = STARTING_LIVES
var summons_done: int = 0


func reset() -> void:
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	summons_done = 0


## 召喚費用單調遞增且不重置。這條曲線決定玩家能鋪多少單位、
## 什麼時候必須改靠合成而非數量取勝。
func summon_cost() -> int:
	return SUMMON_BASE_COST + SUMMON_COST_STEP * summons_done


func can_afford_summon() -> bool:
	return gold >= summon_cost()


func pay_summon() -> void:
	gold -= summon_cost()
	summons_done += 1


func add_gold(amount: int) -> void:
	gold += amount


func lose_lives(amount: int) -> void:
	lives = maxi(0, lives - amount)


func is_defeated() -> bool:
	return lives <= 0


static func kill_reward(wave: int) -> int:
	return 2 + wave / 3


static func wave_reward(wave: int) -> int:
	return 10 + 2 * wave
```

- [ ] **Step 5: 刪掉冒煙測試並執行**

```bash
rm test/unit/test_smoke.gd
tools/run_tests.sh
```

預期：`測試檔 2/2 載入`、`通過 16`、`全部通過`，結束碼 0。

- [ ] **Step 6: Commit**

```bash
git add scripts test
git commit -m "新增守衛數值表與經濟規則，含單元測試"
```

---

### Task 4: 棋盤與合成規則（TDD）

棋盤是遊戲的真相來源，且合成帶有隨機性。**亂數必須可注入**，否則之後每個牽涉合成的測試都會間歇性失敗，而事後補救要動到所有呼叫端。

**Files:**
- Create: `scripts/merge_rules.gd`、`scripts/board.gd`
- Create: `test/unit/test_merge_rules.gd`、`test/unit/test_board.gd`

**Interfaces:**
- Consumes: `UnitStats.MAX_TIER`（Task 3）
- Produces:
  - `MergeRules.can_merge(tier_a: int, tier_b: int) -> bool`
  - `MergeRules.merge_result(tier: int, rng: RandomNumberGenerator) -> Dictionary`（鍵為 `tier`、`kind`）
  - `Board.COLS`(4)、`Board.ROWS`(3)、`Board.CELL_SIZE`(130.0)、`Board.ORIGIN`(`Vector2(165, 465)`)
  - `Board.cell_center(index: int) -> Vector2`、`Board.index_at_position(pos: Vector2) -> int`（靜態）
  - 實例方法 `get_unit(index)`、`is_empty(index) -> bool`、`first_empty_index() -> int`、`has_empty() -> bool`、`place(index, kind, tier)`、`clear_cell(index)`、`clear_all()`、`occupied_indices() -> Array`
  - `Board.resolve_drop(from_index: int, to_index: int, rng: RandomNumberGenerator) -> Dictionary`（鍵 `action` 為 `"none"`／`"move"`／`"swap"`／`"merge"`）

- [ ] **Step 1: 寫失敗的測試**

建立 `test/unit/test_merge_rules.gd`：

```gdscript
extends GutTest

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_same_tier_can_merge() -> void:
	assert_true(MergeRules.can_merge(1, 1))
	assert_true(MergeRules.can_merge(6, 6))

func test_different_tier_cannot_merge() -> void:
	assert_false(MergeRules.can_merge(1, 2))

func test_max_tier_cannot_merge() -> void:
	assert_false(MergeRules.can_merge(UnitStats.MAX_TIER, UnitStats.MAX_TIER),
		"七階已是上限，不應再合成")

func test_merge_raises_tier_by_one() -> void:
	var result := MergeRules.merge_result(3, _rng(1))
	assert_eq(result["tier"], 4)

func test_merge_kind_is_one_of_three() -> void:
	for seed_value in range(30):
		var result := MergeRules.merge_result(1, _rng(seed_value))
		assert_between(result["kind"], UnitStats.Kind.BULL, UnitStats.Kind.DINO,
			"種類必須落在三種守衛之內")

func test_same_seed_gives_same_result() -> void:
	# 亂數可注入是刻意的設計。沒有這個性質，所有牽涉合成的測試
	# 都會變成間歇性失敗。
	var a := MergeRules.merge_result(2, _rng(42))
	var b := MergeRules.merge_result(2, _rng(42))
	assert_eq(a["kind"], b["kind"])

func test_kind_actually_varies_across_seeds() -> void:
	# 反過來守住「不是永遠回傳同一種」——隨機性壞掉時上面的測試抓不到
	var seen := {}
	for seed_value in range(50):
		seen[MergeRules.merge_result(1, _rng(seed_value))["kind"]] = true
	assert_gt(seen.size(), 1, "不同種子應該產生不同種類")
```

建立 `test/unit/test_board.gd`：

```gdscript
extends GutTest

var board: Board

func before_each() -> void:
	board = Board.new()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng

func test_starts_empty() -> void:
	assert_eq(board.occupied_indices().size(), 0)
	assert_true(board.has_empty())
	assert_eq(board.first_empty_index(), 0)

func test_place_and_read_back() -> void:
	board.place(5, UnitStats.Kind.GECKO, 2)
	var unit = board.get_unit(5)
	assert_eq(unit["kind"], UnitStats.Kind.GECKO)
	assert_eq(unit["tier"], 2)
	assert_false(board.is_empty(5))

func test_first_empty_skips_occupied() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(1, UnitStats.Kind.BULL, 1)
	assert_eq(board.first_empty_index(), 2)

func test_full_board_reports_no_empty() -> void:
	for i in Board.COLS * Board.ROWS:
		board.place(i, UnitStats.Kind.BULL, 1)
	assert_false(board.has_empty())
	assert_eq(board.first_empty_index(), -1)

func test_cell_center_matches_layout() -> void:
	assert_eq(Board.cell_center(0), Vector2(165, 465))
	assert_eq(Board.cell_center(3), Vector2(555, 465))
	assert_eq(Board.cell_center(11), Vector2(555, 725))

func test_index_at_position_round_trips() -> void:
	for i in Board.COLS * Board.ROWS:
		assert_eq(Board.index_at_position(Board.cell_center(i)), i)

func test_index_at_position_outside_board_is_minus_one() -> void:
	assert_eq(Board.index_at_position(Vector2(20, 465)), -1)
	assert_eq(Board.index_at_position(Vector2(360, 1200)), -1)

func test_drop_onto_empty_moves() -> void:
	board.place(0, UnitStats.Kind.DINO, 3)
	var result := board.resolve_drop(0, 4, _rng())
	assert_eq(result["action"], "move")
	assert_true(board.is_empty(0))
	assert_eq(board.get_unit(4)["tier"], 3)

func test_drop_onto_different_tier_swaps() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(1, UnitStats.Kind.GECKO, 2)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "swap")
	assert_eq(board.get_unit(0)["tier"], 2)
	assert_eq(board.get_unit(1)["tier"], 1)

func test_drop_onto_same_tier_merges() -> void:
	board.place(0, UnitStats.Kind.BULL, 2)
	board.place(1, UnitStats.Kind.GECKO, 2)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "merge")
	assert_true(board.is_empty(0), "來源格應該清空")
	assert_eq(board.get_unit(1)["tier"], 3, "目標格升為三階")

func test_max_tier_units_swap_instead_of_merging() -> void:
	board.place(0, UnitStats.Kind.BULL, UnitStats.MAX_TIER)
	board.place(1, UnitStats.Kind.DINO, UnitStats.MAX_TIER)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "swap", "七階不能再合成，應改為交換")

func test_drop_onto_self_does_nothing() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	var result := board.resolve_drop(0, 0, _rng())
	assert_eq(result["action"], "none")
	assert_eq(board.get_unit(0)["tier"], 1)

func test_drop_from_empty_cell_does_nothing() -> void:
	var result := board.resolve_drop(3, 4, _rng())
	assert_eq(result["action"], "none")

func test_clear_all_empties_board() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(7, UnitStats.Kind.DINO, 2)
	board.clear_all()
	assert_eq(board.occupied_indices().size(), 0)
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
tools/run_tests.sh
```

預期：結束碼 1，`MergeRules` 與 `Board` 尚未宣告。

- [ ] **Step 3: 寫 MergeRules**

建立 `scripts/merge_rules.gd`：

```gdscript
class_name MergeRules
extends RefCounted

## 合成規則。種類隨機是參考作品樂趣的來源：玩家得一邊應對手上拿到的牌、
## 一邊規劃防線。可預測的合成會讓遊戲退化成單純的數值累積。


static func can_merge(tier_a: int, tier_b: int) -> bool:
	return tier_a == tier_b and tier_a < UnitStats.MAX_TIER


## 回傳 {"tier": 新階級, "kind": 新種類}。
## rng 由呼叫端傳入，測試給固定種子就能穩定重現。
static func merge_result(tier: int, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"tier": tier + 1,
		"kind": rng.randi_range(UnitStats.Kind.BULL, UnitStats.Kind.DINO),
	}
```

- [ ] **Step 4: 寫 Board**

建立 `scripts/board.gd`：

```gdscript
class_name Board
extends RefCounted

## 守衛棋盤的唯一真相來源。純資料，不知道任何節點的存在，
## 因此所有棋盤規則都能在沒有場景樹的情況下測試。
## BoardView 只負責把這裡的狀態畫出來。

const COLS := 4
const ROWS := 3
const CELL_SIZE := 130.0
## 第一格（左上）的中心座標
const ORIGIN := Vector2(165.0, 465.0)

## 每格內容為 null 或 {"kind": int, "tier": int}
var _cells: Array = []


func _init() -> void:
	_cells.resize(COLS * ROWS)
	_cells.fill(null)


static func cell_count() -> int:
	return COLS * ROWS


static func cell_center(index: int) -> Vector2:
	var col := index % COLS
	var row := index / COLS
	return ORIGIN + Vector2(col * CELL_SIZE, row * CELL_SIZE)


## 座標落在哪一格。不在棋盤範圍內回傳 -1。
static func index_at_position(pos: Vector2) -> int:
	var local := pos - ORIGIN + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	var col := int(floor(local.x / CELL_SIZE))
	var row := int(floor(local.y / CELL_SIZE))
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return -1
	return row * COLS + col


func get_unit(index: int):
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


func is_empty(index: int) -> bool:
	return get_unit(index) == null


func first_empty_index() -> int:
	for i in _cells.size():
		if _cells[i] == null:
			return i
	return -1


func has_empty() -> bool:
	return first_empty_index() != -1


func place(index: int, kind: int, tier: int) -> void:
	_cells[index] = {"kind": kind, "tier": tier}


func clear_cell(index: int) -> void:
	_cells[index] = null


func clear_all() -> void:
	_cells.fill(null)


func occupied_indices() -> Array:
	var result := []
	for i in _cells.size():
		if _cells[i] != null:
			result.append(i)
	return result


## 處理一次拖放並回傳發生了什麼，讓 BoardView 知道該怎麼更新畫面。
## action 為 "none"（無效）、"move"（移到空格）、"swap"（交換）、
## "merge"（合成，另含新的 kind 與 tier）。
func resolve_drop(from_index: int, to_index: int, rng: RandomNumberGenerator) -> Dictionary:
	if from_index == to_index:
		return {"action": "none"}
	var source = get_unit(from_index)
	if source == null:
		return {"action": "none"}

	var target = get_unit(to_index)
	if target == null:
		_cells[to_index] = source
		_cells[from_index] = null
		return {"action": "move", "from": from_index, "to": to_index}

	if MergeRules.can_merge(source["tier"], target["tier"]):
		var merged := MergeRules.merge_result(source["tier"], rng)
		_cells[to_index] = {"kind": merged["kind"], "tier": merged["tier"]}
		_cells[from_index] = null
		return {
			"action": "merge", "from": from_index, "to": to_index,
			"kind": merged["kind"], "tier": merged["tier"],
		}

	_cells[from_index] = target
	_cells[to_index] = source
	return {"action": "swap", "from": from_index, "to": to_index}
```

- [ ] **Step 5: 執行測試確認全部通過**

```bash
tools/run_tests.sh
```

預期：`測試檔 4/4 載入`、`通過 37`、`全部通過`，結束碼 0。

- [ ] **Step 6: Commit**

```bash
git add scripts test
git commit -m "新增棋盤狀態與合成規則，亂數可注入以利測試"
```

---

### Task 5: 波次表與選敵（TDD）

**Files:**
- Create: `scripts/wave_table.gd`、`scripts/targeting.gd`
- Create: `test/unit/test_wave_table.gd`、`test/unit/test_targeting.gd`

**Interfaces:**
- Produces:
  - `WaveTable.EnemyKind`（列舉 `THIEF`、`RUNNER`、`BRUTE`、`BOSS`）
  - `WaveTable.hp_for(kind: int, wave: int) -> float`、`speed_for(kind: int) -> float`、`steal_for(kind: int) -> int`、`texture_path(kind: int) -> String`
  - `WaveTable.composition(wave: int) -> Array`（元素為 `EnemyKind`）
  - `Targeting.select(origin: Vector2, attack_range: float, candidates: Array)`（回傳選中的 Dictionary 或 null）

- [ ] **Step 1: 寫失敗的測試**

建立 `test/unit/test_wave_table.gd`：

```gdscript
extends GutTest

func test_first_wave_is_only_basic_thieves() -> void:
	var comp := WaveTable.composition(1)
	for kind in comp:
		assert_eq(kind, WaveTable.EnemyKind.THIEF, "第一波只該有基本小偷")

func test_runners_appear_from_wave_three() -> void:
	assert_false(WaveTable.composition(2).has(WaveTable.EnemyKind.RUNNER))
	assert_true(WaveTable.composition(3).has(WaveTable.EnemyKind.RUNNER))

func test_brutes_appear_from_wave_six() -> void:
	assert_false(WaveTable.composition(5).has(WaveTable.EnemyKind.BRUTE))
	assert_true(WaveTable.composition(6).has(WaveTable.EnemyKind.BRUTE))

func test_boss_appears_every_five_waves() -> void:
	assert_false(WaveTable.composition(4).has(WaveTable.EnemyKind.BOSS))
	assert_true(WaveTable.composition(5).has(WaveTable.EnemyKind.BOSS))
	assert_true(WaveTable.composition(10).has(WaveTable.EnemyKind.BOSS))

func test_only_one_boss_per_wave() -> void:
	var count := 0
	for kind in WaveTable.composition(10):
		if kind == WaveTable.EnemyKind.BOSS:
			count += 1
	assert_eq(count, 1)

func test_wave_size_grows_but_is_capped() -> void:
	assert_lt(WaveTable.composition(1).size(), WaveTable.composition(8).size())
	# 沒有上限的話後期一波會塞進上百隻，畫面與效能都會爆掉
	assert_lt(WaveTable.composition(99).size(), 40)

func test_hp_grows_with_wave() -> void:
	var w1 := WaveTable.hp_for(WaveTable.EnemyKind.THIEF, 1)
	var w2 := WaveTable.hp_for(WaveTable.EnemyKind.THIEF, 2)
	assert_almost_eq(w1, 30.0, 0.001)
	assert_almost_eq(w2 / w1, 1.28, 0.001)

func test_boss_steals_more_lives() -> void:
	assert_eq(WaveTable.steal_for(WaveTable.EnemyKind.THIEF), 1)
	assert_eq(WaveTable.steal_for(WaveTable.EnemyKind.BOSS), 3)

func test_runner_is_fastest() -> void:
	var runner := WaveTable.speed_for(WaveTable.EnemyKind.RUNNER)
	for kind in [WaveTable.EnemyKind.THIEF, WaveTable.EnemyKind.BRUTE, WaveTable.EnemyKind.BOSS]:
		assert_gt(runner, WaveTable.speed_for(kind))

func test_texture_paths_exist() -> void:
	for kind in [WaveTable.EnemyKind.THIEF, WaveTable.EnemyKind.RUNNER,
			WaveTable.EnemyKind.BRUTE, WaveTable.EnemyKind.BOSS]:
		var path := WaveTable.texture_path(kind)
		assert_true(ResourceLoader.exists(path), "找不到貼圖 %s" % path)
```

建立 `test/unit/test_targeting.gd`：

```gdscript
extends GutTest

func _candidate(id: int, pos: Vector2, progress: float) -> Dictionary:
	return {"id": id, "position": pos, "progress": progress}

func test_no_candidates_returns_null() -> void:
	assert_null(Targeting.select(Vector2.ZERO, 300.0, []))

func test_candidate_out_of_range_is_ignored() -> void:
	var far := [_candidate(1, Vector2(1000, 0), 0.5)]
	assert_null(Targeting.select(Vector2.ZERO, 300.0, far))

func test_picks_candidate_within_range() -> void:
	var list := [_candidate(7, Vector2(100, 0), 0.5)]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 7)

func test_prefers_the_one_closest_to_the_vault() -> void:
	# 選最接近終點的敵人，因為它最快造成傷害。若改選最近的，
	# 守衛會一直打剛進場的敵人而放走快到金庫的那隻。
	var list := [
		_candidate(1, Vector2(50, 0), 0.2),
		_candidate(2, Vector2(200, 0), 0.9),
		_candidate(3, Vector2(100, 0), 0.5),
	]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 2)

func test_out_of_range_leader_does_not_block_in_range_choice() -> void:
	var list := [
		_candidate(1, Vector2(5000, 0), 0.95),
		_candidate(2, Vector2(120, 0), 0.3),
	]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 2, "射程外的領先者不該擋住射程內的選擇")

func test_range_boundary_is_inclusive() -> void:
	var list := [_candidate(1, Vector2(300, 0), 0.5)]
	assert_not_null(Targeting.select(Vector2.ZERO, 300.0, list))
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
tools/run_tests.sh
```

預期：結束碼 1，`WaveTable` 與 `Targeting` 尚未宣告。

- [ ] **Step 3: 寫 WaveTable**

建立 `scripts/wave_table.gd`：

```gdscript
class_name WaveTable
extends RefCounted

## 每一波的敵人組成與數值。無限波次，難度靠生命值指數成長推進。

enum EnemyKind { THIEF, RUNNER, BRUTE, BOSS }

const HP_GROWTH := 1.28

## 單波敵人總數上限。沒有上限的話後期一波會塞進上百隻，
## 畫面看不清楚、效能也會被拖垮。
const MAX_THIEVES := 18
const MAX_RUNNERS := 8
const MAX_BRUTES := 6

const BASE := {
	EnemyKind.THIEF: {
		"hp": 30.0, "speed": 60.0, "steal": 1,
		"texture": "res://assets/enemies/thief.png",
	},
	EnemyKind.RUNNER: {
		"hp": 18.0, "speed": 110.0, "steal": 1,
		"texture": "res://assets/enemies/runner.png",
	},
	EnemyKind.BRUTE: {
		"hp": 90.0, "speed": 40.0, "steal": 1,
		"texture": "res://assets/enemies/brute.png",
	},
	EnemyKind.BOSS: {
		"hp": 400.0, "speed": 45.0, "steal": 3,
		"texture": "res://assets/enemies/boss.png",
	},
}


static func hp_for(kind: int, wave: int) -> float:
	return float(BASE[kind]["hp"]) * pow(HP_GROWTH, wave - 1)


static func speed_for(kind: int) -> float:
	return float(BASE[kind]["speed"])


static func steal_for(kind: int) -> int:
	return int(BASE[kind]["steal"])


static func texture_path(kind: int) -> String:
	return String(BASE[kind]["texture"])


## 這一波要出的敵人清單，依序生成。
static func composition(wave: int) -> Array:
	var result := []
	for i in mini(3 + wave, MAX_THIEVES):
		result.append(EnemyKind.THIEF)
	if wave >= 3:
		for i in mini(wave / 2, MAX_RUNNERS):
			result.append(EnemyKind.RUNNER)
	if wave >= 6:
		for i in mini(wave / 3, MAX_BRUTES):
			result.append(EnemyKind.BRUTE)
	if wave % 5 == 0:
		result.append(EnemyKind.BOSS)
	return result
```

- [ ] **Step 4: 寫 Targeting**

建立 `scripts/targeting.gd`：

```gdscript
class_name Targeting
extends RefCounted

## 選敵規則。抽成純函式的好處是可以直接餵假資料測試，
## 不必在場景裡擺出各種敵人位置的組合。


## 從候選中挑出射程內、沿軌道走得最遠（最接近金庫）的敵人。
## candidates 每個元素需含 "position": Vector2 與 "progress": float。
## 沒有合適目標時回傳 null。
static func select(origin: Vector2, attack_range: float, candidates: Array):
	var best = null
	var best_progress := -1.0
	for candidate in candidates:
		var position: Vector2 = candidate["position"]
		if origin.distance_to(position) > attack_range:
			continue
		var progress: float = candidate["progress"]
		if progress > best_progress:
			best_progress = progress
			best = candidate
	return best
```

- [ ] **Step 5: 執行測試確認全部通過**

```bash
tools/run_tests.sh
```

預期：`測試檔 6/6 載入`、`通過 53`、`全部通過`，結束碼 0。

- [ ] **Step 6: Commit**

```bash
git add scripts test
git commit -m "新增波次組成表與選敵規則，含單元測試"
```

---

### Task 6: 棋盤畫面與召喚

第一個看得到、按得動的東西。結束時可以按召喚鈕在格子上生成守衛。

**Files:**
- Create: `scenes/unit_view.gd`、`scenes/unit_view.tscn`
- Create: `scenes/board_view.gd`、`scenes/board_view.tscn`
- Create: `scenes/hud.gd`、`scenes/hud.tscn`
- Create: `scenes/main.gd`、`scenes/main.tscn`

**Interfaces:**
- Consumes: `Board`、`Economy`、`UnitStats`（Task 3、4）
- Produces:
  - `UnitView.setup(kind: int, tier: int) -> void`、`UnitView.set_tier(tier: int) -> void`
  - `BoardView.add_unit(index: int, kind: int, tier: int)`、`remove_unit(index: int)`、`move_unit(from_index: int, to_index: int)`、`clear_all()`
  - `HUD` 訊號 `start_game`、`summon_requested`
  - `HUD.show_title(best_wave: int)`、`hide_title()`、`update_stats(wave: int, lives: int, gold: int)`、`update_summon_button(cost: int, affordable: bool)`、`show_message(text: String)`、`hide_message()`

- [ ] **Step 1: 寫 UnitView 腳本**

建立 `scenes/unit_view.gd`：

```gdscript
extends Node2D

## 一隻守衛的外觀。攻擊邏輯在 Task 9 才加進來。

## 各階級的外圈顏色，用來一眼分辨強弱
const TIER_COLORS := [
	Color(0.62, 0.66, 0.72),
	Color(0.40, 0.74, 0.52),
	Color(0.30, 0.62, 0.88),
	Color(0.62, 0.44, 0.88),
	Color(0.94, 0.62, 0.24),
	Color(0.92, 0.28, 0.34),
	Color(1.00, 0.84, 0.20),
]
const BASE_SPRITE_SCALE := 0.34
const SCALE_PER_TIER := 0.03
const RING_RADIUS := 56.0

var kind: int = UnitStats.Kind.BULL
var tier: int = 1

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tier_label: Label = $TierLabel


func setup(p_kind: int, p_tier: int) -> void:
	kind = p_kind
	_sprite.texture = load(UnitStats.texture_path(kind))
	set_tier(p_tier)


func set_tier(p_tier: int) -> void:
	tier = p_tier
	var factor := BASE_SPRITE_SCALE + SCALE_PER_TIER * (tier - 1)
	_sprite.scale = Vector2(factor, factor)
	_tier_label.text = str(tier)
	queue_redraw()


func _draw() -> void:
	# 外圈同時是階級指示與格子佔位提示
	draw_circle(Vector2.ZERO, RING_RADIUS, Color(1, 1, 1, 0.35))
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48,
		TIER_COLORS[tier - 1], 6.0, true)
```

- [ ] **Step 2: 寫 UnitView 場景**

建立 `scenes/unit_view.tscn`：

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/unit_view.gd" id="1"]
[ext_resource type="Theme" path="res://assets/theme.tres" id="2"]

[node name="UnitView" type="Node2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(0.34, 0.34)

[node name="TierLabel" type="Label" parent="."]
theme = ExtResource("2")
offset_left = 20.0
offset_top = 16.0
offset_right = 70.0
offset_bottom = 62.0
theme_override_font_sizes/font_size = 32
horizontal_alignment = 1
vertical_alignment = 1
text = "1"
```

- [ ] **Step 3: 寫 BoardView 腳本**

建立 `scenes/board_view.gd`。這一版只負責畫格子與擺放守衛，拖曳在 Task 7 加入：

```gdscript
extends Node2D

## 棋盤的畫面呈現。棋盤狀態的真相在 Board（純資料），這裡只負責顯示。

const UNIT_SCENE := preload("res://scenes/unit_view.tscn")
const CELL_INSET := 8.0
const CELL_COLOR := Color(1, 1, 1, 0.18)
const CELL_BORDER := Color(0.42, 0.38, 0.34, 0.5)

## index -> UnitView
var _views: Dictionary = {}


func _draw() -> void:
	var size := Board.CELL_SIZE - CELL_INSET * 2.0
	for i in Board.cell_count():
		var center := Board.cell_center(i)
		var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
		draw_rect(rect, CELL_COLOR, true)
		draw_rect(rect, CELL_BORDER, false, 3.0)


func add_unit(index: int, kind: int, tier: int) -> void:
	var view := UNIT_SCENE.instantiate()
	add_child(view)
	view.setup(kind, tier)
	view.position = Board.cell_center(index)
	_views[index] = view


func remove_unit(index: int) -> void:
	if not _views.has(index):
		return
	_views[index].queue_free()
	_views.erase(index)


func move_unit(from_index: int, to_index: int) -> void:
	if not _views.has(from_index):
		return
	var view = _views[from_index]
	_views.erase(from_index)
	_views[to_index] = view
	view.position = Board.cell_center(to_index)


func get_view(index: int):
	return _views.get(index)


func clear_all() -> void:
	for index in _views.keys():
		_views[index].queue_free()
	_views.clear()
```

- [ ] **Step 4: 寫 BoardView 場景**

建立 `scenes/board_view.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/board_view.gd" id="1"]

[node name="BoardView" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 5: 寫 HUD 腳本**

建立 `scenes/hud.gd`：

```gdscript
extends CanvasLayer

## 畫面上的文字與按鈕。放在 CanvasLayer 底下才不會跟著遊戲場景縮放。

signal start_game
signal summon_requested

const RESTART_DELAY := 1.0

@onready var _stats_label: Label = $StatsLabel
@onready var _message: Label = $Message
@onready var _best_label: Label = $BestLabel
@onready var _start_button: Button = $StartButton
@onready var _summon_button: Button = $SummonButton


func _ready() -> void:
	_start_button.pressed.connect(func(): start_game.emit())
	_summon_button.pressed.connect(func(): summon_requested.emit())


func show_title(best_wave: int) -> void:
	_message.text = "口袋守衛戰"
	_message.show()
	_best_label.text = "最高波次 %d" % best_wave
	_best_label.show()
	_start_button.text = "開始"
	_start_button.show()
	_stats_label.hide()
	_summon_button.hide()


func hide_title() -> void:
	_message.hide()
	_best_label.hide()
	_start_button.hide()
	_stats_label.show()
	_summon_button.show()


func update_stats(wave: int, lives: int, gold: int) -> void:
	_stats_label.text = "波次 %d　　生命 %d　　金幣 %d" % [wave, lives, gold]


func update_summon_button(cost: int, affordable: bool) -> void:
	_summon_button.text = "召喚 · %d 金幣" % cost
	_summon_button.disabled = not affordable


func show_message(text: String) -> void:
	_message.text = text
	_message.show()


func hide_message() -> void:
	_message.hide()


func show_game_over(wave: int, best_wave: int, is_record: bool) -> void:
	if is_record:
		_message.text = "新紀錄！\n撐到第 %d 波" % wave
	else:
		_message.text = "金庫失守\n撐到第 %d 波" % wave
	_message.show()
	_best_label.text = "最高波次 %d" % best_wave
	_best_label.show()
	_stats_label.hide()
	_summon_button.hide()
	# 等一秒再顯示按鈕，避免玩家手還在點就誤觸重來
	await get_tree().create_timer(RESTART_DELAY).timeout
	_start_button.text = "再玩一次"
	_start_button.show()
```

- [ ] **Step 6: 寫 HUD 場景**

建立 `scenes/hud.tscn`：

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/hud.gd" id="1"]
[ext_resource type="Theme" path="res://assets/theme.tres" id="2"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="StatsLabel" type="Label" parent="."]
theme = ExtResource("2")
offset_top = 60.0
offset_right = 720.0
offset_bottom = 130.0
theme_override_font_sizes/font_size = 34
horizontal_alignment = 1
text = "波次 1　　生命 20　　金幣 60"

[node name="Message" type="Label" parent="."]
theme = ExtResource("2")
offset_top = 480.0
offset_right = 720.0
offset_bottom = 720.0
theme_override_font_sizes/font_size = 64
horizontal_alignment = 1
vertical_alignment = 1
text = "口袋守衛戰"

[node name="BestLabel" type="Label" parent="."]
theme = ExtResource("2")
offset_top = 740.0
offset_right = 720.0
offset_bottom = 800.0
horizontal_alignment = 1
text = "最高波次 0"

[node name="StartButton" type="Button" parent="."]
theme = ExtResource("2")
offset_left = 240.0
offset_top = 860.0
offset_right = 480.0
offset_bottom = 950.0
text = "開始"

[node name="SummonButton" type="Button" parent="."]
theme = ExtResource("2")
offset_left = 180.0
offset_top = 1080.0
offset_right = 540.0
offset_bottom = 1180.0
theme_override_font_sizes/font_size = 36
text = "召喚 · 20 金幣"
```

- [ ] **Step 7: 寫 Main 腳本**

建立 `scenes/main.gd`。這一版只做召喚，波次與敵人在後續任務加入：

```gdscript
extends Node2D

## 遊戲流程總控。所有狀態改變都經過這裡，其他節點只發訊號請求。

var _board := Board.new()
var _economy := Economy.new()
var _rng := RandomNumberGenerator.new()

@onready var _board_view: Node2D = $BoardView
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	_rng.randomize()
	_hud.start_game.connect(new_game)
	_hud.summon_requested.connect(_on_summon_requested)
	_hud.show_title(0)


func new_game() -> void:
	_board.clear_all()
	_board_view.clear_all()
	_economy.reset()
	_hud.hide_title()
	_refresh_hud()


func _refresh_hud() -> void:
	_hud.update_stats(1, _economy.lives, _economy.gold)
	_hud.update_summon_button(_economy.summon_cost(), _economy.can_afford_summon())


func _on_summon_requested() -> void:
	if not _economy.can_afford_summon():
		return
	var index := _board.first_empty_index()
	if index == -1:
		_hud.show_message("沒有空格了")
		return
	_economy.pay_summon()
	# 一階守衛的種類也是隨機的，和合成一樣用可注入的 rng
	var kind := _rng.randi_range(UnitStats.Kind.BULL, UnitStats.Kind.DINO)
	_board.place(index, kind, 1)
	_board_view.add_unit(index, kind, 1)
	_refresh_hud()
```

- [ ] **Step 8: 寫 Main 場景**

建立 `scenes/main.tscn`。背景 `ColorRect` 的 `mouse_filter = 2`（IGNORE）是必要的——`Control` 預設為 `STOP`，鋪滿畫面的背景會吃掉所有滑鼠事件，導致 Task 7 的拖曳完全收不到：

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/board_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/hud.tscn" id="3"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
offset_right = 720.0
offset_bottom = 1280.0
mouse_filter = 2
color = Color(1, 0.965, 0.912, 1)

[node name="BoardView" parent="." instance=ExtResource("2")]

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 9: 匯入、語法檢查與擷圖**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import > /dev/null 2>&1
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	$GODOT --headless --path . --check-only -s "$f" > /dev/null 2>&1 || echo "語法錯誤: $f"
done
echo "語法檢查完成"
$GODOT --path . tools/capture.tscn -- /tmp/board.png 90
```

預期：無語法錯誤，`/tmp/board.png` 產出。用 Read 開啟確認標題畫面顯示「口袋守衛戰」且中文正常。

- [ ] **Step 10: 實際按按鈕確認召喚**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

逐項確認：標題畫面出現 → 按「開始」進入遊戲 → 看得到 4×3 的格子 → 按「召喚」在左上角出現一隻守衛且金幣減少 → 連按數次，守衛依序填入格子、召喚費用逐次增加 → 金幣不足時召喚鈕變成停用。確認後關閉視窗。

- [ ] **Step 11: 執行單元測試**

```bash
tools/run_tests.sh
```

預期：`通過 53`、`全部通過`。

- [ ] **Step 12: Commit**

```bash
git add scenes
git commit -m "新增棋盤畫面、HUD 與召喚流程"
```

---

### Task 7: 拖曳、移動、交換與合成

**Files:**
- Modify: `scenes/board_view.gd`（加入拖曳處理）
- Modify: `scenes/main.gd`（處理拖放結果）

**Interfaces:**
- Consumes: `Board.resolve_drop()`、`Board.index_at_position()`（Task 4）
- Produces: `BoardView` 訊號 `unit_dropped(from_index: int, to_index: int)`；`BoardView.set_unit_tier(index: int, tier: int)`

- [ ] **Step 1: 在 BoardView 加入拖曳**

修改 `scenes/board_view.gd`，在檔案開頭的常數之前加入訊號：

```gdscript
## 玩家把某格的守衛拖放到另一格時發出，由 Main 決定實際結果。
signal unit_dropped(from_index: int, to_index: int)
```

在 `_views` 宣告下方加入拖曳狀態：

```gdscript
var _drag_index := -1
var _drag_origin := Vector2.ZERO
```

在檔案末尾加入拖曳處理：

```gdscript
## 用 _unhandled_input 而不是 _input：點到 HUD 按鈕時事件已被 UI 吃掉，
## 不會同時觸發棋盤拖曳。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion:
		# 只在左鍵確實按著時才跟隨。收到「沒按鍵的移動」代表放開的事件
		# 遺失了（例如玩家把滑鼠拖出視窗外才放開），這時要收掉拖曳，
		# 否則守衛會一直黏在游標上。
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_drag(event.position)
		elif _drag_index != -1:
			_cancel_drag()


func _begin_drag(pos: Vector2) -> void:
	var index := Board.index_at_position(pos)
	if index == -1 or not _views.has(index):
		return
	_drag_index = index
	_drag_origin = _views[index].position
	_views[index].z_index = 10


func _update_drag(pos: Vector2) -> void:
	if _drag_index == -1:
		return
	_views[_drag_index].position = pos


func _end_drag(pos: Vector2) -> void:
	if _drag_index == -1:
		return
	var from_index := _drag_index
	var to_index := Board.index_at_position(pos)
	_reset_drag_visual()
	if to_index == -1:
		return
	unit_dropped.emit(from_index, to_index)


func _cancel_drag() -> void:
	_reset_drag_visual()


func _reset_drag_visual() -> void:
	if _drag_index == -1:
		return
	if _views.has(_drag_index):
		_views[_drag_index].position = _drag_origin
		_views[_drag_index].z_index = 0
	_drag_index = -1
```

同時在檔案末尾加入更新階級的方法：

```gdscript
func set_unit_tier(index: int, tier: int) -> void:
	if _views.has(index):
		_views[index].set_tier(tier)
```

- [ ] **Step 2: 在 Main 處理拖放結果**

修改 `scenes/main.gd`，在 `_ready()` 的訊號連接區加入一行：

```gdscript
	_board_view.unit_dropped.connect(_on_unit_dropped)
```

在檔案末尾加入處理函式：

```gdscript
func _on_unit_dropped(from_index: int, to_index: int) -> void:
	var result := _board.resolve_drop(from_index, to_index, _rng)
	match result["action"]:
		"move":
			_board_view.move_unit(from_index, to_index)
		"swap":
			# 兩個畫面物件要一起搬，不能只呼叫兩次 move_unit，
			# 否則第一次搬完後第二次會找不到來源。
			_board_view.swap_units(from_index, to_index)
		"merge":
			_board_view.remove_unit(from_index)
			_board_view.remove_unit(to_index)
			_board_view.add_unit(to_index, result["kind"], result["tier"])
		_:
			pass
```

- [ ] **Step 3: 在 BoardView 加入 swap_units**

在 `scenes/board_view.gd` 的 `move_unit` 下方加入：

```gdscript
func swap_units(index_a: int, index_b: int) -> void:
	var view_a = _views.get(index_a)
	var view_b = _views.get(index_b)
	if view_a == null or view_b == null:
		return
	_views[index_a] = view_b
	_views[index_b] = view_a
	view_a.position = Board.cell_center(index_b)
	view_b.position = Board.cell_center(index_a)
```

- [ ] **Step 4: 語法檢查與冒煙測試**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import > /dev/null 2>&1
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	$GODOT --headless --path . --check-only -s "$f" > /dev/null 2>&1 || echo "語法錯誤: $f"
done
echo "語法檢查完成"
$GODOT --headless --path . --quit-after 200 > /tmp/smoke.log 2>&1
grep -iE "SCRIPT ERROR|Parse Error" /tmp/smoke.log && echo "^^ 發現錯誤" || echo "冒煙測試通過"
```

預期：無語法錯誤、印出「冒煙測試通過」。

- [ ] **Step 5: 實際拖曳確認三種結果**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

逐項確認：召喚數隻守衛 → 把一隻拖到空格，它移動過去 → 把一階拖到另一隻一階上，兩者消失並在目標格出現二階守衛（數字變 2、外圈換色） → 把一階拖到二階上，兩者交換位置 → 拖到棋盤外放開，守衛回到原位。

- [ ] **Step 6: 執行單元測試**

```bash
tools/run_tests.sh
```

預期：`通過 53`、`全部通過`。

- [ ] **Step 7: Commit**

```bash
git add scenes
git commit -m "新增守衛拖曳，支援移動、交換與合成"
```

---

### Task 8: 軌道與敵人

**Files:**
- Create: `scenes/enemy.gd`、`scenes/enemy.tscn`
- Modify: `scenes/main.gd`、`scenes/main.tscn`

**Interfaces:**
- Consumes: `WaveTable`、`Economy.kill_reward()`（Task 3、5）
- Produces: `Enemy.setup(kind: int, wave: int) -> void`、`Enemy.take_damage(amount: float) -> void`、`Enemy.progress_ratio`；訊號 `died(reward: int)`、`reached_vault(steal: int)`；Enemy 加入群組 `enemy`

- [ ] **Step 1: 寫 Enemy 腳本**

建立 `scenes/enemy.gd`：

```gdscript
extends PathFollow2D

## 一隻小偷。以 PathFollow2D 沿軌道前進，這是 Godot 處理「沿路徑移動」
## 的標準做法，位置計算完全交給引擎。

signal died(reward: int)
signal reached_vault(steal: int)

## 保險用的存活上限。萬一軌道設定出錯導致敵人卡住，
## 沒有這道保險它會永遠留在場上。
const MAX_LIFETIME := 120.0

var _hp := 0.0
var _speed := 0.0
var _steal := 1
var _reward := 0
var _finished := false
var _lifetime := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	loop = false
	rotates = false
	add_to_group("enemy")


func setup(kind: int, wave: int) -> void:
	_hp = WaveTable.hp_for(kind, wave)
	_speed = WaveTable.speed_for(kind)
	_steal = WaveTable.steal_for(kind)
	_reward = Economy.kill_reward(wave)
	# setup 可能在 _ready 之前被呼叫，所以直接取節點而非用 @onready
	get_node("Sprite2D").texture = load(WaveTable.texture_path(kind))


func _physics_process(delta: float) -> void:
	if _finished:
		return
	progress += _speed * delta
	_lifetime += delta
	if progress_ratio >= 1.0:
		_finish()
		reached_vault.emit(_steal)
	elif _lifetime > MAX_LIFETIME:
		_finish()


func take_damage(amount: float) -> void:
	if _finished:
		return
	_hp -= amount
	if _hp <= 0.0:
		_finish()
		died.emit(_reward)


func _finish() -> void:
	_finished = true
	remove_from_group("enemy")
	queue_free()
```

- [ ] **Step 2: 寫 Enemy 場景**

建立 `scenes/enemy.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/enemy.gd" id="1"]

[node name="Enemy" type="PathFollow2D"]
rotates = false
loop = false
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
```

- [ ] **Step 3: 在主場景加入軌道與金庫**

修改 `scenes/main.tscn`：把 `load_steps` 由 4 改為 6，於 ext_resource 區加入

```
[ext_resource type="Texture2D" path="res://assets/vault.png" id="4"]
```

在 ext_resource 區之後加入軌道曲線。四個點依序為起點 `(60,300)`、`(60,900)`、`(660,900)`、終點 `(660,300)`，每個點含 in／out／position 三組座標：

```
[sub_resource type="Curve2D" id="Curve2D_1"]
_data = {
"points": PackedVector2Array(0, 0, 0, 0, 60, 300, 0, 0, 0, 0, 60, 900, 0, 0, 0, 0, 660, 900, 0, 0, 0, 0, 660, 300)
}
point_count = 4
```

在 `BoardView` 節點之前插入軌道與金庫（先加入這兩個節點，讓 BoardView 與 HUD 畫在敵人之上）：

```
[node name="Track" type="Path2D" parent="."]
curve = SubResource("Curve2D_1")

[node name="Enemies" type="Node2D" parent="."]

[node name="Vault" type="Sprite2D" parent="."]
position = Vector2(660, 300)
texture = ExtResource("4")
```

- [ ] **Step 4: 在 Main 加入敵人生成**

修改 `scenes/main.gd`。常數區加入：

```gdscript
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
```

`@onready` 區加入：

```gdscript
@onready var _track: Path2D = $Track
```

檔案末尾加入生成函式與訊號處理：

```gdscript
## 敵人必須是 Path2D 的子節點，PathFollow2D 才知道要沿哪條線走。
func _spawn_enemy(kind: int, wave: int) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	_track.add_child(enemy)
	enemy.setup(kind, wave)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_vault.connect(_on_enemy_reached_vault)


func _on_enemy_died(reward: int) -> void:
	_economy.add_gold(reward)
	_refresh_hud()


func _on_enemy_reached_vault(steal: int) -> void:
	_economy.lose_lives(steal)
	_refresh_hud()
```

暫時在 `new_game()` 末尾加入一行，先確認敵人會走：

```gdscript
	_spawn_enemy(WaveTable.EnemyKind.THIEF, 1)
```

- [ ] **Step 5: 語法檢查與擷圖確認敵人在走**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import > /dev/null 2>&1
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	$GODOT --headless --path . --check-only -s "$f" > /dev/null 2>&1 || echo "語法錯誤: $f"
done
echo "語法檢查完成"
```

預期：無語法錯誤。

- [ ] **Step 6: 實際觀察敵人沿軌道前進**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

逐項確認：按開始後，一隻小偷從左上出現 → 沿左側往下、底部往右、右側往上前進 → 抵達右上的金庫時消失且生命由 20 變 19。若小偷方向相反或走錯路，檢查 `Curve2D` 四個點的順序。

- [ ] **Step 7: 移除暫時的測試生成並 commit**

把 Step 4 加在 `new_game()` 末尾的那一行 `_spawn_enemy(...)` 刪除——正式的波次生成在 Task 10 加入。

```bash
git add scenes
git commit -m "新增軌道、金庫與沿路徑前進的敵人"
```

---

### Task 9: 守衛攻擊與投射物

**Files:**
- Create: `scenes/projectile.gd`、`scenes/projectile.tscn`
- Modify: `scenes/unit_view.gd`（加入索敵與開火）
- Modify: `scenes/main.gd`、`scenes/main.tscn`

**Interfaces:**
- Consumes: `Targeting.select()`、`UnitStats`（Task 3、5）；`Enemy.take_damage()`、`Enemy.progress_ratio`（Task 8）
- Produces: `UnitView` 訊號 `fired(origin: Vector2, target: Node2D, damage: float, splash: float)`；`Projectile.setup(target: Node2D, damage: float, splash: float)`

- [ ] **Step 1: 寫 Projectile 腳本**

建立 `scenes/projectile.gd`：

```gdscript
extends Node2D

## 飛向目標的投射物。命中時結算傷害，範圍攻擊另外波及附近敵人。

const SPEED := 780.0
## 目標若在飛行途中死亡或卡住，這道上限確保投射物不會永遠留在場上
const MAX_LIFETIME := 3.0
const RADIUS := 9.0

var _target: Node2D = null
var _damage := 0.0
var _splash := 0.0
var _color := Color(0.98, 0.78, 0.20)
var _lifetime := 0.0


func setup(target: Node2D, damage: float, splash: float, color: Color) -> void:
	_target = target
	_damage = damage
	_splash = splash
	_color = color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(0.12, 0.12, 0.14), 2.0, true)


func _physics_process(delta: float) -> void:
	_lifetime += delta
	# 目標可能在投射物飛行途中就被別的守衛打死，命中前一定要重新檢查
	if _lifetime > MAX_LIFETIME or not is_instance_valid(_target):
		queue_free()
		return
	var to_target := _target.global_position - global_position
	var step := SPEED * delta
	if to_target.length() <= step:
		_hit()
		return
	global_position += to_target.normalized() * step


func _hit() -> void:
	if is_instance_valid(_target):
		_target.take_damage(_damage)
		if _splash > 0.0:
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy == _target or not is_instance_valid(enemy):
					continue
				if enemy.global_position.distance_to(global_position) <= _splash:
					enemy.take_damage(_damage)
	queue_free()
```

- [ ] **Step 2: 寫 Projectile 場景**

建立 `scenes/projectile.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/projectile.gd" id="1"]

[node name="Projectile" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: 在 UnitView 加入索敵與開火**

修改 `scenes/unit_view.gd`。在常數區之前加入訊號：

```gdscript
## 開火時發出，由 Main 負責生成投射物——投射物集中管理才好清場。
signal fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color)
```

在 `var tier` 下方加入冷卻計時與啟用旗標：

```gdscript
var _cooldown := 0.0
var _active := false
```

在 `set_tier` 下方加入：

```gdscript
## 只有在波次進行中才需要索敵，開場與結束畫面關掉以省效能。
func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_cooldown = UnitStats.attack_interval(kind)
	fired.emit(
		global_position, target,
		UnitStats.damage(kind, tier),
		UnitStats.splash_radius(kind),
		TIER_COLORS[tier - 1]
	)


func _find_target() -> Node2D:
	var candidates := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		candidates.append({
			"node": enemy,
			"position": enemy.global_position,
			"progress": enemy.progress_ratio,
		})
	var chosen = Targeting.select(global_position,
		UnitStats.attack_range(kind, tier), candidates)
	if chosen == null:
		return null
	return chosen["node"]
```

並在 `_ready` 之前加入預設關閉處理（`UnitView` 目前沒有 `_ready`，新增一個）：

```gdscript
func _ready() -> void:
	set_physics_process(false)
```

- [ ] **Step 4: 在 BoardView 轉發開火訊號**

修改 `scenes/board_view.gd`。在檔案開頭的訊號宣告下方加入：

```gdscript
## 把底下所有守衛的開火事件轉給 Main
signal unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color)
```

在 `add_unit` 的 `_views[index] = view` 之前加入一行，把新守衛的訊號接起來：

```gdscript
	view.fired.connect(func(origin, target, damage, splash, color):
		unit_fired.emit(origin, target, damage, splash, color))
	view.set_active(_units_active)
```

在 `_views` 宣告下方加入狀態變數與批次開關：

```gdscript
var _units_active := false
```

在檔案末尾加入：

```gdscript
## 波次進行中才讓守衛索敵。開場與結束畫面關掉。
func set_units_active(value: bool) -> void:
	_units_active = value
	for index in _views:
		_views[index].set_active(value)
```

- [ ] **Step 5: 在 Main 生成投射物**

修改 `scenes/main.gd`。常數區加入：

```gdscript
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
```

`@onready` 區加入：

```gdscript
@onready var _projectiles: Node2D = $Projectiles
```

`_ready()` 的訊號連接區加入：

```gdscript
	_board_view.unit_fired.connect(_on_unit_fired)
```

檔案末尾加入：

```gdscript
func _on_unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	_projectiles.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(target, damage, splash, color)
```

- [ ] **Step 6: 在主場景加入投射物容器**

修改 `scenes/main.tscn`，在 `Enemies` 節點之後加入：

```
[node name="Projectiles" type="Node2D" parent="."]
```

- [ ] **Step 7: 加入暫時的測試生成以便觀察**

在 `scenes/main.gd` 的 `new_game()` 末尾暫時加入兩行：

```gdscript
	_board_view.set_units_active(true)
	_spawn_enemy(WaveTable.EnemyKind.BRUTE, 1)
```

- [ ] **Step 8: 語法檢查**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import > /dev/null 2>&1
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	$GODOT --headless --path . --check-only -s "$f" > /dev/null 2>&1 || echo "語法錯誤: $f"
done
echo "語法檢查完成"
```

預期：無語法錯誤。

- [ ] **Step 9: 實際觀察守衛開火**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

逐項確認：按開始後召喚幾隻守衛 → 壯漢小偷沿軌道前進時，射程內的守衛射出彩色投射物 → 投射物飛向小偷並命中 → 小偷血量耗盡後消失且金幣增加 → 投射物在目標消失後不會殘留。

- [ ] **Step 10: 移除暫時的測試生成，執行測試並 commit**

把 Step 7 加入的兩行從 `new_game()` 末尾刪除。

```bash
tools/run_tests.sh
git add scenes
git commit -m "新增守衛索敵、開火與投射物"
```

預期測試：`通過 53`、`全部通過`。

---

### Task 10: 波次流程、生命與完整循環

**Files:**
- Modify: `scenes/main.gd`（波次狀態機、存檔）
- Modify: `scenes/main.tscn`（三個計時器）

**Interfaces:**
- Consumes: 前述所有介面
- Produces: 完整可玩循環；最高波次存於 `user://best_wave.save`

- [ ] **Step 1: 在主場景加入計時器**

修改 `scenes/main.tscn`，在 `Projectiles` 節點之後加入：

```
[node name="SpawnTimer" type="Timer" parent="."]
wait_time = 0.8

[node name="BreakTimer" type="Timer" parent="."]
wait_time = 3.0
one_shot = true
```

- [ ] **Step 2: 改寫 Main 加入波次流程**

`scenes/main.gd` 整份換成：

```gdscript
extends Node2D

## 遊戲流程總控。所有狀態改變都經過這裡，其他節點只發訊號請求。

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

const SAVE_PATH := "user://best_wave.save"
const FIRST_WAVE_DELAY := 3.0

var _board := Board.new()
var _economy := Economy.new()
var _rng := RandomNumberGenerator.new()

var _wave := 0
var _best_wave := 0
var _running := false
## 這一波還沒生成的敵人，依序取出
var _pending: Array = []
## 已生成且還活著的敵人數
var _alive := 0

@onready var _board_view: Node2D = $BoardView
@onready var _hud: CanvasLayer = $HUD
@onready var _track: Path2D = $Track
@onready var _projectiles: Node2D = $Projectiles
@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _break_timer: Timer = $BreakTimer


func _ready() -> void:
	_rng.randomize()
	_load_best_wave()
	_hud.start_game.connect(new_game)
	_hud.summon_requested.connect(_on_summon_requested)
	_board_view.unit_dropped.connect(_on_unit_dropped)
	_board_view.unit_fired.connect(_on_unit_fired)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_break_timer.timeout.connect(_start_next_wave)
	_hud.show_title(_best_wave)


func new_game() -> void:
	_clear_field()
	_board.clear_all()
	_board_view.clear_all()
	_economy.reset()
	_wave = 0
	_pending.clear()
	_alive = 0
	_running = true
	_board_view.set_units_active(true)
	_hud.hide_title()
	_refresh_hud()
	_hud.show_message("準備防守")
	_break_timer.start(FIRST_WAVE_DELAY)


## 清空場上敵人與投射物。結束與重來都要用，否則上一局的東西會殘留。
func _clear_field() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	for projectile in _projectiles.get_children():
		projectile.queue_free()


func _refresh_hud() -> void:
	_hud.update_stats(maxi(_wave, 1), _economy.lives, _economy.gold)
	_hud.update_summon_button(_economy.summon_cost(), _economy.can_afford_summon())


# --- 波次流程 ---

func _start_next_wave() -> void:
	if not _running:
		return
	_wave += 1
	_pending = WaveTable.composition(_wave)
	_alive = 0
	_hud.hide_message()
	_refresh_hud()
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	if _pending.is_empty():
		_spawn_timer.stop()
		return
	_spawn_enemy(_pending.pop_front(), _wave)


## 敵人必須是 Path2D 的子節點，PathFollow2D 才知道要沿哪條線走。
func _spawn_enemy(kind: int, wave: int) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	_track.add_child(enemy)
	enemy.setup(kind, wave)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_vault.connect(_on_enemy_reached_vault)
	_alive += 1


func _on_enemy_died(reward: int) -> void:
	_economy.add_gold(reward)
	_alive -= 1
	_refresh_hud()
	_check_wave_cleared()


func _on_enemy_reached_vault(steal: int) -> void:
	_economy.lose_lives(steal)
	_alive -= 1
	_refresh_hud()
	if _economy.is_defeated():
		_game_over()
		return
	_check_wave_cleared()


func _check_wave_cleared() -> void:
	if not _running or _alive > 0 or not _pending.is_empty():
		return
	_economy.add_gold(Economy.wave_reward(_wave))
	_refresh_hud()
	_hud.show_message("第 %d 波守住了" % _wave)
	_break_timer.start()


func _game_over() -> void:
	_running = false
	_spawn_timer.stop()
	_break_timer.stop()
	_board_view.set_units_active(false)
	_clear_field()
	var is_record := _wave > _best_wave
	if is_record:
		_best_wave = _wave
		_save_best_wave()
	_hud.show_game_over(_wave, _best_wave, is_record)


# --- 玩家操作 ---

func _on_summon_requested() -> void:
	if not _running or not _economy.can_afford_summon():
		return
	var index := _board.first_empty_index()
	if index == -1:
		_hud.show_message("沒有空格了，先合成吧")
		return
	_economy.pay_summon()
	# 一階守衛的種類也是隨機的，和合成一樣用可注入的 rng
	var kind := _rng.randi_range(UnitStats.Kind.BULL, UnitStats.Kind.DINO)
	_board.place(index, kind, 1)
	_board_view.add_unit(index, kind, 1)
	_refresh_hud()


func _on_unit_dropped(from_index: int, to_index: int) -> void:
	var result := _board.resolve_drop(from_index, to_index, _rng)
	match result["action"]:
		"move":
			_board_view.move_unit(from_index, to_index)
		"swap":
			# 兩個畫面物件要一起搬，不能只呼叫兩次 move_unit，
			# 否則第一次搬完後第二次會找不到來源。
			_board_view.swap_units(from_index, to_index)
		"merge":
			_board_view.remove_unit(from_index)
			_board_view.remove_unit(to_index)
			_board_view.add_unit(to_index, result["kind"], result["tier"])
		_:
			pass


func _on_unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	_projectiles.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(target, damage, splash, color)


# --- 存檔 ---

func _save_best_wave() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		# 存檔失敗不該讓遊戲中斷，記一筆就好
		push_warning("無法寫入最高波次：%s" % error_string(FileAccess.get_open_error()))
		return
	file.store_32(_best_wave)
	file.close()


## 讀取失敗（第一次玩、檔案損毀）時退回 0，不拋錯。
func _load_best_wave() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_best_wave = 0
		return
	_best_wave = file.get_32()
	file.close()
```

- [ ] **Step 3: 語法檢查與冒煙測試**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import > /dev/null 2>&1
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	$GODOT --headless --path . --check-only -s "$f" > /dev/null 2>&1 || echo "語法錯誤: $f"
done
echo "語法檢查完成"
$GODOT --headless --path . --quit-after 300 > /tmp/smoke.log 2>&1
grep -iE "SCRIPT ERROR|Parse Error" /tmp/smoke.log && echo "^^ 發現錯誤" || echo "冒煙測試通過"
```

預期：無語法錯誤、印出「冒煙測試通過」。

- [ ] **Step 4: 寫整合測試**

建立 `tools/integration_check.gd`：

```gdscript
extends Node

## 整合測試：把整個遊戲場景跑起來，驗證單元測試碰不到的場景樹行為
## ——輸入路由、訊號串接、拖曳合成、波次流程、存檔。
##
## 兩個寫這種腳本必須注意的地方（前作實際踩過）：
##   1. 幀數不等於時間。幀率會變（有敵人時與清場後差距可達數十倍），
##      要等時間就用 Time.get_ticks_msec()。
##   2. 結果要逐項即時印出。全部累積到最後才印的話，腳本一旦中途卡住
##      就什麼都看不到。

const UI_TIMEOUT_MS := 8000
const WAVE_TIMEOUT_MS := 40000

var _failures := 0
var _main: Node
var _hud: CanvasLayer
var _board_view: Node2D


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["通過" if ok else "失敗", label])
	if not ok:
		_failures += 1


func _await_until(condition: Callable, timeout_ms: int) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true


func _mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	Input.parse_input_event(event)


## 真實拖曳會持續送出帶按鍵遮罩的移動事件，測試照做才不會因為
## 「單一事件沒剛好在對的時機被沖出去」而偶發失敗。
func _drag_to(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _drag_unit(from_index: int, to_index: int) -> void:
	var from_pos := Board.cell_center(from_index)
	var to_pos := Board.cell_center(to_index)
	_mouse(from_pos, true)
	for i in 12:
		_drag_to(to_pos)
		await get_tree().physics_frame
	_mouse(to_pos, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_hud = _main.get_node("HUD")
	_board_view = _main.get_node("BoardView")
	var start_button: Button = _hud.get_node("StartButton")
	var summon_button: Button = _hud.get_node("SummonButton")
	await get_tree().process_frame

	print("環境：視窗 %s　視圖 %s" % [
		DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])

	_check("開場顯示標題與開始鈕", start_button.visible and not summon_button.visible)

	# 用真實滑鼠事件點擊，才驗得到輸入路由沒有被背景 Control 吃掉
	_mouse(Vector2(360, 905), true)
	await get_tree().process_frame
	_mouse(Vector2(360, 905), false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("點擊開始鈕可開局", summon_button.visible and not start_button.visible)

	# 召喚兩隻一階守衛
	_hud.summon_requested.emit()
	_hud.summon_requested.emit()
	await get_tree().process_frame
	_check("召喚兩隻後棋盤有兩隻守衛", _main._board.occupied_indices().size() == 2)
	_check("召喚後費用上升", _main._economy.summon_cost() == 28)

	# 拖曳合成：兩隻一階應合成為一隻二階
	await _drag_unit(0, 1)
	_check("合成後只剩一隻守衛", _main._board.occupied_indices().size() == 1)
	var merged = _main._board.get_unit(1)
	_check("合成後階級為 2", merged != null and merged["tier"] == 2)

	# 波次流程
	var wave_started: bool = await _await_until(
		func(): return _main._wave >= 1, UI_TIMEOUT_MS)
	_check("開場緩衝後波次開始", wave_started)

	var enemy_spawned: bool = await _await_until(
		func(): return not get_tree().get_nodes_in_group("enemy").is_empty(),
		UI_TIMEOUT_MS)
	_check("敵人有生成", enemy_spawned)

	var wave_two: bool = await _await_until(
		func(): return _main._wave >= 2, WAVE_TIMEOUT_MS)
	_check("第一波結束後進入第二波", wave_two)

	# 直接扣光生命驗證結束流程
	_main._economy.lose_lives(_main._economy.lives)
	_main._game_over()
	await get_tree().process_frame
	_check("結束後停止流程", not _main._running)
	_check("結束後清空場上敵人", get_tree().get_nodes_in_group("enemy").is_empty())

	var restart_shown: bool = await _await_until(
		func(): return start_button.visible, UI_TIMEOUT_MS)
	_check("結束畫面出現重來鈕", restart_shown and start_button.text == "再玩一次")

	_hud.start_game.emit()
	await get_tree().process_frame
	_check("重來後棋盤清空且金幣重置",
		_main._board.occupied_indices().is_empty() and _main._economy.gold == 60)

	print("---")
	if _failures == 0:
		print("整合測試全部通過")
	else:
		print("整合測試有 %d 項失敗" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
```

建立 `tools/integration_check.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/integration_check.gd" id="1"]

[node name="IntegrationCheck" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: 寫完整驗證腳本**

建立 `tools/verify_game.sh`：

```bash
#!/usr/bin/env bash
# 完整驗證：語法檢查 → 單元測試 → 整合測試。
#
# 整合測試需要真正的算繪視窗（要驗證輸入路由與 UI），不能用 --headless。
# 這裡刻意不加 --quit-after：強制結束的結束碼是 0，會讓中途卡住的測試
# 看起來像通過。讓腳本自己 quit()。

set -uo pipefail

GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

status=0

echo "== 重新掃描專案 =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 語法檢查 =="
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	if ! "$GODOT" --headless --path . --check-only -s "$f" >/dev/null 2>&1; then
		echo "語法錯誤: $f"
		status=1
	fi
done
[ "$status" -eq 0 ] && echo "全部通過"

echo
echo "== 單元測試 =="
if ! tools/run_tests.sh; then
	status=1
fi

echo
echo "== 整合測試 =="
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
"$GODOT" --path . tools/integration_check.tscn >"$LOG" 2>&1
integration_exit=$?
grep -E "^(通過|失敗)|^整合測試|^環境|^---" "$LOG"
if [ "$integration_exit" -ne 0 ]; then
	echo "整合測試結束碼 ${integration_exit}"
	grep -iE "SCRIPT ERROR|Parse Error" "$LOG" | head -10
	status=1
fi

echo
if [ "$status" -eq 0 ]; then
	echo "=== 全部驗證通過 ==="
else
	echo "=== 有驗證項目失敗 ==="
fi
exit "$status"
```

```bash
chmod +x tools/verify_game.sh
```

- [ ] **Step 6: 執行完整驗證**

```bash
tools/verify_game.sh
```

預期：語法無誤、單元測試 `通過 53`、整合測試全部通過、印出「=== 全部驗證通過 ===」。

- [ ] **Step 7: 實際玩完整一局**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

逐項確認：標題顯示最高波次 → 開始後顯示「準備防守」三秒 → 第一波小偷依序進場 → 召喚與合成守衛擊殺小偷、金幣增加 → 一波清空顯示「第 N 波守住了」並給過關獎勵 → 三秒後下一波，敵人變多變強 → 第五波出現大盜 → 生命歸零顯示結束畫面與最高波次 → 重來後棋盤清空、金幣回到 60。

- [ ] **Step 8: Commit**

```bash
git add scenes tools
git commit -m "新增波次流程、生命結算、最高波次存檔與整合測試"
```

---

### Task 11: HTML5 匯出

匯出範本在前作已安裝（`~/Library/Application Support/Godot/export_templates/4.7.2.stable/` 下的 `web_nothreads_*`），本次不需重新下載。

**Files:**
- Create: `export_presets.cfg`、`README.md`
- Create: `build/web/`（匯出產物，已在 `.gitignore` 排除）

- [ ] **Step 1: 確認匯出範本已安裝**

```bash
ls -lh "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/" | grep -i web
```

預期：看到 `web_nothreads_debug.zip` 與 `web_nothreads_release.zip`。若不存在，需要下載官方匯出範本（約 1.2 GB），下載前先向使用者取得同意。

- [ ] **Step 2: 寫匯出預設**

建立 `export_presets.cfg`。`variant/thread_support=false` 讓匯出使用 `web_nothreads_*` 範本，網頁版因此不需要伺服器提供跨來源隔離標頭，用 `python3 -m http.server` 就能跑：

```
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="addons/gut/*, test/*, tools/*, docs/*"
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
html/progressive_web_app=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

- [ ] **Step 3: 匯出網頁版**

```bash
GODOT=/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot
rm -rf build/web && mkdir -p build/web
$GODOT --headless --path . --export-release "Web" build/web/index.html
echo "匯出結束碼: $?"
ls -lh build/web/
```

預期：結束碼 0，產生 `index.html`、`index.js`、`index.wasm`、`index.pck`。

- [ ] **Step 4: 在瀏覽器實測**

網頁版必須經由 HTTP 提供，直接開 `file://` 會因跨來源限制失敗：

```bash
python3 -m http.server 8765 --directory build/web
```

開啟 `http://localhost:8765`，逐項確認：遊戲載入且中文正常顯示 → 點擊開始 → 召喚守衛 → 用滑鼠拖曳合成 → 敵人進場、守衛開火 → 完整玩到結束畫面 → 重新整理後最高波次仍在（存於瀏覽器 IndexedDB）。

**自動化測試網頁版時的兩個要點**（前作實測結論）：Godot 網頁版監聽的是 `MouseEvent` 而非 `PointerEvent`；分頁若為背景狀態（`document.hidden` 為 true）瀏覽器不發 `requestAnimationFrame`，Godot 主迴圈會完全停住，看起來很像當掉。

- [ ] **Step 5: 寫專案 README**

建立 `README.md`：

```markdown
# 口袋守衛戰

以「口袋」品牌吉祥物為主角的隨機合成塔防遊戲，以 Godot 4.7 開發，可匯出為網頁版。
玩法參考《同盟塔防戰－並肩作戰》的核心循環。

## 玩法

三隻吉祥物守護金庫，抵擋一波波前來行竊的小偷。

- 按「召喚」花金幣在格子上生成一隻**隨機種類**的一階守衛
- 把**兩隻同階守衛拖在一起**，合成為高一階、**種類隨機**的守衛
- 守衛自動攻擊軌道上的小偷；小偷抵達金庫會偷走生命
- 生命歸零即結束，無限波次，記錄最高波數

三種守衛各有定位：紅牛單體重擊、橘壁虎連射、綠恐龍範圍濺射。

## 開發

需要 Godot 4.7.2。開啟專案：

    /Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path .

完整驗證（語法 → 單元測試 → 整合測試），改完程式跑這個：

    tools/verify_game.sh

只跑單元測試（**用這個腳本，不要直接呼叫 GUT**，原因見腳本開頭註解）：

    tools/run_tests.sh

不開視窗確認畫面：

    /Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path . tools/capture.tscn -- /tmp/shot.png 300

重新產生敵人與金庫美術（詳見 [tools/README.md](tools/README.md)）：

    tools/.venv/bin/python tools/prepare_assets.py

## 匯出網頁版

    /Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html
    python3 -m http.server 8765 --directory build/web

然後開啟 <http://localhost:8765>。

## 專案結構

| 路徑 | 內容 |
|---|---|
| `scripts/` | 遊戲規則的純類別（棋盤、合成、數值、經濟、波次、選敵），單元測試對象 |
| `scenes/` | 遊戲場景與其腳本 |
| `assets/` | 吉祥物（沿用 Game1）、程式化產生的敵人與金庫、字型與主題 |
| `test/unit/` | GUT 單元測試 |
| `tools/` | 資產產生、測試把關、整合測試、擷圖工具 |
| `docs/superpowers/` | 設計規格與實作計畫 |

## 架構重點

**規則與節點分離。** 所有遊戲規則放在 `scripts/` 下不繼承 `Node` 的類別裡，
節點只負責畫面與輸入。`Board` 是棋盤的唯一真相來源，`BoardView` 只把它畫出來。

**亂數可注入。** 合成與召喚的隨機性都透過外部傳入的 `RandomNumberGenerator`，
測試給固定種子即可穩定重現。隨機玩法若不先處理這件事，之後每個牽涉隨機的
測試都會變成間歇性失敗。

**訊號單向往上。** `UnitView` 開火只管發訊號，不知道投射物怎麼生成；
`BoardView` 完成拖放只管發訊號，不知道規則怎麼判定。狀態改變集中在 `Main`。

## 授權

程式碼為專案自有。內嵌字型 Noto Sans TC 採 SIL Open Font License 1.1。
吉祥物圖為「口袋」品牌素材。
```

- [ ] **Step 6: 最終完整驗證並 commit**

```bash
tools/verify_game.sh
git add export_presets.cfg README.md
git commit -m "新增 HTML5 匯出設定與專案說明"
```

預期：全部驗證通過。

---

## 自我檢查結果

**規格涵蓋度：** 規格每一節都有對應任務——遊戲概念與核心循環（Task 6–10）、版面與座標（Task 1 的 project.godot、Task 4 的 Board 常數、Task 8 的軌道曲線）、三種守衛與階級（Task 3）、合成規則（Task 4）、敵人四種與生命成長（Task 5）、經濟公式（Task 3）、節點架構（Task 6–10）、為可測試性而設計（Task 3–5）、資料流訊號方向（Task 6、7、9、10）、錯誤處理（Enemy 與 Projectile 的存活上限、目標失效檢查、無空格拒絕、金幣不足停用按鈕、結束清場、拖曳按鍵遮罩檢查）、資產（Task 2）、測試策略（Task 1 建立、Task 10 的整合測試）、六個里程碑（對應十一個任務）。

**與規格的一處調整：** 規格的節點架構圖列了 `WaveTimer`，實作改為只用 `SpawnTimer`（波內生成節奏）與 `BreakTimer`（波間休息）。波次推進由「場上敵人歸零且待生成清單為空」觸發，不需要第三個計時器——少一個計時器就少一個要同步的狀態。

**型別一致性核對：** `UnitStats` 五個靜態方法、`Economy` 七個實例方法與兩個靜態方法、`MergeRules` 兩個靜態方法、`Board` 三個靜態與八個實例方法、`WaveTable` 五個靜態方法、`Targeting.select`、`UnitView` 三個方法與 `fired` 訊號、`BoardView` 七個方法與兩個訊號、`Enemy` 兩個方法與兩個訊號、`Projectile.setup`、`HUD` 七個方法與兩個訊號，在定義處與所有使用處的名稱、參數順序、型別均已逐一核對相符。

特別核對的三處易錯點：`Board.clear_cell()` 而非 `clear()`（避免與 `Array.clear` 混淆）；`UnitView.fired` 與 `BoardView.unit_fired` 都帶五個參數且順序一致（origin、target、damage、splash、color）；`Projectile.setup()` 的第四個參數 `color` 在 Task 9 Step 1 定義、Step 5 使用，兩處相符。
