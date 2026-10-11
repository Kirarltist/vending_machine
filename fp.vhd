--------------------------------------------------------------------------------
-- 文件：fp.vhd
-- 模块：fp（时钟模块 / 分频器）
-- 说明：把主板时钟分频，产生两路节拍：
--         clk_scan : 1kHz 方波，给数码管动态扫描用（顶层轮显 I1/I2/I3）
--         co       : 10Hz 窄脉冲，给 shouhuoji 状态机当时钟用
--                    （shouhuoji 里 q=10 判断超时，10Hz 时约 1 秒）
--
--       两个分频比写成了 CONSTANT，改频率只改这两个数，不用数二进制位数。
--
--       注意：主板时钟频率由板上跳线决定（1Hz / 1KHz / 10KHz / 100KHz / 1MHz）
--             上机时请把跳线设为 1MHz，与下面的 CONSTANT 对应：
--               1MHz / 1000   = 1kHz   （扫描）
--               1MHz / 100000 = 10Hz   （状态机节拍）
--             跳线若改成别的档位，把这两个 CONSTANT 按同样的方法换算即可。
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY fp IS
	PORT (CLK20   : IN  STD_LOGIC;      -- 主板时钟（跳线设 1MHz）
			clk_scan: OUT STD_LOGIC;      -- 1kHz 扫描时钟
			co      : OUT STD_LOGIC);     -- 10Hz 状态机节拍
END fp;

ARCHITECTURE a OF fp IS

	----------------------------------------------------------------------------
	-- ★★★ 仿真 / 上机 切换开关 ★★★
	--   SIM_MODE = FALSE ：上机（下载到板子）用的真值 —— 扫描 1kHz、节拍 10Hz
	--   SIM_MODE = TRUE  ：仿真专用的超小分频比 —— 扫描 SCAN_DIV=4、节拍 TICK_DIV=10，
	--                      10ns 时钟下"一个节拍 = 100ns"，整笔交易约 0.5us 就能跑完，
	--                      这样 Quartus 自带 VWF 仿真（End Time 上限 100us）也放得下。
	--
	--   仿真步骤：把下面这行改成 TRUE -> 重新 Generate Functional Simulation Netlist
	--             -> 跑 Simulator；仿真完必须改回 FALSE 再全编译下载！
	----------------------------------------------------------------------------
	CONSTANT SIM_MODE : BOOLEAN := FALSE;      -- ★ 仿真时改 TRUE，上机前必须改回 FALSE ★

	FUNCTION pick(sim_val : INTEGER; hw_val : INTEGER; sim : BOOLEAN) RETURN INTEGER IS
	BEGIN
		IF sim THEN
			RETURN sim_val;
		ELSE
			RETURN hw_val;
		END IF;
	END FUNCTION;

	CONSTANT SCAN_DIV : INTEGER := pick(4, 1000,   SIM_MODE);  -- 上机: 1MHz/1000   = 1kHz
	CONSTANT TICK_DIV : INTEGER := pick(10, 100000, SIM_MODE); -- 上机: 1MHz/100000 = 10Hz
	SIGNAL scan_cnt : INTEGER RANGE 0 TO SCAN_DIV - 1 := 0;
	SIGNAL tick_cnt : INTEGER RANGE 0 TO TICK_DIV - 1 := 0;
	SIGNAL scan_r   : STD_LOGIC := '0';
BEGIN

	----------------------------------------------------------------------------
	-- 1kHz 方波：计到一半翻转，占空比 50%
	----------------------------------------------------------------------------
	PROCESS(CLK20)
	BEGIN
		IF CLK20'EVENT AND CLK20='1' THEN
			IF scan_cnt = SCAN_DIV/2 - 1 THEN
				scan_cnt <= 0;
				scan_r   <= NOT scan_r;
			ELSE
				scan_cnt <= scan_cnt + 1;
			END IF;
		END IF;
	END PROCESS;
	clk_scan <= scan_r;

	----------------------------------------------------------------------------
	-- 10Hz 窄脉冲：每 TICK_DIV 个时钟输出一个时钟宽的 '1'
	----------------------------------------------------------------------------
	PROCESS(CLK20)
	BEGIN
		IF CLK20'EVENT AND CLK20='1' THEN
			IF tick_cnt = TICK_DIV - 1 THEN
				tick_cnt <= 0;
				co       <= '1';
			ELSE
				tick_cnt <= tick_cnt + 1;
				co       <= '0';
			END IF;
		END IF;
	END PROCESS;

END a;
