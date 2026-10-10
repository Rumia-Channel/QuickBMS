cmake_minimum_required(VERSION 3.25)

# The manifest toolchain must be selected before project() detects compilers.
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT})
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE FILEPATH "vcpkg toolchain")
endif()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
project(QuickBMS VERSION 0.12.0 LANGUAGES C CXX)

if(MSVC AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "QuickBMS uses GNU C extensions. Select the Visual Studio LLVM (ClangCL) toolset, e.g. cmake --preset windows.")
endif()
if(CMAKE_SIZEOF_VOID_P LESS 8)
    message(FATAL_ERROR "This fork requires a 64-bit target.")
endif()

option(QUICKBMS64 "Use 64-bit BMS integers and build quickbms64" ON)
find_package(ZLIB REQUIRED)
find_package(OpenSSL 3 REQUIRED)
find_package(Threads REQUIRED)
if(NOT WIN32)
    find_package(Iconv REQUIRED)
endif()

include(cmake/Sources.cmake)
# A single archive keeps legacy, unused implementations out of the final link
# while allowing codec-to-codec references without platform-specific link groups.
list(REMOVE_ITEM QUICKBMS_SOURCES src/quickbms.c)
add_library(quickbms_codecs STATIC ${QUICKBMS_SOURCES})
add_executable(quickbms src/quickbms.c)
set_target_properties(quickbms quickbms_codecs PROPERTIES
    C_STANDARD 90 C_STANDARD_REQUIRED YES C_EXTENSIONS YES
    CXX_STANDARD 17 CXX_STANDARD_REQUIRED YES CXX_EXTENSIONS YES)
set_target_properties(quickbms PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_BINARY_DIR}/bin>")
if(QUICKBMS64)
    target_compile_definitions(quickbms PRIVATE QUICKBMS64)
    target_compile_definitions(quickbms_codecs PRIVATE QUICKBMS64)
    set_target_properties(quickbms PROPERTIES OUTPUT_NAME quickbms64)
endif()

foreach(target quickbms quickbms_codecs)
    target_include_directories(${target} PRIVATE
        src src/libs/capstone/include src/libs/ecrypt/include
        src/libs/libcsc src/libs/ucl src/libs/ucl/include src/encryption src/extra
        src/libs/brieflz/include src/libs/brotli/include
        src/libs/lzo/include)
    target_compile_definitions(${target} PRIVATE
        CAPSTONE_HAS_ARM CAPSTONE_HAS_ARM64 CAPSTONE_HAS_MIPS
        CAPSTONE_HAS_POWERPC CAPSTONE_HAS_SPARC CAPSTONE_HAS_SYSZ
        CAPSTONE_HAS_X86 CAPSTONE_HAS_XCORE
        CAPSTONE_USE_SYS_DYN_MEM CAPSTONE_X86_ATT_DISABLE DENSITY_FORCE_INLINE=inline
        DISABLE_MCRYPT DISABLE_TOMCRYPT E_INVALIDARG=-1 LZHAM_ANSI_CPLUSPLUS
        MYDOWN_GLOBAL_COOKIE MYDOWN_SSL ZSTD_DISABLE_ASM _7ZIP_ST _7Z_TYPES_
        restrict=__restrict__)
    target_link_libraries(${target} PRIVATE ZLIB::ZLIB OpenSSL::SSL OpenSSL::Crypto Threads::Threads)
endforeach()
target_link_libraries(quickbms PRIVATE quickbms_codecs)
set_source_files_properties(
    src/libs/zlib/contrib/infback9/infback9.c
    src/libs/zlib/contrib/infback9/inftree9.c
    PROPERTIES INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/src/libs/zlib")
# LZHAM's include directory contains its own zlib.h facade. Keep it private
# to those translation units rather than shadowing the vcpkg zlib API.
foreach(source IN LISTS QUICKBMS_SOURCES)
    if(source MATCHES "^src/libs/lzham_codec/")
        set_source_files_properties("${source}" PROPERTIES INCLUDE_DIRECTORIES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/libs/lzham_codec/include;${CMAKE_CURRENT_SOURCE_DIR}/src/libs/lzham_codec/lzhamcomp;${CMAKE_CURRENT_SOURCE_DIR}/src/libs/lzham_codec/lzhamdecomp")
    endif()
endforeach()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64|x64)$" OR
   CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
    target_sources(quickbms_codecs PRIVATE ${QUICKBMS_X86_SOURCES})
    if(MSVC)
        target_compile_options(quickbms_codecs PRIVATE /clang:-msse2)
    else()
        target_compile_options(quickbms_codecs PRIVATE -msse2)
    endif()
endif()

if(WIN32)
    enable_language(RC)
    target_sources(quickbms PRIVATE src/res/quickbms.rc)
    target_sources(quickbms_codecs PRIVATE src/extra/MemoryModule.c)
    target_include_directories(quickbms PRIVATE src/res)
    set_property(DIRECTORY PROPERTY VS_STARTUP_PROJECT quickbms)
    # The application manifest is already embedded by quickbms.rc.
    target_link_options(quickbms PRIVATE /MANIFEST:NO)
    foreach(target quickbms quickbms_codecs)
        target_compile_definitions(${target} PRIVATE WIN32 _CRT_SECURE_NO_WARNINGS
            _CRT_NONSTDC_NO_WARNINGS NOMINMAX _WIN32_WINNT=0x0A00 WINVER=0x0A00)
    endforeach()
    target_link_libraries(quickbms PRIVATE ws2_32 winmm wininet comdlg32 shell32 advapi32 bcrypt user32 gdi32)
else()
    foreach(target quickbms quickbms_codecs)
        target_compile_definitions(${target} PRIVATE unix _FILE_OFFSET_BITS=64)
    endforeach()
    target_link_libraries(quickbms PRIVATE Iconv::Iconv ${CMAKE_DL_LIBS} m)
    if(APPLE)
        target_compile_definitions(quickbms PRIVATE FORCE_SATUR_SUB_128)
        target_compile_definitions(quickbms_codecs PRIVATE FORCE_SATUR_SUB_128)
    endif()
endif()

# Legacy codecs still contain K&R declarations and historical pointer types.
# Keep these diagnostics as warnings while modern compilers build the same code.
if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    foreach(target quickbms quickbms_codecs)
        target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:C>:-Wno-error=implicit-function-declaration>"
            "$<$<COMPILE_LANGUAGE:C>:-Wno-error=incompatible-pointer-types>"
            "$<$<COMPILE_LANGUAGE:C>:-Wno-error=int-conversion>"
            "$<$<COMPILE_LANGUAGE:C>:-Wno-error=incompatible-function-pointer-types>")
        if(MSVC)
            target_compile_options(${target} PRIVATE
                "$<$<COMPILE_LANGUAGE:C>:/clang:-std=gnu89>"
                "$<$<COMPILE_LANGUAGE:CXX>:/clang:-std=gnu++17>")
        endif()
    endforeach()
endif()

include(GNUInstallDirs)
install(TARGETS quickbms RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
