cmake_minimum_required(VERSION 3.21)

# =============================================================================
# STM32_CHIP: 选择目标芯片型号
# 支持: STM32F405xx, STM32F407xx, STM32F415xx, STM32F417xx,
#       STM32F427xx, STM32F429xx, STM32F437xx, STM32F439xx,
#       STM32F401xC, STM32F401xE, STM32F410Rx, STM32F410Cx, STM32F410Tx,
#       STM32F411xE, STM32F412Cx, STM32F412Rx, STM32F412Vx, STM32F412Zx,
#       STM32F413xx, STM32F423xx, STM32F446xx, STM32F469xx, STM32F479xx
# =============================================================================
set(STM32_CHIP STM32F405xx CACHE STRING "Target STM32F4 chip family")

project(stm32f4-blinky C ASM CXX)

# ---- Compile definitions ----
# Note: __FPU_PRESENT is already defined by the device header
add_compile_definitions(${STM32_CHIP})
add_compile_definitions(USE_HAL_DRIVER ARM_MATH_CM4)

# ---- Chip-specific settings ----
# Derive lowercase chip name for startup/linker filenames
string(TOLOWER ${STM32_CHIP} STM32_CHIP_LOWER)

set(STARTUP_FILE lib/CMSIS/Device/Source/Templates/gcc/startup_${STM32_CHIP_LOWER}.s)
set(SYSTEM_FILE  lib/CMSIS/Device/Source/Templates/system_stm32f4xx.c)
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/linker/${STM32_CHIP}.ld)

# ---- App sources (add your application .cpp / .c files here) ----
set(APP_SOURCES
    ${STARTUP_FILE}
    ${SYSTEM_FILE}
    src/main.cpp
)

# ---- HAL sources (add more as needed for your peripherals) ----
set(HAL_SRC_DIR lib/STM32F4xx_HAL_Driver/Src)
set(HAL_SOURCES
    ${HAL_SRC_DIR}/stm32f4xx_hal.c
    ${HAL_SRC_DIR}/stm32f4xx_hal_cortex.c
    ${HAL_SRC_DIR}/stm32f4xx_hal_rcc.c
    ${HAL_SRC_DIR}/stm32f4xx_hal_gpio.c
    ${HAL_SRC_DIR}/stm32f4xx_hal_pwr.c
    ${HAL_SRC_DIR}/stm32f4xx_hal_pwr_ex.c
)

# ---- Executable ----
add_executable(${PROJECT_NAME}
    ${APP_SOURCES}
    ${HAL_SOURCES}
)

# ---- Include directories ----
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/lib/CMSIS/Core/Include
    ${CMAKE_SOURCE_DIR}/lib/CMSIS/Device/Include
    ${CMAKE_SOURCE_DIR}/lib/STM32F4xx_HAL_Driver/Inc
)

# ---- Linker script ----
target_link_options(${PROJECT_NAME} PRIVATE
    -T ${LINKER_SCRIPT}
    -Wl,-Map=${PROJECT_BINARY_DIR}/${PROJECT_NAME}.map
)

# ---- Libraries (order matters) ----
target_link_libraries(${PROJECT_NAME} PRIVATE
    c
    m
    gcc
    nosys
    stdc++
)

# ---- Post-build: generate .hex and .bin ----
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${PROJECT_NAME}>
            $<TARGET_FILE_DIR:${PROJECT_NAME}>/${PROJECT_NAME}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${PROJECT_NAME}>
            $<TARGET_FILE_DIR:${PROJECT_NAME}>/${PROJECT_NAME}.bin
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${PROJECT_NAME}>
    COMMENT "Generating .hex, .bin and size report"
)
