# -*- coding: utf-8 -*-
"""
make_quartus_vwf.py —— 生成一份给 Quartus 自带仿真器用的 .vwf 激励文件。

以工程里已有的 Waveform1.vwf（顶层端口列表与之一致）为模板，只替换输入信号的
TRANSITION_LIST，输出信号保持 X（由设计驱动）。

场景：购买 1 号商品（价格 2，投 5，找零 3）。
前提：fp.vhd 里 SIM_MODE = TRUE（节拍 100ns、扫描 40ns），
      这样整笔交易在 0.5us 内跑完，远小于 Quartus End Time 的 100us 上限。

时间安排（10ns 周期时钟，节拍沿在 95 / 195 / 295 / 395 / 495 ns）：
   0 ~ 50 ns      rst2 = 0（复位），pp = 0000，coin2 = 00
   50 ns          rst2 = 1，pp = 0001（选 1 号商品）
   190 ~ 210 ns   coin2 = 01（投 5），正好跨过 195ns 的节拍沿
   1000 ns        仿真结束
"""
import re
import os

SRC = os.path.join("..", "Waveform.vwf")      # 工程里已有一份同端口列表的模板
DST = "wave_quartus_buy_item1.vwf"

# 每个输入信号的 TRANSITION_LIST 内容（'\t' 缩进与 Quartus 自己生成的格式一致）
CLK = ("\t\tREPEAT = 1;\n"
       "\t\tNODE\n"
       "\t\t{\n"
       "\t\t\tREPEAT = 100;\n"
       "\t\t\tLEVEL 0 FOR 5.0;\n"
       "\t\t\tLEVEL 1 FOR 5.0;\n"
       "\t\t}\n")

STIM = {
    "clk20":    CLK,
    "rst2":     "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 50.0;\n\t\tLEVEL 1 FOR 950.0;\n",
    "pp[0]":    "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 50.0;\n\t\tLEVEL 1 FOR 950.0;\n",
    "pp[1]":    "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 1000.0;\n",
    "pp[2]":    "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 1000.0;\n",
    "pp[3]":    "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 1000.0;\n",
    "coin2[1]": "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 1000.0;\n",
    "coin2[0]": "\t\tREPEAT = 1;\n\t\tLEVEL 0 FOR 190.0;\n\t\tLEVEL 1 FOR 20.0;\n\t\tLEVEL 0 FOR 790.0;\n",
}

src = open(SRC, "r", encoding="utf-8", errors="replace").read()

pattern = re.compile(r'TRANSITION_LIST\("([^"]+)"\)\s*\{\s*\n\tNODE\s*\n\t\{\n.*?\n\t\}\n\}', re.S)


def repl(m):
    name = m.group(1)
    body = STIM.get(name)
    if body is None:
        return m.group(0)                      # 输出信号：原样保留（LEVEL X）
    return 'TRANSITION_LIST("%s")\n{\n\tNODE\n\t{\n%s\t}\n}\n' % (name, body)


out, n = pattern.subn(repl, src)
print("替换了 %d 个 TRANSITION_LIST 块" % n)

# 确保 HEADER 里的仿真结束时间 = 1000 ns（=1us，远小于 100us 上限）
out = re.sub(r"DATA_DURATION = [0-9.]+;", "DATA_DURATION = 1000.0;", out, count=1)
out = re.sub(r"SIMULATION_TIME = [0-9.]+;", "SIMULATION_TIME = 0.0;", out, count=1)

open(DST, "w", encoding="ascii", errors="replace").write(out)
print("已生成", DST, os.path.getsize(DST), "字节")
