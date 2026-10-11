# 自动售货机（Quartus II 13.0 / Cyclone IV E EP4CE10F17C8N）

## 一、目录结构与层次

```
vending_machine\
├── vending_machine.qpf   Quartus 工程文件（双击打开）
├── vending_machine.qsf   器件、源文件、顶层、引脚锁定
├── dingceng.vhd          系统顶层：例化三个子模块 + 三轮换扫描
├── fp.vhd                时钟模块：1MHz -> 1kHz 扫描 + 10Hz 节拍
├── shouhuoji.vhd         主控模块：状态机（投币/选货/找零/出货）
├── xianshi.vhd           显示模块：4 位金额 -> 七段码（教材图 7.15）
├── Waveform.vwf          顶层功能仿真波形（clk20/coin2/pp/rst2/I1/I2/I3/suc2/showout2）
└── README.md             本文件
```

```
dingceng（系统顶层）
 ├── U1  fp         CLK20(1MHz) ──> clk_scan(1kHz) + co(10Hz 脉冲)
 ├── U2  shouhuoji  clk=co, coin2/rst2/pp ──> price/need/mout(各 4bit)、suc2、showout2
 ├── U3  xianshi    price/need/mout ──> I1/I2/I3（各 7bit 七段码，纯组合逻辑）
 └── 轮显级（写在 dingceng 里）：1kHz 时钟把 I1/I2/I3 轮流送到 seg/sel
```

## 二、模块端口

| 模块 | 输入 | 输出 |
|---|---|---|
| `fp` | `CLK20`（1MHz） | `clk_scan`（1kHz 方波）、`co`（10Hz 窄脉冲） |
| `shouhuoji` | `clk`(接 `co`)、`rst`(低有效)、`coin(1:0)`、`choose(3:0)` | `price`、`need`、`mout`（各 4bit）、`suc`、`showout` |
| `xianshi` | `price`、`need`、`mout` | `I1`、`I2`、`I3`（各 7bit，位序 g f e d c b a） |

## 三、引脚锁定（已写入 vending_machine.qsf）

| 端口 | 引脚 | 说明 |
|---|---|---|
| `clk20` | PIN_M1 | 主板时钟，**跳线设 1MHz** |
| `rst2` | PIN_P6 | 拨码开关 K11，低电平复位 |
| `coin2[1]` | PIN_T10 | 拨码开关 K1，投币加 1 |
| `coin2[0]` | PIN_R10 | 拨码开关 K0，投币加 5 |
| `pp[0..3]` | PIN_R9 / T9 / N9 / T8 | 拨码开关 K2/K3/K4/K5，选货（独热码） |
| `seg[0..7]` | PIN_D16 / E9 / C9 / D9 / E10 / C11 / D11 / D12 | a b c d e f g dp |
| `sel[0..2]` | PIN_F15 / C16 / D15 | 位码（板上经 3-8 译码） |
| `suc2` | PIN_N6 | LED0，交易成功 |
| `showout2` | PIN_N5 | LED1，找零成功 |
| `I1 / I2 / I3` | 不锁引脚 | 只给 Waveform.vwf 功能仿真看波形 |

> 引脚编号来自《EDA 技术及应用设计指导书》表 1-1、表 1-2、表 2-1。
> 工程设置了 `RESERVE_ALL_UNUSED_PINS`，未用引脚不会默认接地。

## 四、当前进度

| 文件 | 状态 |
|---|---|
| `fp.vhd` | ✅ 已实现。分频比是架构里两个 CONSTANT：`SCAN_DIV=1000`、`TICK_DIV=100000`（对应 1MHz 输入） |
| `xianshi.vhd` | ✅ 已实现。0~F 十六进制七段码表，纯组合逻辑 |
| `shouhuoji.vhd` | ✅ 能编译能跑。状态机 a(待机)→b(投币)→c(继续投币)→d(出货)/g(退币)，价格表 2/3/4/6 |
| `dingceng.vhd` | ✅ 已实现。含三轮换扫描，驱动板上 seg/sel |

## 五、上机流程

1. Quartus 13.0 → File → Open Project → `vending_machine.qpf`
2. Processing → Start Compilation（生成 `output_files\vending_machine.sof`）
3. Assignments → Pin Planner 核对上面的引脚表
4. Tools → Programmer → USB-Blaster → JTAG → Start
5. **把主板时钟跳线设为 1MHz**，然后：
   - 先拨 K2/K3/K4/K5 中的一个选货（独热码，一次只拨一个），数码管第 1 位显示价格；
   - 再拨 K1 / K0 投币，第 2 位显示还需要补交多少；够了 LED0 亮，第 3 位显示找零；
   - K11 拨到 0 一侧复位。

## 六、仿真（Waveform.vwf）要注意的三点

1. **复位**：现在 `rst2` 在整个 1000 ns 里都是 0（低电平复位 = 一直在复位），状态机不会动。
   仿真时把 `rst2` 改成先 0 一小段、之后拉高到 1。
2. **时长**：`clk20` 现在是 10 ns 周期，而 `SCAN_DIV=1000`（半个扫描周期 = 5 µs）、
   `TICK_DIV=100000`（一个节拍 = 1 ms）。现在的 `DATA_DURATION=1000 ns` 太短，
   至少要拉到 **2 ms** 才看得到一个完整节拍。
   想快点看到动作，可以临时把 `fp.vhd` 里 `TICK_DIV` 改成 100、`SCAN_DIV` 改成 10，
   仿真完再改回来（上机必须用 1MHz 对应的原值）。
3. **激励**：`pp` 现在只有 `pp[3]` 在 10~30 ns 给了一个 20 ns 宽的高电平。
   `pp[3]` 对应商品 4（价格 6），要配合上面第 1、2 点放开复位、拉长时间，才看得到完整交易过程。

## 七、还没解决的两件事（你定了我就改）

1. **投币会被重复计数**：`shouhuoji.vhd` 在状态 b/c 里是"每个节拍看一次 coin，
   只要开关还拨着就加一次"，10Hz 节拍下按住 1 秒会加 10 次。
   常规做法是加一级边沿检测（记一个 `coin_r`，只在 `coin` 由 0 变 1 的那一拍加钱）。
2. **投币单位**：现在 `coin="10"` 加 1、`coin="01"` 加 5，价格是 2/3/4/6。
   若按"角"计（1 元 = 10 角），这几个数要一起改。

## 八、其它注意事项

- **数码管极性未实测**：`xianshi.vhd` 按"段码 1 = 点亮（共阴）"写；位码 `sel_r` 取 000/001/010，
  若板上 3-8 译码是低电平有效，整排会全亮或全灭 —— 把 `dingceng.vhd` 里 `sel_r` 取反（111/110/101）即可。
  先只拨一个开关看现象最快。
- **时钟跳线必须与 `fp.vhd` 的 CONSTANT 对应**（默认按 1MHz）。
  换档位时按 `分频比 = 跳线频率 / 目标频率` 重算这两个 CONSTANT。
- **机械开关有抖动**：目前没做去抖，快速拨动可能被识别成多次；和第七节第 1 条可以一起修。
- 第一次编译后会自动生成 `db\`、`incremental_db\`、`output_files\` 等目录，属正常现象。
