# ---------------------------------------------------------------------------
# run_sim.do —— 自动售货机整机功能仿真（购买 1 号商品）
#
# 用法（在本 sim 目录下）：
#   ModelSim GUI :  vsim -do run_sim.do      （会打开波形窗口）
#   命令行       :  vsim -c -do "do run_sim.do; run -all; quit -f"
#
# 注意：仿真用的是"源文件级"功能仿真，不需要 Quartus 先编译。
# ---------------------------------------------------------------------------

vlib work
vmap work work

vcom -93 ../fp.vhd ../shouhuoji.vhd ../xianshi.vhd ../dingceng.vhd tb_dingceng.vhd

vsim -t 1ns work.tb_dingceng

add wave -divider "inputs"
add wave clk20 rst2 coin2 pp
add wave -divider "display codes"
add wave -radix binary I1
add wave -radix binary I2
add wave -radix binary I3
add wave -divider "status"
add wave suc2 showout2
add wave -divider "board display"
add wave -radix binary seg
add wave -radix binary sel
