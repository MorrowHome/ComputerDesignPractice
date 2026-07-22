# SoC 官方 C_TEST

本目录由课程提供的 `Sources/c_test_rv_stu.tar.gz` 解包得到，并已按照本
SoC 的 UART 寄存器定义补完以下逻辑：

- 控制寄存器写 `0x3`，清空 TX/RX；
- 状态寄存器 bit 3 为 TX full，发送前等待其清零；
- 状态寄存器 bit 0 为 RX valid，接收前等待其置位；
- UART Test 的字符串逐字节发送；
- 修复格式化输入首次访问空缓冲区和排序测试时钟宏名称问题。

测试程序中的 `20XXXXXXXX` 仍需替换为本人学号。

## 编译

在装有 RISC-V GNU 裸机工具链的 Linux 环境执行，例如：

```sh
cd 0_uart_test
sh compile.sh
```

脚本默认使用 `riscv32-unknown-elf-gcc`、`objdump` 和 `objcopy`。也可以
通过 `CC`、`OBJDUMP`、`OBJCOPY`、`CFLAGS_EXTRA` 环境变量指定兼容工具。
成功后会生成 `main.coe`、`main.bin` 和 `main.s`。

将 `main.coe` 载入 Vivado 的 `DRAM` Block Memory IP，重新生成 Output
Products 后再运行综合、实现和生成 bitstream。

建议依次验证：

1. `0_uart_test`：UART、开关、LED 和数码管；
2. `1_formatIO_test`：格式化输入输出；
3. `2_sort_test`：定时器、排序和堆分配；
4. `4_coremark`：性能测试。

`3_ddr_test`、`compile_use_ddr.sh` 和 `5_llama2.c` 依赖 DDR 控制器。当前
SoC 分支只实现了指导书基本 SoC 所需的片上主存和五类外设，没有实现
DDR3 控制器，因此这些 DDR 测试不属于当前可下板验证范围。
