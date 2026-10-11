--------------------------------------------------------------------------------
-- 文件：dingceng.vhd
-- 模块：dingceng（系统顶层）
-- 说明：自动售货机的系统顶层。做四件事：
--       1) 声明与硬件/仿真对应的端口（引脚见 vending_machine.qsf）；
--       2) 例化 fp（分频/时钟）、shouhuoji（主控）、xianshi（显示）；
--       3) 把 shouhuoji 的 price/need/mout 接到 xianshi，得到三路七段码 I1/I2/I3，
--          这三个端口同时送给 Waveform.vwf 观察用；
--       4) 用 1kHz 扫描时钟把 I1/I2/I3 轮流送到板上的 seg/sel，供上机下载。
--
--       为什么要第 4 步：板上 8 位数码管是动态扫描的，只有 seg[7:0] + sel[2:0]
--       这一组引脚，没法同时接 3×7=21 根独立段码，所以必须轮显。
--
--       I1/I2/I3 只是给仿真看的监视端口，没有锁引脚（见 .qsf 末尾的说明），
--       如果只做上机下载、不看波形，可以把这三个端口和下面三句赋值删掉。
--
-- 硬件平台：Cyclone IV E  EP4CE10F17C8N
--           主板时钟跳线设 1MHz
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY dingceng IS
  PORT(
    clk20    : IN  STD_LOGIC;                     -- 主板时钟，PIN_M1（跳线设 1MHz）
    rst2     : IN  STD_LOGIC;                     -- 复位，低电平有效，接拨码开关 K11
    coin2    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);  -- 投币：coin2(1)=加 1，coin2(0)=加 5
    pp       : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- 选货（独热码），接 K5..K2
    I1       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);  -- 商品价格的七段码（仿真观察用）
    I2       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);  -- 需要补交钱数的七段码
    I3       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);  -- 找零钱数的七段码
    seg      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- 段码 seg[0]=a ... seg[6]=g, seg[7]=dp
    sel      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);  -- 位码（板上经 3-8 译码选通 8 位数码管）
    suc2     : OUT STD_LOGIC;                     -- 交易成功，接 LED0
    showout2 : OUT STD_LOGIC                      -- 找零成功，接 LED1
  );
END dingceng;

ARCHITECTURE rtl OF dingceng IS

  -- 子模块之间的中间信号
  SIGNAL co1    : STD_LOGIC;                     -- fp 输出的 10Hz 状态机节拍
  SIGNAL scan1  : STD_LOGIC;                     -- fp 输出的 1kHz 扫描时钟
  SIGNAL price1 : STD_LOGIC_VECTOR(3 DOWNTO 0);  -- 商品价格
  SIGNAL need1  : STD_LOGIC_VECTOR(3 DOWNTO 0);  -- 需要补交的钱数
  SIGNAL mout1  : STD_LOGIC_VECTOR(3 DOWNTO 0);  -- 找零钱数

  -- xianshi 输出的三路七段码（内部信号，同时送给上面的监视端口）
  SIGNAL I1_i, I2_i, I3_i : STD_LOGIC_VECTOR(6 DOWNTO 0);

  -- 轮显
  SIGNAL dsel  : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";  -- 0->价格 1->应付 2->找零
  SIGNAL seg_r : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL sel_r : STD_LOGIC_VECTOR(2 DOWNTO 0);

  -- 时钟/分频模块
  COMPONENT fp
    PORT(
      CLK20    : IN  STD_LOGIC;
      clk_scan : OUT STD_LOGIC;
      co       : OUT STD_LOGIC
    );
  END COMPONENT;

  -- 主控模块
  COMPONENT shouhuoji
    PORT(
      clk    : IN  STD_LOGIC;
      rst    : IN  STD_LOGIC;
      coin   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
      choose : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      price  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      need   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      mout   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      suc    : OUT STD_LOGIC;
      showout: OUT STD_LOGIC
    );
  END COMPONENT;

  -- 显示译码模块
  COMPONENT xianshi
    PORT(
      price : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      need  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      mout  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      I1    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      I2    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      I3    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
    );
  END COMPONENT;

BEGIN

  ------------------------------------------------------------------------------
  -- U1 时钟模块：1MHz -> 1kHz 扫描 + 10Hz 节拍
  ------------------------------------------------------------------------------
  U1 : fp PORT MAP(
         CLK20    => clk20,
         clk_scan => scan1,
         co       => co1
       );

  ------------------------------------------------------------------------------
  -- U2 主控模块
  ------------------------------------------------------------------------------
  U2 : shouhuoji PORT MAP(
         clk     => co1,          -- 10Hz 节拍当时钟
         rst     => rst2,
         coin    => coin2,
         choose  => pp,
         price   => price1,
         need    => need1,
         mout    => mout1,
         suc     => suc2,
         showout => showout2
       );

  ------------------------------------------------------------------------------
  -- U3 显示译码模块（纯组合逻辑，教材图 7.15）
  ------------------------------------------------------------------------------
  U3 : xianshi PORT MAP(
         price => price1,
         need  => need1,
         mout  => mout1,
         I1    => I1_i,
         I2    => I2_i,
         I3    => I3_i
       );

  -- 把内部的三路段码送到监视端口，供 Waveform.vwf 观察
  I1 <= I1_i;
  I2 <= I2_i;
  I3 <= I3_i;

  ------------------------------------------------------------------------------
  -- 1kHz 轮显计数：00 -> 01 -> 10 -> 11 -> 00 ...
  ------------------------------------------------------------------------------
  PROCESS(scan1)
  BEGIN
    IF scan1'EVENT AND scan1='1' THEN
      dsel <= dsel + 1;
    END IF;
  END PROCESS;

  ------------------------------------------------------------------------------
  -- 把三路七段码轮流送到板上的段码/位码
  --   Ix 是 "g f e d c b a"（Ix(0)=a），和板上 seg[0]=a ... seg[6]=g 一一对应，
  --   所以直接拼：seg <= '0' & Ix （seg[7] 是 dp，这里不带小数点，置 0）
  --   sel 取 000/001/010 表示第 1/2/3 位数码管，具体哪一位亮以板上实测为准：
  --   如果整排数码管全亮或全灭，把 sel_r 取反（或改用 111/110/101）。
  ------------------------------------------------------------------------------
  PROCESS(dsel, I1_i, I2_i, I3_i)
  BEGIN
    CASE dsel IS
      WHEN "00"   => seg_r <= '0' & I1_i; sel_r <= "000";   -- 第 1 位：商品价格
      WHEN "01"   => seg_r <= '0' & I2_i; sel_r <= "001";   -- 第 2 位：需要补交的钱数
      WHEN OTHERS => seg_r <= '0' & I3_i; sel_r <= "010";   -- 第 3 位：找零钱数
    END CASE;
  END PROCESS;

  seg <= seg_r;
  sel <= sel_r;

END rtl;
