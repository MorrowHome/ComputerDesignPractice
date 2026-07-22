#ifndef SOC_IO_H
#define SOC_IO_H

#include <stdint.h>

#define MMIO32(address) (*(volatile uint32_t *)(uintptr_t)(address))

#define SOC_SWITCH       MMIO32(0xFFFF0000u)
#define SOC_LED          MMIO32(0xFFFF1000u)
#define SOC_DIGLED       MMIO32(0xFFFF2000u)
#define SOC_UART_RX      MMIO32(0xFFFF3000u)
#define SOC_UART_TX      MMIO32(0xFFFF3004u)
#define SOC_UART_STATUS  MMIO32(0xFFFF3008u)
#define SOC_UART_CTRL    MMIO32(0xFFFF300Cu)
#define SOC_TIMER_LOW    MMIO32(0xFFFF4000u)
#define SOC_TIMER_HIGH   MMIO32(0xFFFF4008u)

static inline void soc_uart_init(void)
{
    SOC_UART_CTRL = 0x3u;
}

static inline void soc_uart_putc(char ch)
{
    while (SOC_UART_STATUS & (1u << 3)) {
    }
    SOC_UART_TX = (uint32_t)(uint8_t)ch;
}

static inline char soc_uart_getc(void)
{
    while (!(SOC_UART_STATUS & 1u)) {
    }
    return (char)(SOC_UART_RX & 0xFFu);
}

static inline uint64_t soc_timer_read(void)
{
    uint32_t high_before;
    uint32_t low;
    uint32_t high_after;

    do {
        high_before = SOC_TIMER_HIGH;
        low = SOC_TIMER_LOW;
        high_after = SOC_TIMER_HIGH;
    } while (high_before != high_after);

    return ((uint64_t)high_after << 32) | low;
}

#endif
