# Toolchain file: Clang for ARM bare-metal (arm-none-eabi)
# Uses GCC toolchain for linker, newlib, and libgcc (compiler-rt unavailable for ARM on Arch)

set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(CMAKE_C_COMPILER                clang)
set(CMAKE_C_COMPILER_TARGET         arm-none-eabi)
set(CMAKE_ASM_COMPILER              clang)
set(CMAKE_ASM_COMPILER_TARGET       arm-none-eabi)
set(CMAKE_CXX_COMPILER              clang++)
set(CMAKE_CXX_COMPILER_TARGET       arm-none-eabi)

# Prevent CMake from trying to link a test executable during compiler detection
set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY)

# ---- Paths ----
set(GCC_TOOLCHAIN_ROOT              /usr)
set(GCC_ARM_NONE_EABI_SYSROOT       /usr/arm-none-eabi)

# Auto-detect GCC version
execute_process(COMMAND arm-none-eabi-gcc -dumpversion
    OUTPUT_VARIABLE GCC_ARM_NONE_EABI_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _gcc_version_result
)
if(_gcc_version_result OR NOT GCC_ARM_NONE_EABI_VERSION)
    message(FATAL_ERROR "arm-none-eabi-gcc not found. Install: sudo pacman -S arm-none-eabi-gcc")
endif()

# Auto-detect multilib for Cortex-M4F
execute_process(COMMAND arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -print-multi-directory
    OUTPUT_VARIABLE GCC_MULTILIB_SUBDIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT GCC_MULTILIB_SUBDIR)
    message(FATAL_ERROR "Cannot determine GCC multilib directory for Cortex-M4F")
endif()

# ---- Common compile flags (must be a single string, not a CMake list) ----
set(COMMON_FLAGS "--gcc-toolchain=${GCC_TOOLCHAIN_ROOT}")
string(APPEND COMMON_FLAGS " --sysroot=${GCC_ARM_NONE_EABI_SYSROOT}")
string(APPEND COMMON_FLAGS " -mcpu=cortex-m4 -mthumb")
string(APPEND COMMON_FLAGS " -mfloat-abi=hard -mfpu=fpv4-sp-d16")

# Note: chip-specific compile definitions (STM32F405xx, USE_HAL_DRIVER, etc.)
# are set in CMakeLists.txt so they can reference the STM32_CHIP variable.

# ---- C flags ----
set(CMAKE_C_FLAGS_INIT "${COMMON_FLAGS}" CACHE STRING "" FORCE)
string(APPEND CMAKE_C_FLAGS_INIT
    " -ffunction-sections -fdata-sections"
    " -fno-common -fmessage-length=0"
    " -fno-exceptions -fsigned-char"
    " -std=gnu11"
)

# ---- C++ flags ----
set(CMAKE_CXX_FLAGS_INIT "${COMMON_FLAGS}" CACHE STRING "" FORCE)
string(APPEND CMAKE_CXX_FLAGS_INIT
    " -ffunction-sections -fdata-sections"
    " -fno-common -fmessage-length=0"
    " -fno-exceptions -fno-rtti"
    " -fsigned-char"
    " -Wno-main"
    " -std=gnu++17"
)

# ---- Assembler flags (preprocess with C preprocessor for #include) ----
set(CMAKE_ASM_FLAGS_INIT "${COMMON_FLAGS} -x assembler-with-cpp" CACHE STRING "" FORCE)

# ---- Linker flags ----
set(LIBGCC_DIR "${GCC_TOOLCHAIN_ROOT}/lib/gcc/arm-none-eabi/${GCC_ARM_NONE_EABI_VERSION}/${GCC_MULTILIB_SUBDIR}")
set(NEWLIB_DIR "${GCC_ARM_NONE_EABI_SYSROOT}/lib/${GCC_MULTILIB_SUBDIR}")

set(CMAKE_EXE_LINKER_FLAGS_INIT "${COMMON_FLAGS}" CACHE STRING "" FORCE)
string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT
    " -fuse-ld=lld"
    " -rtlib=libgcc"
    " --unwindlib=none"
    " -nostartfiles -nodefaultlibs -nostdlib"
    " -Wl,-L${LIBGCC_DIR}"
    " -Wl,-L${NEWLIB_DIR}"
)

# ---- Tools from GCC toolchain ----
set(CMAKE_OBJCOPY arm-none-eabi-objcopy CACHE FILEPATH "")
set(CMAKE_OBJDUMP arm-none-eabi-objdump CACHE FILEPATH "")
set(CMAKE_SIZE     arm-none-eabi-size     CACHE FILEPATH "")

# ---- Search only sysroot ----
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
