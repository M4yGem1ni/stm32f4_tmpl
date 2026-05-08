# STM32F4 模板：C++ + Clang + CMake

基于 **C++** + **Clang** + **CMake** 的 STM32F4 裸机固件模板，使用 STM32CubeF4 HAL/CMSIS 库。

## 为什么用 Clang

- 兼容 **clangd**，提供准确的代码高亮/补全/跳转
- 搭配 Ninja 编译速度快
- 底层链接和运行时库仍使用 GCC (`arm-none-eabi-gcc` 提供 newlib + libgcc)

## 安装依赖

```bash
sudo pacman -S clang lld cmake ninja arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib openocd arm-none-eabi-gdb
```

## 快速开始

```bash
# 1. 下载 CMSIS/HAL 库到 lib/
git clone --depth 1 --branch v6.1.0  https://github.com/ARM-software/CMSIS_6.git                    lib/CMSIS/Core
git clone --depth 1 --branch v2.6.8  https://github.com/STMicroelectronics/cmsis_device_f4.git       lib/CMSIS/Device
git clone --depth 1 --branch v1.8.2  https://github.com/STMicroelectronics/stm32f4xx_hal_driver.git  lib/STM32F4xx_HAL_Driver

# 2. 配置并编译
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=toolchain/arm-none-eabi-clang.cmake \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -G Ninja
cmake --build build
ln -sf build/compile_commands.json .   # 启用 clangd

# 3. 烧录 (ST-Link)
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c "program build/stm32f4-blinky.elf verify reset exit"
```

## 切换芯片型号

通过 CMake 参数或修改 `CMakeLists.txt` 顶部：

```bash
cmake -B build -DSTM32_CHIP=STM32F407xx ...
```

并为你的芯片创建对应的链接脚本 `linker/<STM32_CHIP>.ld`（复制现有脚本，调整内存大小即可）。

## 添加 HAL 模块

在 `include/stm32f4xx_hal_conf.h` 中启用模块：

```c
#define HAL_UART_MODULE_ENABLED
#include "stm32f4xx_hal_uart.h"
```

在 `CMakeLists.txt` 的 `HAL_SOURCES` 中添加对应源文件：

```cmake
${HAL_SRC_DIR}/stm32f4xx_hal_uart.c
```

## 目录结构

```
├── CMakeLists.txt
├── toolchain/arm-none-eabi-clang.cmake   # 交叉编译工具链
├── linker/STM32F405xx.ld                 # 链接脚本
├── include/stm32f4xx_hal_conf.h          # HAL 配置
├── src/main.cpp                          # 入口 (C++，使用 C++17)
├── lib/                                  # CMSIS + HAL（需手动下载）
└── build/                                # 构建输出
```

## 调试

### VS Code 调试（推荐）

**安装插件**：项目 `.vscode/extensions.json` 已推荐 `Cortex-Debug` 和 `clangd`。

**配置 CMake**（Debug 模式，包含调试符号）：

```bash
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=toolchain/arm-none-eabi-clang.cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -G Ninja
```

**工作流程**：

1. 点击行号左侧添加断点（红点）
2. 按 `F5` 启动调试
   - Cortex-Debug 自动启动 OpenOCD 作为 GDB 服务器
   - 编译固件（如代码有改动）
   - Flash 烧录并停在 `main()` 入口
3. `F10` 单步跳过 / `F11` 单步进入 / `F5` 继续运行
4. 左侧 "CORTEX-DEBUG" 面板可查看外设寄存器值

**SVD 外设寄存器视图**（可选）：

```bash
# 下载 SVD 文件到 .vscode/，调试时可以图形化查看 GPIO、RCC 等寄存器
curl -o .vscode/STM32F405.svd https://raw.githubusercontent.com/posborne/cmsis-svd/master/data/STMicro/STM32F405.svd
```

### 终端调试

```bash
# 终端 1: 启动 OpenOCD
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg

# 终端 2: GDB 连接
arm-none-eabi-gdb build/stm32f4-blinky \
    -ex "target extended-remote :3333" \
    -ex "monitor reset halt" \
    -ex "load" \
    -ex "break main" \
    -ex "continue"
```

## extern "C" 使用规则

嵌入式 C++ 和汇编/C 混合开发的核心问题：

### 为什么需要

C++ 编译器会对函数名做**名字改编**（name mangling）以支持重载。例如 `void foo(int)` 编译后符号变为 `_Z3fooi`。而启动文件（汇编）、HAL 库（C）都是按 C 方式编译，只认识原始符号名 `foo`。

`extern "C"` 告诉 C++ 编译器：这段代码用 C 的方式生成符号名，不要改编。

### 必须使用 extern "C" 的场景

#### 1. 中断处理函数

启动文件中以 C 符号名引用的中断向量：

```cpp
// startup_stm32f405xx.s 中:
//   .weak  SysTick_Handler
//   .word  SysTick_Handler

extern "C" void SysTick_Handler(void)     // 去掉 extern "C" → 链接失败
{
    HAL_IncTick();
}

extern "C" void USART1_IRQHandler(void)   // 同样必须
{
    // ...
}
```

如果忘记加，编译后符号变成 `_Z16SysTick_Handlerv`，启动文件找不到 `SysTick_Handler`，链接报错 `undefined symbol`。

#### 2. C HAL 库的回调函数

HAL 的回调都是弱定义（`__weak`），默认是空函数，用户重写需要用 C 符号名匹配：

```cpp
// HAL 库中以 C 方式定义: void HAL_GPIO_EXTI_Callback(uint16_t pin)

extern "C" void HAL_GPIO_EXTI_Callback(uint16_t pin)  // 去掉 → 不会报错，但不会被调用
{
    if (pin == GPIO_PIN_13) {
        // 处理按键中断
    }
}
```

这里忘了加不会报编译/链接错误——因为 HAL 的 `__weak` 版本已经存在，链接器找到 C 符号，你的 C++ 版本变成了另一个马甲符号，静静躺在固件里但永远不会被调用。

#### 3. main 函数

启动文件调用 `bl main`，main 必须有 C 符号名：

```cpp
extern "C" int main(void)     // C++ 文件中必须
{
    // ...
}
```

`.cpp` 文件不加 `extern "C"` 编译后符号为 `_Z4mainv`，启动代码找不到。`.c` 文件不需要。

#### 4. FreeRTOS 任务函数

FreeRTOS 通过函数指针调用任务，C ABI 兼容即可，不需要 `extern "C"`：

```cpp
// 不需要 extern "C" — FreeRTOS 通过 void* task_func(void*) 调用，
// 函数指针在同一个 C++ 编译单元内，符号自己会找到
void MyTask(void *param)     // OK，不需要 extern "C"
{
    for(;;) { ... }
}
```

但是如果任务函数在 `.cpp` 文件中，创建任务时可能遇到类型转换问题——需要用 `reinterpret_cast` 或将其声明为 `extern "C"` 以匹配 FreeRTOS 的 C 函数指针类型。

### 不需要使用 extern "C" 的场景

| 场景 | 原因 |
|---|---|
| C++ 类方法互相调用 | 编译器自动处理 |
| `#include "stm32f4xx_hal.h"` | 头文件自带 `extern "C"` 保护 |
| `#include "cmsis_gcc.h"` | CMSIS 头文件自带 |
| 纯 C++ 模块内部 | 不需要被 C/汇编访问 |
| C++ 模板 / constexpr | 编译期解决，无符号 |

### 常用写法

```cpp
// 方式 1: 逐个包裹
extern "C" void SysTick_Handler(void) { ... }

// 方式 2: 批量包裹
extern "C" {
    void SysTick_Handler(void) { ... }
    void USART1_IRQHandler(void) { ... }
    int main(void) { ... }
}

// 方式 3: 头文件中声明（自己写的 C 库给 C++ 用）
#ifdef __cplusplus
extern "C" {
#endif

void my_c_function(int param);

#ifdef __cplusplus
}
#endif
```

### 忘了加的表现

| 症状 | 原因 |
|---|---|
| `undefined reference to 'SysTick_Handler'` | 中断处理没加 extern "C" |
| 中断回调写了但永远不触发 | 回调函数签名对了但符号名不匹配 |
| `undefined reference to 'main'` | main 没加 extern "C" |

## 注意事项

- `-rtlib=libgcc` 是**关键参数**：Arch 的 clang 不含 ARM 裸机的 compiler-rt，必须使用 GCC 的 libgcc 替代
- `main.cpp` 中的 `_init`/`_fini`/`_write`/`_read` 桩函数不要删除
- 链接脚本中 `.bss` 和 `._user_heap_stack` 标为 `NOLOAD`，否则 `.bin` 文件会异常巨大
