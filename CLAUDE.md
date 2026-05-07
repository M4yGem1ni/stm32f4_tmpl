# CLAUDE.md — STM32F4 Clang + CMake Template

## Project Overview

Bare-metal STM32F4 firmware template using **C++ (default)** + **Clang** compiler + **CMake** build system + STM32CubeF4 HAL/CMSIS. Targets Cortex-M4F (ARMv7E-M, hard float, FPv4-SP-D16).

## Language

Default: **C++17** (`-std=gnu++17 -fno-exceptions -fno-rtti`). C source files (.c) can be freely mixed in.

- **C++ files**: compiled with `clang++`, object files linked against `libstdc++`
- **HAL/CMSIS**: C sources compiled with `clang`, headers use `extern "C"` — safe to `#include` directly in C++

## Build System Architecture

### Toolchain Design (toolchain/arm-none-eabi-clang.cmake)

- **Compiler**: Clang with `--target=arm-none-eabi`
- **Library/Runtime**: GCC toolchain (newlib, libgcc)
- **Linker**: LLD (`-fuse-ld=lld`)
- **Critical flag**: `-rtlib=libgcc` — Arch's clang lacks ARM compiler-rt builtins, so we use GCC's libgcc
- **Path resolution**: `--gcc-toolchain=/usr` finds `arm-none-eabi-gcc` and its libraries; `--sysroot=/usr/arm-none-eabi` finds newlib
- GCC version and multilib path are **auto-detected** via `execute_process` (not hardcoded)
- `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` prevents CMake from failing compiler detection

### CMakeLists.txt

- `STM32_CHIP` cache variable (default `STM32F405xx`) controls:
  - Compile definition (e.g. `-DSTM32F405xx`)
  - Startup file (`startup_<chip_lower>.s`)
  - Linker script (`linker/<STM32_CHIP>.ld`)
- HAL sources are manually listed (minimal set: hal, cortex, rcc, gpio, pwr, pwr_ex)
- Post-build: objcopy generates `.hex` and `.bin`

### Linker Script (linker/STM32F405xx.ld)

- Memory layout varies per chip. Create new `.ld` files for different chips.
- `.bss` and `._user_heap_stack` are marked `NOLOAD` — required for correct `.bin` generation
- `/DISCARD/` section strips unused libc/libm/libgcc sections

## Key Configuration Points

### Adding a HAL peripheral module

1. `include/stm32f4xx_hal_conf.h`: add `#define HAL_<MODULE>_MODULE_ENABLED` and `#include "stm32f4xx_hal_<module>.h"`
2. `CMakeLists.txt`: add `${HAL_SRC_DIR}/stm32f4xx_hal_<module>.c` to `HAL_SOURCES`

### Switching target chip

1. Set `STM32_CHIP` in CMakeLists.txt or via `-DSTM32_CHIP=...` on cmake command line
2. Create a matching linker script at `linker/<STM32_CHIP>.ld` with correct memory sizes
3. Verify startup file exists at `lib/CMSIS/Device/Source/Templates/gcc/startup_<chip_lower>.s`

### Oscillator configuration

In `include/stm32f4xx_hal_conf.h`:
- `HSE_VALUE` — External high-speed oscillator (default 8 MHz)
- `HSI_VALUE` — Internal high-speed oscillator (16 MHz)
- `LSE_VALUE` — External low-speed oscillator (32.768 kHz)

## Common Operations

### Build

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=toolchain/arm-none-eabi-clang.cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G Ninja
cmake --build build
```

### Flash (OpenOCD + ST-Link)

```bash
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg -c "program build/stm32f4-blinky.elf verify reset exit"
```

### Debug

```bash
# Terminal 1
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg

# Terminal 2
arm-none-eabi-gdb build/stm32f4-blinky -ex "target extended-remote :3333" -ex "monitor reset halt"
```

## Important Conventions and Gotchas

- **`_init`/`_fini` stubs** in `main.cpp` are required. Without them, `__libc_init_array` (called from Reset_Handler) fails linking because `-nostartfiles` skips crti.o.
- **Newlib stubs**: `_write`, `_read` are provided as no-ops in `main.cpp`. For UART output, implement real versions.
- **`assert_param`**: HAL uses this macro extensively. Our config defines it as `((void)0)` (disabled). Enable `USE_FULL_ASSERT` in `stm32f4xx_hal_conf.h` for debug builds.
- **`__FPU_PRESENT`**: Do NOT pass via `-D` flag — the device header (`stm32f405xx.h`) already defines it. Duplicate definitions cause warnings.
- **HAL tick**: `SysTick_Handler` must call `HAL_IncTick()`. Defined in `main.cpp` with `extern "C"`, overrides the weak default in the startup file.
- **`-flto`**: Not enabled by default but compatible with this setup if desired.
- **`.bin` size**: If `.bin` grows huge (>100MB), check that `.bss` and `._user_heap_stack` have `NOLOAD` in the linker script.
- **Interrupt handlers**: Must use `extern "C"` linkage in C++ files so they match the startup file's symbol names.
- **Mixing C/C++**: C source files can be added freely to `APP_SOURCES`. HAL/CMSIS C APIs are already `extern "C"`-safe. For custom C headers used from C++, wrap in `#ifdef __cplusplus extern "C" { ... }`.

## Library Versions

| Library | Version | Source |
|---------|---------|--------|
| CMSIS Core | 6.1.0 | ARM-software/CMSIS_6 |
| CMSIS Device F4 | 2.6.8 | STMicroelectronics/cmsis_device_f4 |
| STM32F4 HAL | 1.8.2 | STMicroelectronics/stm32f4xx_hal_driver |

Libraries are stored in `lib/` and are NOT committed to git (add to `.gitignore` if desired).
