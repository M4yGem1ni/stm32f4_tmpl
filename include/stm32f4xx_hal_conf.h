#ifndef STM32F4XX_HAL_CONF_H
#define STM32F4XX_HAL_CONF_H

#ifdef __cplusplus
extern "C" {
#endif

/* ########################## Module Selection ############################## */
#define HAL_MODULE_ENABLED
#define HAL_CORTEX_MODULE_ENABLED
#define HAL_FLASH_MODULE_ENABLED
#define HAL_GPIO_MODULE_ENABLED
#define HAL_PWR_MODULE_ENABLED
#define HAL_RCC_MODULE_ENABLED

/* ########################## Oscillator Values ############################# */
#if !defined(HSE_VALUE)
  #define HSE_VALUE              8000000U
#endif
#if !defined(HSE_STARTUP_TIMEOUT)
  #define HSE_STARTUP_TIMEOUT     100U
#endif
#if !defined(HSI_VALUE)
  #define HSI_VALUE              16000000U
#endif
#if !defined(LSE_VALUE)
  #define LSE_VALUE               32768U
#endif
#if !defined(LSE_STARTUP_TIMEOUT)
  #define LSE_STARTUP_TIMEOUT     5000U
#endif

/* ########################## System Parameters ############################# */
#define TICK_INT_PRIORITY          0x0FU
#define USE_RTOS                  0U
#define PREFETCH_ENABLE           1U
#define INSTRUCTION_CACHE_ENABLE  1U
#define DATA_CACHE_ENABLE         1U

/* ########################## Assert Selection ############################## */
/* Uncomment to enable full assert (expensive, for debugging) */
/* #define USE_FULL_ASSERT 1U */

#ifdef USE_FULL_ASSERT
  #define assert_param(expr) ((expr) ? (void)0U : assert_failed((uint8_t *)__FILE__, __LINE__))
  void assert_failed(uint8_t *file, uint32_t line);
#else
  #define assert_param(expr) ((void)0U)
#endif

/* Include HAL modules */
#include "stm32f4xx_hal_def.h"
#include "stm32f4xx_hal_cortex.h"
#include "stm32f4xx_hal_flash.h"
#include "stm32f4xx_hal_gpio.h"
#include "stm32f4xx_hal_pwr.h"
#include "stm32f4xx_hal_rcc.h"

#ifdef __cplusplus
}
#endif

#endif /* STM32F4XX_HAL_CONF_H */
