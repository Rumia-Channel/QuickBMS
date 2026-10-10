# QuickBMS — 64-bit fork

QuickBMS extracts files from archives using format-specific BMS scripts. It also
supports compression, encryption, and reimporting modified files into an archive.
This fork of QuickBMS 0.12.0 targets **64-bit processes** and builds from source
with **CMake and vcpkg**.

Windows development uses **Visual Studio 2022 with clang-cl**. Linux and macOS
presets are also provided; final build verification is limited to Windows. See
[verification](#verification) for the exact scope.

## Contents

- [Requirements](#requirements)
- [Windows: Visual Studio 2022](#windows-visual-studio-2022)
- [Running QuickBMS](#running-quickbms)
- [Linux](#linux)
- [macOS](#macos)
- [Build options](#build-options)
- [Compatibility limits](#compatibility-limits)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Documentation and credits](#documentation-and-credits)

## Requirements

All builds require:

- A 64-bit target and a compatible Clang C/C++ toolchain.
- **CMake 3.25 or newer** and Git.
- A bootstrapped vcpkg checkout, with `VCPKG_ROOT` pointing to its directory.

[CMakePresets.json](CMakePresets.json) defines these native builds:

| Platform | Preset | Generator | Compiler |
| --- | --- | --- | --- |
| Windows x64 | `windows` | Visual Studio 17 2022 | clang-cl, MSVC ABI |
| Linux, native 64-bit architecture | `linux` | Ninja | Clang |
| macOS, Intel or Apple Silicon | `macos` | Ninja | Apple Clang |

[vcpkg.json](vcpkg.json) pins the dependency registry baseline. CMake installs
OpenSSL 3 and zlib automatically during configuration; a separate `vcpkg install`
step is not needed. Specialized, locally patched codecs remain in `src/libs` and
`src/compression`. No separate system LZO package or prebuilt 32-bit `.lib` is
required.

**Run the commands below from this repository's root.** If vcpkg is already
installed, skip cloning and bootstrapping it and set `VCPKG_ROOT` to that checkout.
The first configuration needs network access to obtain dependencies.

## Windows: Visual Studio 2022

### 1. Install the development tools

In Visual Studio Installer, select **Desktop development with C++**, a Windows
10/11 SDK, and these individual components:

- **C++ Clang Compiler for Windows**
  (`Microsoft.VisualStudio.Component.VC.Llvm.Clang`).
- **MSBuild support for the LLVM (clang-cl) toolset**
  (`Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset`).
- **C++ CMake tools for Windows**. Check `cmake --version`; it must be at least 3.25.

The compiler is **clang-cl with the MSVC ABI**, not MinGW. The legacy codecs use
GNU C extensions that Microsoft's `cl.exe` does not support. The preset uses
`x64-windows-static` dependencies and the static MSVC runtime. **WSL is not
required.**

### 2. Set up vcpkg

Open **Developer PowerShell for VS 2022**:

```powershell
git clone https://github.com/microsoft/vcpkg.git "$HOME\vcpkg"
& "$HOME\vcpkg\bootstrap-vcpkg.bat" -disableMetrics
$env:VCPKG_ROOT = "$HOME\vcpkg"
```

This environment variable applies to the current shell. To make it available to
new Visual Studio sessions as well, optionally save it as a user variable:

```powershell
[Environment]::SetEnvironmentVariable("VCPKG_ROOT", $env:VCPKG_ROOT, "User")
```

Restart Visual Studio after changing its environment.

### 3. Configure and build

```powershell
cmake --preset windows
cmake --build --preset windows --parallel
```

The build preset selects **Release**. The executable is
`build/windows/bin/quickbms64.exe`; the generated solution is
`build/windows/QuickBMS.sln`.

Check the built CLI, then optionally install it into `build/install/bin`:

```powershell
cmake -DQUICKBMS=build/windows/bin/quickbms64.exe -P cmake/Smoke.cmake
cmake --install build/windows --config Release --prefix build/install
```

### 4. Develop and debug in Visual Studio

1. Choose **File > Open > Project/Solution** and open
   `build/windows/QuickBMS.sln`.
2. Use the `quickbms` executable target as the startup project.
3. Select **Debug | x64** and build.
4. In **Project Properties > Debugging**, set **Command Arguments** to your BMS
   script, input archive, and output directory. Quote paths containing spaces.
   Set **Working Directory** to the repository root if using relative paths.

A Debug build can also be requested from the command line:

```powershell
cmake --build build/windows --config Debug --parallel
```

Debug and Release share `build/windows/bin/quickbms64.exe`; there is no extra
`Debug` or `Release` subdirectory. Switching configurations replaces that file.
Before installing, build the configuration you intend to install and pass the
same `--config` to `cmake --install`.

## Running QuickBMS

Choose a BMS script that matches your archive format. QuickBMS does not select an
archive parser automatically. The [scripts directory](scripts/) contains scripts;
see [quickbms.txt](quickbms.txt) for the language reference and full CLI options.

For example, replace these paths with your own script, archive, and output folder:

```powershell
.\build\windows\bin\quickbms64.exe "C:\data\format.bms" "C:\data\archive.bin" "C:\data\output"
```

Use `-l` before the script path to list files without extracting them. `-o`
overwrites existing output files without confirmation; `-k` skips them instead.
Use trusted scripts and keep a backup of the original archive before reimporting.
Reimporting modifies the archive and has format-specific restrictions: read
section 3 of [quickbms.txt](quickbms.txt) before using `-w -r`.

On Linux or macOS, invoke the executable under `build/linux/bin/quickbms64` or
`build/macos/bin/quickbms64` with the same argument order.

## Linux

The `linux` preset uses Clang and Ninja. On Debian/Ubuntu, install the build tools
and vcpkg port prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y build-essential clang cmake ninja-build git curl zip unzip tar \
  autoconf automake libtool pkg-config
git clone https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
"$HOME/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
export VCPKG_ROOT="$HOME/vcpkg"
```

Check `cmake --version`: older distribution packages may be below the required
3.25 minimum. Then configure, build, and check the CLI:

```bash
cmake --preset linux
cmake --build --preset linux --parallel
cmake -DQUICKBMS=build/linux/bin/quickbms64 -P cmake/Smoke.cmake
cmake --install build/linux --prefix build/install
```

## macOS

The `macos` preset uses Apple Clang and Ninja for the native architecture. Install
Xcode Command Line Tools if they are not already present:

```bash
xcode-select --install
```

Install the remaining tools with Homebrew, then build from the repository root:

```bash
brew install cmake ninja git autoconf automake libtool pkg-config
git clone https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
"$HOME/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
export VCPKG_ROOT="$HOME/vcpkg"
cmake --preset macos
cmake --build --preset macos --parallel
cmake -DQUICKBMS=build/macos/bin/quickbms64 -P cmake/Smoke.cmake
cmake --install build/macos --prefix build/install
```

vcpkg selects the native Unix architecture. An explicit triplet can be passed at
configuration time, for example `-DVCPKG_TARGET_TRIPLET=x64-linux`, `x64-osx`, or
`arm64-osx`. The compiler must target the same architecture; changing the triplet
alone does **not** enable cross-compilation.

## Build options

`QUICKBMS64` defaults to `ON`: both the process and BMS integer/offset handling
are 64-bit, and the executable is named `quickbms64` (`quickbms64.exe` on Windows).

For scripts that need the original 32-bit BMS integer behavior, configure with
`-DQUICKBMS64=OFF`, for example:

```powershell
cmake --preset windows -DQUICKBMS64=OFF
cmake --build --preset windows --parallel
```

This produces `quickbms.exe` but **still builds a 64-bit process**. It does not
restore compatibility with 32-bit plugins or codecs. Adjust executable paths in
CLI and smoke commands accordingly. Pass `-DQUICKBMS64=ON` to restore the default.

Windows selects Debug or Release at build time, as shown above. Linux/macOS
presets default to Release; for a debug build, configure the appropriate preset
with `-DCMAKE_BUILD_TYPE=Debug` before building it.

## Compatibility limits

This is not a replacement for every feature of the original 32-bit build:

- ZEN decompression, JCALG compression, XMem compression, and the XMem LZX TD
  variant depend on legacy 32-bit code/libraries and are unavailable.
- Regular XMem LZX and JCALG decompression use existing portable implementations.
- aPLib compression uses the existing portable literal encoder. Its output is
  valid, but its compression ratio is lower than the old 32-bit implementation.
- The original fork disabled the assembly-derived Amiga codecs; they remain
  outside the build.

## Verification

[cmake/Smoke.cmake](cmake/Smoke.cmake) runs the actual executable with Unicode
paths and compares these operations against known results:

- Raw extraction, zlib decompression, and regular XMem LZX decompression.
- NIST AES-128 ECB/CTR vectors, including split CTR updates.
- RFC 6229 RC4 using OpenSSL's legacy provider.
- Incremental SHA-256 and HMAC-SHA-256.

Native Windows x64 builds and the smoke checks have been exercised with
**clang-cl, the Visual Studio SDK, and Ninja**. The validation machine lacked the
ClangCL MSBuild toolset component, so the generated Visual Studio solution and
IDE workflow have **not** been exercised locally. Separate Windows checks also
covered seeking/extracting beyond 4 GiB and AES-CTR reimport followed by extraction;
those two checks are not part of `Smoke.cmake`.

Final verification is limited to Windows. Linux/macOS presets are provided for
native builds; macOS has been source-checked, not built locally.
[GitHub Actions](.github/workflows/build.yml) is configured to build, smoke-test,
and install on Windows only; the workflow has not been run remotely.

## Troubleshooting

- **`VCPKG_ROOT` is missing or the toolchain cannot be found:** point the variable
  to the vcpkg checkout, not its executable or this project. Confirm that
  `scripts/buildsystems/vcpkg.cmake` exists inside that directory and that vcpkg
  has been bootstrapped. Visual Studio must inherit the variable as well.
- **ClangCL is not found:** install both the Clang compiler and its **MSBuild
  toolset support** in Visual Studio Installer. Installing a standalone LLVM
  compiler alone does not provide the Visual Studio toolset integration.
- **CMake rejects `cl.exe`:** use the `windows` preset; selecting the default MSVC
  compiler cannot build the GNU C extensions in the legacy sources.
- **An executable seems to be missing:** check `build/<preset>/bin`, not a
  configuration subdirectory. With `QUICKBMS64=OFF`, the name is `quickbms` rather
  than `quickbms64`.
- **Changing generator, compiler, or architecture causes a cache error:** use a
  fresh build directory. For example, add `-B build/windows-fresh` to the configure
  command, then build that directory with
  `cmake --build build/windows-fresh --config Release --parallel`. The existing
  build preset still points to `build/windows`.

## Documentation and credits

- [quickbms.txt](quickbms.txt): upstream manual, CLI options, BMS language, and
  reimport limitations. Its historical descriptions of 32-bit binaries do not
  describe this fork's executable architecture; use this README for build steps.
- [scripts/](scripts/): bundled BMS scripts.
- [changelog.txt](changelog.txt): project change history.
- [CMake build configurations](https://github.com/Kitware/CMake/blob/master/Help/manual/cmake-buildsystem.7.rst)
  and [vcpkg CMake integration](https://github.com/microsoft/vcpkg/blob/master/scripts/buildsystems/vcpkg.cmake):
  upstream build-system references.

QuickBMS was created by **Luigi Auriemma**. This fork focuses on reproducible
source builds and 64-bit development. The project declares **GPL-2.0-or-later**
in [vcpkg.json](vcpkg.json); bundled libraries retain their own license notices.
