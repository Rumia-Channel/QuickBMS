## "A 64-bit fork of QuickBMS."

### What are the major differences vs. original quickbms?

 - switched from 32-bit to 64-bit builds as an exploration into what needs to be changed to cross-compile for both 32-bit and 64-bit.
 - switched from GCC to LLVM, it solved problems in symbol resolution.
 - added a build option to produce a debugger-friendly build.
 - "amiga stuff" is removed, it was transliterated ASM to begin with and the assembly code is not 64bit compatible. converting it requires more time than i have, and, i don't personally need any of it.
 - created a new Makefile at the repo root to replace the old Makefile under `src/`, this was done for build performance, you can now do a `make clean && make --jobs` and it takes about a minute to compile everything. the old makefile is still present, but was renamed to avoid confusion.

### Why?

 - i was processing a very large amount of data (100+ files) and wanted to containerize my process so i could distribute the workload across my k8s cluster. rather than pull "random linux binary from internet" into my "production" environment i decided to build from source code something that i could both trust and fix.
 - i was met with nothing but pain building from sources, this is the end-product.

 if people find this fork useful/valuable i am willing to continue working on it (fix bugs) since aluigi seems to have abandoned it (?), but the reality is that this fork of quickbms only exists for me. as with many of my projects it is sitting on a private repo/server, and i have decided to make a mirror available in case someone else wants to bang on this version instead of the "0.12" snapshot we've been using for the last couple of years.

### Compiling

install clang + llvm. i used v14 toolchain/runtimes. for debian/ubuntu this looks like:

```bash
apt-get -y install \
  build-essential \
  zlib1g-dev liblzo2-dev libssl-dev unicode \
  clang llvm lld lldb
```

once you have the tools you can use `make` from the repo root (not from `src/`):

```bash
make clean
make build
make all # an alias for `build`
make install # installs to /usr/local/bin/
```

and remember, if you don't enjoy waiting 15+ minutes the Makefile is `--jobs` compatible, thus, you can do..

```bash
make clean && make --jobs
```

..the old Makefile had me wasting so much time between builds that i had enough time to reimplement the makefile to improve build times (while waiting for builds!)

### Will it run on Windows? macOS?

i have only compiled on "linux x86_64", but from what i have seen this code "should" cross-compile on Linux, macOS, and Windows operating systems targeting aarch64/arm64 and x86_64/amd64 processor architectures.

#### macOS (needs work)

i have tested on OSX 13, 14, and now 15 and getting it to build on OSX still requires additional work, specifically:

- `make` behaves differently on OSX and some targets need to be re-ordered.
- `clang` seems to be enforcing c++ deprecations not enforced on GNU systems.
- system `lzo` doesn't seem to resolve, forcing the use of the lzo shadow.
- the masking of `fdopen` in the zlib shadow causes compilation errors.

possibly other issues.. if someone wants to take a stab at fixing the OSX issues i will be more than happy to pull fixes .. otherwise, unless someone asks, i will add fixes as i can but as of yet OSX feels like a boss fight and i can't commit to fixing all of the issues i keep finding.

#### Build on Windows using WSL

you should be able to build under WSL using the `Debian` distribution, this may be the quickest solution for Windows users, as you can see nearer the end of this section you can somewhat hide the use of WSL if you're trying to automate from a Windows script or similar:

From a Windows Console/Terminal:

```console
wsl --install Debian -n
```

Then switch to the cloned repo from github, and enter the WSL container:

```console
cd C:\the\path\to\quickbms\
wsl -d Debian
```

If it's the first run of the Linux container you should be prompted to set a username and password, set them to something you can remember, you may occasionally need them (such as for running `sudo`):

From within WSL:

```bash
# update base packages, and install pre-reqs
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential zlib1g-dev liblzo2-dev libssl-dev unicode clang llvm lld lldb

# run make
make clean && make --jobs
# optionally, install to a common path inside WSL
sudo make install
```

If you want to run it from Windows (CLI) _without having to drop into WSL_..

From Windows shell:

(the path here needs to be changed to match where your repo was located)

```console
cd C:\the\path\to\quickbms\
wsl --exec bin/quickbms64 --help
```

Or, if you did the optional `make install` step, you can avoid the need to use a specific path:

```console
wsl quickbms64
```

Just keep in mind that the pathing from within Linux is different than Windows (your C drive is accessible from `/mnt/c/` not `C:\`, and all backslashes should be changed to forward slashes.)


----

> The original readme from the repository this was forked from can be found in [quickbms.txt](quickbms.txt).

----
