--------------------------------------------------------------------------------
-- 文件：shouhuoji.vhd
-- 模块：shouhuoji（主控模块）
-- 说明：自动售货机的核心控制。负责投币累加、选货判断、价格比对、
--       出货/找零/退币、状态指示，并把"要显示的内容"以 BCD 形式送给显示模块。
--
-- 接口约定：
--   coin   : 投币输入（默认接 k[3..0]）
--   choose : 选货输入（默认接 k[7..4]）
--   rst    : 复位（默认接 k[11]，高电平复位）
--   tick   : 1Hz 节拍，来自 fp，用于计时/闪烁
--   disp   : 8 位 × 4bit BCD，"disp(3 DOWNTO 0)" 是最右一位数字
--            （显示模块按下标 0..7 逐位扫描，0 为最低位）
--   led    : 状态指示
--   co     : 出货或按键提示音
--
-- TODO（待你实现，建议状态机 + 数据通路）：
--   1) 状态定义：IDLE（待机）-> COIN（投币中）-> CHOOSE（选货中）
--                -> DISPENSE（出货/找零）-> 回到 IDLE
--   2) 投币处理：识别 coin 是按"币值"还是"按键位置"编码；
--      用 coin 的上升沿/高电平检测投币，累加到"当前金额"寄存器。
--   3) 去抖：机械开关/按键有抖动，务必在输入级做 10~20ms 采样去抖
--      （用 clk 计数），否则一次投币会被识别成多次。
--   4) 价格表：定义商品编号 -> 价格的映射（价格用"角"为单位，避免小数）。
--   5) 判断：金额 >= 价格 才出货，出货后金额清零；不足则保持显示并给出提示。
--   6) 找零：金额 - 价格 = 找零，用 BCD 输出到 disp；
--      也可以用 tick 配合倒计时实现"找零/出货"动画。
--   7) 超时退币：CHOOSE 状态停留过久（用 tick 计数）则回到 IDLE 并清零金额。
--   8) 显示内容：BCD 转换（二进制金额 -> 每位 4bit BCD），
--      未使用的位显示 '0' 或灭掉。
--
-- 硬件极性待实测：数码管是共阴还是共阳、位码高电平还是低电平有效，
--                 请先在 xianshi.vhd 里写死一个测试图形上板确认。
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY shouhuoji IS
  PORT(
    clk    : IN  STD_LOGIC;                     -- 工作时钟（默认接 fp 的 clk_scan）
    rst    : IN  STD_LOGIC;                     -- 复位，低电平有效（第 78 行是 IF rst='0'）
    coin   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);  -- 投币输入
    choose : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- 选货输入
    price  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- 商品价格
    need   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- 需要补交的钱数
    mout   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- 显示找零钱数
    suc    : OUT STD_LOGIC;                     --交易成功信号（原来这里少了分号）
	 showout: OUT STD_LOGIC                     --找零成功信号
  );
END shouhuoji;

ARCHITECTURE rtl OF shouhuoji IS

  -- TODO: 在这里声明状态机状态、金额寄存器、BCD 寄存器、去抖计数器等，例如
  -- TYPE state_t IS (IDLE, COIN, CHOOSE, DISPENSE);
  -- SIGNAL state   : state_t := IDLE;
  -- SIGNAL amount  : INTEGER RANGE 0 TO 1000 := 0;      -- 当前金额（单位：角）
  -- SIGNAL bcd_d1  : STD_LOGIC_VECTOR(3 DOWNTO 0);      -- 个位
  -- SIGNAL bcd_d2  : STD_LOGIC_VECTOR(3 DOWNTO 0);      -- 十位
  -- ...
  -- 说明：这里用了 std_logic_arith，整数比较可直接用；
  --       若要用 unsigned，请改用 numeric_std 并统一类型。
  TYPE state_type IS (a,b,c,d,g);
  SIGNAL current_state : state_type := a;          -- 原写法 ": =a" 非法，改为 ":="
  SIGNAL q : INTEGER RANGE 0 to 100 := 0;          -- 加上初值，避免仿真时整数越界
  SIGNAL paidtemp:STD_LOGIC_VECTOR(3 downto 0);
  SIGNAL needtemp:STD_LOGIC_VECTOR(3 downto 0);
  SIGNAL backmoney:STD_LOGIC_VECTOR(3 downto 0);
  SIGNAL pricetemp:STD_LOGIC_VECTOR(3 downto 0);

BEGIN                     -- 架构体的开始（原来漏了这一句，第 75 行的 BEGIN 是 PROCESS 自己的）

PROCESS(clk, rst)          -- 异步复位，rst 必须放进敏感表
	BEGIN
		IF rst ='0'THEN current_state<=a;
		ELSIF clk'EVENT AND clk ='1'THEN	        -- 注意是 ELSIF，不是 ELSEIF；clk'EVENT 中间不要加空格
			CASE current_state IS
			WHEN a =>
						paidtemp<="0000";
						backmoney<="0000";
						pricetemp<="0000";
						q<=0;
						mout<="0000";
						need<="0000";
						price<="0000";
						suc<='0';
						showout<='0';
						
						-- 选货：choose 为独热码，0001->2 角、0010->3 角、0100->4 角、1000->6 角
						-- 原代码是 4 层嵌套 IF（缺 3 个 END IF）且用了未声明的信号 p，改成一条判断链
						-- 价格直接给常量：原来写 pricetemp <= pricetemp + 2 是用"旧值再累加"，
						-- 而同一进程前面还有一句 pricetemp<="0000" 被它覆盖，结果每进一次状态 a
						-- 价格就多涨一次（2→4→6…）。这里改成固定值，单位与投币一致（+1/+5）。
						IF choose = "0001" THEN
							pricetemp <= "0010"; needtemp <= "0010"; current_state <= b;   -- 商品1：2
						ELSIF choose = "0010" THEN
							pricetemp <= "0011"; needtemp <= "0011"; current_state <= b;   -- 商品2：3
						ELSIF choose = "0100" THEN
							pricetemp <= "0100"; needtemp <= "0100"; current_state <= b;   -- 商品3：4
						ELSIF choose = "1000" THEN
							pricetemp <= "0110"; needtemp <= "0110"; current_state <= b;   -- 商品4：6
						ELSE
							current_state <= a;
						END IF;
						-- 这里不再写 price<=pricetemp：那会把旧价格送到数码管，
						-- 留着状态 a 开头的 price<="0000"，待机时显示 0。
						
				WHEN b =>
							q<=q+1;
							CASE coin IS
							WHEN"10"=>paidtemp<=paidtemp +1;
							WHEN"01"=>paidtemp<=paidtemp +5;
							WHEN OTHERS=>paidtemp<=paidtemp;
							END CASE;
							IF paidtemp >=pricetemp THEN	
								needtemp<="0000";
								backmoney<=paidtemp-pricetemp;current_state<=d;
							END IF;
							IF paidtemp<pricetemp THEN     -- 原来是 "THEN;"，多出的分号会把紧跟的语句挤出 IF 之外
								needtemp<=pricetemp-paidtemp;backmoney<="0000";
							IF q=10 THEN	
								IF paidtemp="0000"THEN
									current_state<=a;
								ELSE
									q<=0;current_state<=c;
								END IF;
							ELSE
								current_state<=b;
							END IF;
						END IF;
					price<=pricetemp;
					need<=needtemp;
				WHEN c =>
							q<=q+1;
							CASE coin IS
							WHEN"10"=>paidtemp<=paidtemp +1;
							WHEN"01"=>paidtemp<=paidtemp +5;
							WHEN others=>paidtemp<=paidtemp;
							END CASE;
							IF paidtemp>=pricetemp THEN	
								needtemp<="0000";
								backmoney<=paidtemp-pricetemp;current_state<=d;
							END IF;
							IF paidtemp<pricetemp THEN	
								needtemp<=pricetemp-paidtemp;backmoney<="0000";
								IF q<=10 THEN	
									current_state<=c;
								ELSE
									backmoney<=paidtemp;
									current_state<=g;q<=0;
								END IF;
							END IF;
							price<=pricetemp;
						need<=needtemp;
				WHEN d =>
							suc<='1';
							price<=pricetemp;
							need<=needtemp;
							IF backmoney>"0000" THEN	
								mout<=backmoney;showout<='1';
							ELSE	
								mout<="0000";showout<='0';
							END IF;
							current_state<=a;
				WHEN g=>
							suc<='0';price<=pricetemp;need<=needtemp;
							IF backmoney>"0000" THEN mout<=backmoney;showout<='1';
							ELSE mout<="0000";showout<='0';
							END IF;
							current_state<=a;
						END CASE;
					END IF;
				END PROCESS;
					
				



END rtl;
