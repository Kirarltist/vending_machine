vlib work
vcom -93 ../fp.vhd ../shouhuoji.vhd ../xianshi.vhd ../dingceng.vhd tb_dingceng.vhd
vsim -c -do "run -all; quit -f" work.tb_dingceng