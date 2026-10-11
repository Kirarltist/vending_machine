--------------------------------------------------------------------------------
-- 文件：tb_dingceng.vhd
-- 用途：自动售货机整机功能仿真平台（ModelSim）。场景：购买 1 号商品。
--
--   1 号商品价格 = 2（见 shouhuoji.vhd 状态 a：choose="0001" -> pricetemp="0010"）
--   投币：coin2="01" 表示按键 K0，一次加 5
--   所以整个过程应当是：价格显示 2 -> 投 5 -> 应付显示 2 -> 交易成功、找零 3
--
-- 时序安排（主板时钟 10ns 周期；fp 里 TICK_DIV=100000，一个状态机节拍 = 1ms）：
--   0.0 ~ 0.5 ms   复位：rst2='0'，pp="0000"，coin2="00"
--   0.5 ms         放开复位，pp="0001"（拨 K2 选 1 号商品）
--   1.9 ~ 2.1 ms   coin2="01"（拨 K0 投 5）
--                  —— 必须"跨过"2.0ms 这个节拍沿，状态机才恰好采到一次
--   6.0 ms         结束仿真
--
-- 状态机节拍沿出现在 t = 1.0ms / 2.0ms / 3.0ms / 4.0ms / 5.0ms ...
--   t=1.0ms : 状态 a 看到 pp="0001" -> 转入 b，pricetemp=2、needtemp=2
--   t=2.0ms : 状态 b 采到 coin="01" -> 已投金额 +5；price<=2、need<=2
--   t=3.0ms : 已投 5 >= 价格 2 -> 找零 backmoney = 5-2 = 3，转入 d
--   t=4.0ms : 状态 d -> suc=1、mout=3、showout=1，然后回 a
--   t=5.0ms : 状态 a -> 全部清零，回到待机
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY tb_dingceng IS
END tb_dingceng;

ARCHITECTURE sim OF tb_dingceng IS

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

  ------------------------------------------------------------------------------
  -- 被测设计：整机顶层
  ------------------------------------------------------------------------------
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

  ------------------------------------------------------------------------------
  -- 辅助函数：把 1 位逻辑值 / 7 段码打印成可读字符
  ------------------------------------------------------------------------------
  FUNCTION b2c(b : STD_LOGIC) RETURN CHARACTER IS
  BEGIN
    IF b = '1' THEN RETURN '1';
    ELSIF b = '0' THEN RETURN '0';
    ELSE RETURN 'X';
    END IF;
  END FUNCTION;

  FUNCTION bin7(p : STD_LOGIC_VECTOR(6 DOWNTO 0)) RETURN STRING IS
    VARIABLE s : STRING(1 TO 7);
  BEGIN
    FOR i IN 0 TO 6 LOOP
      IF p(6-i) = '1' THEN s(i+1) := '1'; ELSE s(i+1) := '0'; END IF;
    END LOOP;
    RETURN s;
  END FUNCTION;

  -- 7 段码 -> 十六进制字符（与 xianshi.vhd 的编码表一一对应）
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

  DUT : dingceng PORT MAP(
          clk20    => clk20,
          rst2     => rst2,
          coin2    => coin2,
          pp       => pp,
          I1       => I1,
          I2       => I2,
          I3       => I3,
          seg      => seg,
          sel      => sel,
          suc2     => suc2,
          showout2 => showout2
        );

  ------------------------------------------------------------------------------
  -- 10ns 周期时钟
  ------------------------------------------------------------------------------
  clk_gen : PROCESS
  BEGIN
    clk20 <= '0'; WAIT FOR 5 ns;
    clk20 <= '1'; WAIT FOR 5 ns;
  END PROCESS;

  ------------------------------------------------------------------------------
  -- 激励：购买 1 号商品（价格 2，投 5）
  ------------------------------------------------------------------------------
  stim : PROCESS
  BEGIN
    rst2  <= '0';
    pp    <= "0000";
    coin2 <= "00";
    WAIT FOR 500 us;                    -- 先复位，等状态机稳定在 a

    rst2  <= '1';                       -- 放开复位
    pp    <= "0001";                    -- 选 1 号商品（K2）
    WAIT FOR 1400 us;                   -- 到 1.9 ms

    coin2 <= "01";                      -- 投币：K0，一次加 5
    WAIT FOR 200 us;                    -- 跨过 2.0ms 的节拍沿，到 2.1 ms
    coin2 <= "00";                      -- 松手

    WAIT FOR 3900 us;                   -- 到 6.0 ms，看完 d -> a 回到待机
    -- VHDL-93 没有 std.env.finish，用 severity FAILURE 让 run -all 自动停下来
    ASSERT FALSE
      REPORT "==== SIM END: buying item 1 finished (price=2, paid=5, change=3) ===="
      SEVERITY FAILURE;
  END PROCESS;

  ------------------------------------------------------------------------------
  -- 监视：I1/I2/I3（价格/应付/找零的七段码）、suc、showout 一变就打印一行
  ------------------------------------------------------------------------------
  mon : PROCESS
  BEGIN
    WAIT ON I1, I2, I3, suc2, showout2;
    REPORT "t=" & INTEGER'IMAGE(NOW/1 us) & " us"
         & " | price_disp=" & d2c(I1) & " I1=" & bin7(I1)
         & " | need_disp="  & d2c(I2) & " I2=" & bin7(I2)
         & " | mout_disp="  & d2c(I3) & " I3=" & bin7(I3)
         & " | suc=" & b2c(suc2) & " showout=" & b2c(showout2);
  END PROCESS;

END sim;
