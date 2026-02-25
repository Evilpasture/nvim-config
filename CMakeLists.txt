cmake_minimum_required(VERSION 3.21) # VERSION 3.21+ supports C23 features better

project(ClickerDaemon LANGUAGES C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ==========================================================================
# COMPILER VALIDATION (Strict Clang/C23 enforcement)
# ==========================================================================

if(MSVC AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR 
        "\n"
        "ERROR: Friendship ended with MSVC (cl.exe).\n"
        "This is a C23-only zone. Please use Clang-cl or LLVM Clang.\n"
        "Current Compiler: ${CMAKE_C_COMPILER_ID}"
    )
endif()

# ==========================================================================
# COMPILER SETTINGS (C23)
# ==========================================================================

# Use the C23 standard
set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Define the executable from clicker.c
add_executable(clicker clicker.c)

# ==========================================================================
# WINDOWS MULTIMEDIA LINKING
# ==========================================================================

# Link the Windows Multimedia library (winmm.lib) for PlaySoundA
if(WIN32)
    target_link_libraries(clicker PRIVATE winmm)
endif()


# Get the absolute path to your sounds directory
set(SOUNDS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/sounds")

# Inject the paths as macros into clicker.c
target_compile_definitions(clicker PRIVATE
    SOUND_CLICK="${SOUNDS_DIR}/click.wav"
    SOUND_ENTER="${SOUNDS_DIR}/enter.wav"
    SOUND_SPACE="${SOUNDS_DIR}/space.wav"
)


# ==========================================================================
# COMPILER FLAGS (CLANG 22)
# ==========================================================================

if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    target_compile_options(clicker PRIVATE
        -O3             # Maximum optimization
        -Wall           # Enable all common warnings
        -Wextra         # Even more warnings
        -Wpedantic      # Ensure standard compliance
        -Wno-deprecated-declarations # Win32 headers can sometimes trigger these
    )
    
    # Optional: Enable Colorized Output in the terminal
    add_compile_options(-fcolor-diagnostics)
endif()

# Set output directory to current folder for easy access
set_target_properties(clicker PROPERTIES 
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)
