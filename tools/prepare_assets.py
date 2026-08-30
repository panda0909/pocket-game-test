"""程式化產生小偷與金庫的遊戲貼圖。

執行方式：
    tools/.venv/bin/python tools/prepare_assets.py

所有圖都以四倍尺寸繪製再縮小，藉此得到平滑邊緣。
相同輸入永遠產生相同輸出，可以安全地重複執行。
"""

import os

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY_DIR = os.path.join(ROOT, "assets", "enemies")
ASSET_DIR = os.path.join(ROOT, "assets")

SUPERSAMPLE = 4
OUTLINE = (20, 20, 24, 255)

# 高光與陰影都用半透明白／黑疊在底色上，這樣同一組數值可以套用在
# 任何顏色的身體上，換配色時不必重算每一種明暗。
HIGHLIGHT = (255, 255, 255, 62)
SHADOW = (0, 0, 0, 48)

SACK_COLOR = (228, 206, 160, 255)
COIN_COLOR = (255, 196, 0, 255)
CAPE_COLOR = (196, 42, 52, 255)

# 名稱 -> (輸出尺寸, 身體顏色, 是否加披風, 眼睛樣式)
# 眼睛樣式讓四種敵人一眼分得出來，不必只靠大小與顏色。
ENEMIES = {
    "thief": (96, (58, 68, 110, 255), False, "round"),
    "runner": (80, (72, 132, 148, 255), False, "narrow"),
    "brute": (120, (46, 52, 78, 255), False, "angry"),
    "boss": (140, (38, 40, 62, 255), True, "glow"),
}


def _shade_within(image, box):
    """在指定橢圓範圍內加上左上高光與右下陰影，做出圓潤的立體感。

    先畫在獨立圖層、再用同一個橢圓當遮罩裁切，陰影才不會溢出輪廓。
    直接畫在主圖上會蓋到旁邊的錢袋與披風。
    """
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)

    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0

    draw.ellipse(
        (x0 + width * 0.20, y0 + height * 0.34, x1 + width * 0.12, y1 + height * 0.12),
        fill=SHADOW,
    )
    draw.ellipse(
        (x0 + width * 0.10, y0 + height * 0.06, x0 + width * 0.58, y0 + height * 0.44),
        fill=HIGHLIGHT,
    )

    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    image.alpha_composite(layer)


def _draw_eyes(draw, big, style, band_top, band_bottom):
    """依樣式畫眼睛。四種敵人靠表情區分，比只調大小好認得多。"""
    eye_y = (band_top + band_bottom) / 2
    radius = big * 0.038
    for eye_x in (big * 0.34, big * 0.56):
        if style == "narrow":
            # 瞇眼：橫向壓扁，看起來像在衝刺
            draw.ellipse(
                (eye_x - radius * 1.3, eye_y - radius * 0.45,
                 eye_x + radius * 1.3, eye_y + radius * 0.45),
                fill=OUTLINE,
            )
        elif style == "angry":
            # 怒眼：圓眼加上一道斜眉
            draw.ellipse(
                (eye_x - radius, eye_y - radius, eye_x + radius, eye_y + radius),
                fill=OUTLINE,
            )
            slant = radius * 1.1 if eye_x < big * 0.45 else -radius * 1.1
            draw.line(
                [(eye_x - radius * 1.2, eye_y - radius * 1.5 - slant * 0.4),
                 (eye_x + radius * 1.2, eye_y - radius * 1.5 + slant * 0.4)],
                fill=OUTLINE,
                width=max(2, int(big * 0.016)),
            )
        elif style == "glow":
            # 發光眼：外圈紅光加深色瞳孔，大盜一眼可辨
            draw.ellipse(
                (eye_x - radius * 1.5, eye_y - radius * 1.5,
                 eye_x + radius * 1.5, eye_y + radius * 1.5),
                fill=(226, 74, 74, 255),
            )
            draw.ellipse(
                (eye_x - radius * 0.7, eye_y - radius * 0.7,
                 eye_x + radius * 0.7, eye_y + radius * 0.7),
                fill=OUTLINE,
            )
        else:
            draw.ellipse(
                (eye_x - radius, eye_y - radius, eye_x + radius, eye_y + radius),
                fill=OUTLINE,
            )


def _draw_sack(image, draw, big, outline_width):
    """背在右後方的錢袋，束口加上露出來的金幣。"""
    box = (big * 0.62, big * 0.28, big * 0.97, big * 0.66)
    draw.ellipse(box, fill=SACK_COLOR, outline=OUTLINE, width=outline_width)
    _shade_within(image, box)

    # 束口：兩段短線加中間的結
    knot_y = big * 0.29
    draw.line([(big * 0.68, knot_y), (big * 0.91, knot_y)],
              fill=OUTLINE, width=outline_width)
    draw.ellipse((big * 0.77, knot_y - big * 0.030, big * 0.83, knot_y + big * 0.030),
                 fill=OUTLINE)

    # 袋口露出的金幣，點出「偷錢」這件事
    for cx, cy, r in (
        (big * 0.72, big * 0.245, big * 0.038),
        (big * 0.84, big * 0.250, big * 0.032),
    ):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r),
                     fill=COIN_COLOR, outline=OUTLINE, width=max(2, outline_width // 2))


def draw_thief(size, body_color, cape, eye_style):
    """小偷：深色圓身、白色蒙面橫帶、背上裝著金幣的錢袋。"""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline_width = max(2, int(big * 0.035))

    if cape:
        # 披風畫在身體後面，往左後方甩出去。要伸出身體輪廓（x < 0.14）夠多，
        # 否則會整片被身體蓋住，大盜就看不出和一般小偷的差別。
        draw.polygon(
            [
                (big * 0.40, big * 0.20),
                (big * 0.02, big * 0.50),
                (big * 0.04, big * 0.98),
                (big * 0.46, big * 0.80),
            ],
            fill=CAPE_COLOR,
            outline=OUTLINE,
        )

    _draw_sack(image, draw, big, outline_width)

    # 腳：畫在身體之前，才會被身體壓在下面像是從底下伸出來
    for foot_x in (big * 0.30, big * 0.56):
        draw.ellipse(
            (foot_x - big * 0.075, big * 0.86, foot_x + big * 0.075, big * 0.97),
            fill=body_color, outline=OUTLINE, width=outline_width,
        )

    body = (big * 0.14, big * 0.22, big * 0.78, big * 0.92)
    draw.ellipse(body, fill=body_color, outline=OUTLINE, width=outline_width)
    _shade_within(image, body)

    # 蒙面橫帶
    band_top = big * 0.38
    band_bottom = big * 0.50
    draw.rectangle((big * 0.16, band_top, big * 0.76, band_bottom),
                   fill=(246, 246, 250, 255))
    draw.line([(big * 0.16, band_top), (big * 0.76, band_top)],
              fill=OUTLINE, width=max(2, outline_width // 2))
    draw.line([(big * 0.16, band_bottom), (big * 0.76, band_bottom)],
              fill=OUTLINE, width=max(2, outline_width // 2))

    _draw_eyes(draw, big, eye_style, band_top, band_bottom)

    return image.resize((size, size), Image.LANCZOS)


def draw_vault(size=160):
    """金庫：帶立體邊框的保險箱、金色轉盤與門把。"""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline_width = max(2, int(big * 0.03))
    radius_outer = big * 0.10

    # 外殼下方多畫一層深色，做出厚度
    pad = big * 0.08
    draw.rounded_rectangle(
        (pad, pad + big * 0.03, big - pad, big - pad + big * 0.02),
        radius=radius_outer, fill=(52, 55, 64, 255),
    )
    draw.rounded_rectangle(
        (pad, pad, big - pad, big - pad),
        radius=radius_outer, fill=(84, 88, 100, 255),
        outline=OUTLINE, width=outline_width,
    )
    # 內門板
    inner = big * 0.19
    draw.rounded_rectangle(
        (inner, inner, big - inner, big - inner),
        radius=big * 0.06, fill=(108, 112, 126, 255),
        outline=OUTLINE, width=outline_width,
    )
    draw.rounded_rectangle(
        (inner + big * 0.03, inner + big * 0.03, big - inner - big * 0.06, big - inner - big * 0.09),
        radius=big * 0.04, fill=(124, 129, 144, 255),
    )

    # 四角鉚釘
    for rx, ry in (
        (pad + big * 0.055, pad + big * 0.055),
        (big - pad - big * 0.055, pad + big * 0.055),
        (pad + big * 0.055, big - pad - big * 0.055),
        (big - pad - big * 0.055, big - pad - big * 0.055),
    ):
        r = big * 0.018
        draw.ellipse((rx - r, ry - r, rx + r, ry + r), fill=(58, 61, 70, 255))

    # 轉盤的四根轉柄
    center = big / 2
    spoke = big * 0.19
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        draw.line(
            [(center, center), (center + dx * spoke, center + dy * spoke)],
            fill=OUTLINE, width=outline_width,
        )

    # 金色轉盤，加一圈深金外環與左上高光
    dial = big * 0.14
    draw.ellipse((center - dial, center - dial, center + dial, center + dial),
                 fill=(214, 160, 0, 255), outline=OUTLINE, width=outline_width)
    inner_dial = dial * 0.74
    draw.ellipse(
        (center - inner_dial, center - inner_dial, center + inner_dial, center + inner_dial),
        fill=COIN_COLOR,
    )
    draw.ellipse(
        (center - inner_dial * 0.75, center - inner_dial * 0.8,
         center - inner_dial * 0.05, center - inner_dial * 0.15),
        fill=(255, 232, 150, 255),
    )

    return image.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ENEMY_DIR, exist_ok=True)

    for name, (size, color, cape, eye_style) in sorted(ENEMIES.items()):
        path = os.path.join(ENEMY_DIR, name + ".png")
        draw_thief(size, color, cape, eye_style).save(path)
        print(f"敵人 {name}.png ({size}, {size}) 眼睛樣式 {eye_style}")

    vault_path = os.path.join(ASSET_DIR, "vault.png")
    draw_vault().save(vault_path)
    print("金庫 vault.png (160, 160)")


if __name__ == "__main__":
    main()
