# 实验2 B组：miniRV SoC

本分支在实验1完整单周期 CPU 的基础上实现指导书要求的 SoC 数据通路：

`cpu_core -> ICache/DCache -> axi_master -> AXI bridge -> 主存/外设`

## 已实现模块

- `ICache.v`：1 KiB 直接映射指令 Cache，16 B Cache 行，缺失时使用 4 拍 AXI 突发读取。
- `DCache.v`：1 KiB 直接映射数据 Cache，读分配、写穿透、不写分配；I/O 地址采用 Uncached 单拍访问。
- `axi_master.v`：三段式状态控制，支持 AXI4 的 AR/R 与 AW/W/B 通道；仲裁优先级为数据写、数据读、取指。
- `soc_axi_bridge.v`：普通地址访问主存，最高 64 KiB 的 `0xFFFF_xxxx` 地址访问外设。
- `soc_bram_axi.v`：板级 AXI 主存适配器，复用原工程中已经初始化的 `DRAM` Block Memory IP。
- `soc_peripherals_axi.v`：外设 AXI 从设备和地址译码。
- 拨码开关、LED、八位数码管、115200 波特率 UART、64 位计时器五种外设。

## I/O 地址

| 地址 | 属性 | 功能 |
| --- | --- | --- |
| `0xFFFF0000` | 读 | 读取 16 位拨码开关 |
| `0xFFFF1000` | 写 | 控制 16 位 LED |
| `0xFFFF2000` | 写 | 显示 8 个十六进制数码管 |
| `0xFFFF3000` | 读 | UART RX 数据 |
| `0xFFFF3004` | 写 | UART TX 数据 |
| `0xFFFF3008` | 读 | UART 状态 |
| `0xFFFF300C` | 写 | UART FIFO 复位控制 |
| `0xFFFF4000` | 读 | 计时器低 32 位 |
| `0xFFFF4008` | 读 | 计时器高 32 位 |

## 验证

AXI Trace 使用 `RUN_TRACE` 条件编译，按指导书要求绕过板级外设桥，直接连接 Trace 提供的 `bram_axi`。将 `src/rtl` 中的 HDL 复制到 `cdp-tests/mySoC` 后运行：

```sh
make build
make run TEST=lw
make run TEST=sw
```

外设自测使用 Verilator：

```sh
verilator --binary --timing -Wno-fatal -Isrc/rtl \
  --top-module soc_peripherals_tb \
  src/sim/soc_peripherals_tb.v src/rtl/soc_peripherals_axi.v \
  src/rtl/switch_io.v src/rtl/led_io.v src/rtl/digled_io.v \
  src/rtl/timer_io.v src/rtl/uart_io.v
./obj_dir/Vsoc_peripherals_tb
```

## Vivado 与下板

打开 `miniRV.xpr` 即可看到新增 RTL。板级构建复用 `DRAM` IP，因此请把 C_TEST 或 CoreMark 生成的 `.coe` 文件载入 `DRAM`，重新生成 IP 输出文件，然后再综合、实现和生成比特流。UART 和时钟均按 50 MHz 配置；修改 CPU 时钟后，需要同步修改 `uart_io.v` 的 `CLK_FREQ` 参数及 CoreMark 的 `MHZ`。

`software/soc_io.h` 提供 MMIO 和 UART/计时器访问函数，`software/io_test.c` 会把拨码值显示到 LED、把计时器显示到数码管，并通过串口进行字符回显。可将这两个文件复制到课程 C_TEST 工程中编译。

下板前必须在装有 Vivado 的机器上完成综合实现，确认时序报告无违例，再使用 EGO1 实板验证 UART、拨码、LED 和数码管。
