#include "soc_io.h"

static void put_string(const char *text)
{
    while (*text)
        soc_uart_putc(*text++);
}

static void put_hex32(uint32_t value)
{
    static const char digits[] = "0123456789ABCDEF";
    int shift;
    for (shift = 28; shift >= 0; shift -= 4)
        soc_uart_putc(digits[(value >> shift) & 0xFu]);
}

int main(void)
{
    uint32_t switches;
    uint32_t timer_low;

    soc_uart_init();
    put_string("miniRV SoC I/O test\r\n");

    switches = SOC_SWITCH;
    SOC_LED = switches;

    timer_low = (uint32_t)soc_timer_read();
    SOC_DIGLED = timer_low;

    put_string("switch=0x");
    put_hex32(switches);
    put_string(" timer=0x");
    put_hex32(timer_low);
    put_string("\r\nType characters to echo:\r\n");

    for (;;) {
        char ch = soc_uart_getc();
        soc_uart_putc(ch);
        SOC_LED = (uint8_t)ch;
        SOC_DIGLED = (uint32_t)soc_timer_read();
    }
}
