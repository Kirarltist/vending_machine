--------------------------------------------------------------------------------
-- 文件：tb_dingceng_fast.vhd
-- 用途：和 tb_dingceng.vhd 同样的场景（购买 1 号商品），但用于
--       fp.vhd 里 SIM_MODE = TRUE 的"快速分频"配置：
--         SCAN_DIV = 4   -> 扫描周期 40 ns
--         TICK_DIV = 10  -> 状态机节拍 100 ns（节拍沿在 95/195/295/395/495 ns）
--       整笔交易 0.5us 就跑完，远小于任何仿真工具的 End Time 上限。
--
-- 这里的时间点和 sim\wave_quartus_buy_item1.vwf 里的激励完全一致，
-- 所以两者结果应当一模一样：
--   0 ~ 50 ns      rst2=0 复位
--   50 ns          rst2=1，pp="0001"（选 1 号商品，价格 2）
--   190 ~ 210 ns   coin2="01"（投 5），跨过 195ns 的节拍沿被采一次
--   1000 ns        结束
--
--   预期：价格显示 2 -> 交易成功、找零 3 -> 回待机
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY tb_dingceng_fast IS
END tb_dingceng_fast;

ARCHITECTURE sim OF tb_dingceng_fast IS

  SIGNAL clk20    : STD_LOGIC := '0';
  SIGNAL rst2     : STD_LOGIC := '1';
  SIGNAL coin2    : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
  SIGNAL pp       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
  SIGNAL I1       : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL I2       : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL I3       : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL seg      : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL sel      : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL suc2     : STD_LOGIC;
  SIGNAL showout2 : STD_LOGIC;

  COMPONENT dingceng
    PORT(
      clk20    : IN  STD_LOGIC;
      rst2     : IN  STD_LOGIC;
      coin2    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
      pp       : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      I1       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      I2       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      I3       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      seg      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      sel      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      suc2     : OUT STD_LOGIC;
      showout2 : OUT STD_LOGIC
    );
  END COMPONENT;

  FUNCTION b2c(b : STD_LOGIC) RETURN CHARACTER IS
  BEGIN
    IF b = '1' THEN RETURN '1';
    ELSIF b = '0' THEN RETURN '0';
    ELSE RETURN 'X';
    END IF;
  END FUNCTION;

  FUNCTION d2c(p : STD_LOGIC_VECTOR(6 DOWNTO 0)) RETURN CHARACTER IS
  BEGIN
    CASE p IS
      WHEN "0111111" => RETURN '0';
      WHEN "0000110" => RETURN '1';
      WHEN "1011011" => RETURN '2';
      WHEN "1001111" => RETURN '3';
      WHEN "1100110" => RETURN '4';
      WHEN "1101101" => RETURN '5';
      WHEN "1111101" => RETURN '6';
      WHEN "0000111" => RETURN '7';
      WHEN "1111111" => RETURN '8';
      WHEN "1101111" => RETURN '9';
      WHEN "1110111" => RETURN 'A';
      WHEN "1111100" => RETURN 'b';
      WHEN "0111001" => RETURN 'C';
      WHEN "1011110" => RETURN 'd';
      WHEN "1111001" => RETURN 'E';
      WHEN "1110001" => RETURN 'F';
      WHEN OTHERS    => RETURN '?';
    END CASE;
  END FUNCTION;

BEGIN

  DUT : dingceng PORT MAP(clk20, rst2, coin2, pp, I1, I2, I3, seg, sel, suc2, showout2);

  clk_gen : PROCESS
  BEGIN
    clk20 <= '0'; WAIT FOR 5 ns;
    clk20 <= '1'; WAIT FOR 5 ns;
  END PROCESS;

  stim : PROCESS
  BEGIN
    rst2  <= '0';
    pp    <= "0000";
    coin2 <= "00";
    WAIT FOR 50 ns;
    rst2  <= '1';
    pp    <= "0001";          -- 选 1 号商品
    WAIT FOR 140 ns;          -- 到 190 ns
    coin2 <= "01";            -- 投 5
    WAIT FOR 20 ns;           -- 到 210 ns，跨过 195ns 的节拍沿
    coin2 <= "00";
    WAIT FOR 790 ns;          -- 到 1000 ns
    ASSERT FALSE
      REPORT "==== SIM END (fast mode): item 1 bought, change = 3 ===="
      SEVERITY FAILURE;
  END PROCESS;

  mon : PROCESS
  BEGIN
    WAIT ON I1, I2, I3, suc2, showout2;
    REPORT "t=" & INTEGER'IMAGE(NOW/1 ns) & " ns"
         & " | price_disp=" & d2c(I1)
         & " need_disp="  & d2c(I2)
         & " mout_disp="  & d2c(I3)
         & " | suc=" & b2c(suc2) & " showout=" & b2c(showout2);
  END PROCESS;

END sim;
