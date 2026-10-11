# -*- coding: utf-8 -*-
"""
draw_wave.py —— 把 ModelSim 功能仿真的结果画成一张时序示意图（PNG）。
数据全部取自 sim/transcript.txt 的实际仿真输出（购买 1 号商品场景）。
运行：  python draw_wave.py
"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 860
L, R, T, B = 180, 50, 110, 250
FONT = "C:/Windows/Fonts/msyh.ttc"

f_title = ImageFont.truetype(FONT, 26)
f_lab = ImageFont.truetype(FONT, 19)
f_val = ImageFont.truetype(FONT, 19)
f_small = ImageFont.truetype(FONT, 16)

img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)

T0, T1 = 0.0, 6.0            # ms


def X(t):
    return L + (W - L - R) * (t - T0) / (T1 - T0)


rows = [
    ("pp[3:0]",    [(0, 0.5, "0000"), (0.5, 6.0, "0001")]),
    ("coin2[1:0]", [(0, 1.9, "00"), (1.9, 2.1, "01"), (2.1, 6.0, "00")]),
    ("price 价格",  [(0, 1.0, "X"), (1.0, 2.0, "0"), (2.0, 5.0, "2"), (5.0, 6.0, "0")]),
    ("need 应付",   [(0, 1.0, "X"), (1.0, 2.0, "0"), (2.0, 4.0, "2"), (4.0, 6.0, "0")]),
    ("mout 找零",   [(0, 1.0, "X"), (1.0, 4.0, "0"), (4.0, 5.0, "3"), (5.0, 6.0, "0")]),
    ("suc2",       [(0, 1.0, "X"), (1.0, 4.0, "0"), (4.0, 5.0, "1"), (5.0, 6.0, "0")]),
    ("showout2",   [(0, 1.0, "X"), (1.0, 4.0, "0"), (4.0, 5.0, "1"), (5.0, 6.0, "0")]),
]

rowh = (H - T - B) / len(rows)

# 标题
d.text((L, 25), "自动售货机 购买 1 号商品 功能仿真时序（ModelSim，数据取自 transcript.txt）",
       font=f_title, fill="black")
d.text((L, 62), "1 号商品价格 = 2；投币 K0(coin2=\"01\") 一次加 5；所以结果应是：价格 2 → 找零 3 + 交易成功",
       font=f_small, fill="#444444")

# 节拍竖线
for k in range(1, 6):
    x = X(float(k))
    y = T - 6
    while y < H - B:
        d.line([(x, y), (x, min(y + 6, H - B))], fill="#d08080", width=1)
        y += 12
    d.text((x - 34, T - 34), "节拍 %dms" % k, font=f_small, fill="#a04040")

# 每行
for i, (name, segs) in enumerate(rows):
    y = T + i * rowh
    yc = y + rowh / 2
    d.text((16, yc - 12), name, font=f_lab, fill="black")
    # 基线
    d.line([(X(0), yc), (X(6), yc)], fill="#bbbbbb", width=1)
    for (a, b, val) in segs:
        xa, xb = X(a), X(b)
        fill = "#eef4ff" if val not in ("X",) else "#eeeeee"
        d.rectangle([xa, yc - 17, xb, yc + 17], fill=fill, outline="#4a6fa5")
        w = d.textlength(val, font=f_val)
        d.text(((xa + xb) / 2 - w / 2, yc - 11), val, font=f_val, fill="black")

# 时间轴
y_axis = H - B + 10
d.line([(X(0), y_axis), (X(6), y_axis)], fill="black", width=2)
for k in range(0, 7):
    x = X(float(k))
    d.line([(x, y_axis), (x, y_axis + 8)], fill="black", width=2)
    d.text((x - 18, y_axis + 12), "%d ms" % k, font=f_small, fill="black")

# 注释
notes = [
    "① 0.1~0.5 ms：复位（rst2=0），状态机停在待机 a",
    "② 0.5 ms：rst2=1 放开复位，pp=0001 选 1 号商品（K2 拨上）",
    "③ 1.0 ms 节拍：状态 a 读到 pp=0001 → 转 b，价格寄存器 = 2",
    "④ 1.9~2.1 ms：coin2=01 投 5（K0 拨上一下），被 2.0 ms 节拍采到一次",
    "⑤ 3.0 ms 节拍：已投 5 ≥ 价格 2 → 找零 backmoney = 5-2 = 3，转状态 d",
    "⑥ 4.0 ms 节拍：状态 d → suc=1、mout=3、showout=1（交易成功＋找零）",
    "⑦ 5.0 ms 节拍：状态 a → 全部清零，回到待机",
]
for i, s in enumerate(notes):
    d.text((16 + (i % 2) * 660, y_axis + 40 + (i // 2) * 24), s, font=f_small, fill="#333333")

img.save("wave_buy_item1.png")
print("saved wave_buy_item1.png", img.size)
