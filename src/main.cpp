#include "stm32f4xx_hal.h"

// ---- bare-metal C++ stubs --------------------------------------------------

extern "C" {
    void _init(void) {}
    void _fini(void) {}
    int _write(int fd, char *buf, int len) { (void)fd; (void)buf; return len; }
    int _read(int fd, char *buf, int len)  { (void)fd; (void)buf; return len; }
}

// ---- application -----------------------------------------------------------

class Led
{
public:
    Led(GPIO_TypeDef *port, uint16_t pin)
        : _port(port), _pin(pin)
    {
        GPIO_InitTypeDef cfg = {
            .Pin   = _pin,
            .Mode  = GPIO_MODE_OUTPUT_PP,
            .Pull  = GPIO_NOPULL,
            .Speed = GPIO_SPEED_FREQ_LOW,
        };
        HAL_GPIO_Init(_port, &cfg);
    }

    void on()  { HAL_GPIO_WritePin(_port, _pin, GPIO_PIN_SET); }
    void off() { HAL_GPIO_WritePin(_port, _pin, GPIO_PIN_RESET); }
    void toggle() { HAL_GPIO_TogglePin(_port, _pin); }

private:
    GPIO_TypeDef *_port;
    uint16_t _pin;
};

static void SystemClock_Config()
{
    HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq() / 1000);
}

extern "C" int main(void)
{
    HAL_Init();
    SystemClock_Config();
    __HAL_RCC_GPIOA_CLK_ENABLE();

    Led led(GPIOA, GPIO_PIN_5);

    while (1) {
        led.toggle();
        HAL_Delay(500);
    }
}

extern "C" void SysTick_Handler(void)
{
    HAL_IncTick();
}
