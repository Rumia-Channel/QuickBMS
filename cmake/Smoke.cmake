cmake_minimum_required(VERSION 3.25)
if(NOT DEFINED QUICKBMS OR NOT EXISTS "${QUICKBMS}")
    message(FATAL_ERROR "Pass -DQUICKBMS=<built quickbms64 executable>")
endif()
get_filename_component(QUICKBMS "${QUICKBMS}" ABSOLUTE)
get_filename_component(binary_dir "${QUICKBMS}" DIRECTORY)
set(work "${binary_dir}/../smoke/検証")
file(MAKE_DIRECTORY "${work}/output")
file(WRITE "${work}/input.txt" "QuickBMS portable build!")
file(WRITE "${work}/extract.bms" [=[
get SIZE asize
log "copy.txt" 0 SIZE
set MEMORY_FILE binary "\x78\x9c\x0b\x2c\xcd\x4c\xce\x76\xf2\x0d\x56\x28\xc8\x2f\x2a\x49\x4c\xca\x49\x55\x48\x2a\xcd\xcc\x49\x51\x04\x00\x6d\x9c\x08\xaa"
comtype zlib
clog "zlib.txt" 0 32 24 MEMORY_FILE
set MEMORY_FILE binary "\xff\x00\x18\x00\x2c\x5b\x80\x80\x8d\x00\x30\x80\x01\x12\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x51\x75\x69\x63\x6b\x42\x4d\x53\x20\x70\x6f\x72\x74\x61\x62\x6c\x65\x20\x62\x75\x69\x6c\x64\x21"
comtype xmemlzx "131072 524288"
clog "xmem.txt" 0 49 24 MEMORY_FILE
set MEMORY_FILE binary "\x6b\xc1\xbe\xe2\x2e\x40\x9f\x96\xe9\x3d\x7e\x11\x73\x93\x17\x2a"
encryption aes "\x2b\x7e\x15\x16\x28\xae\xd2\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c" "" 1
log "aes.bin" 0 16 MEMORY_FILE
set MEMORY_FILE binary "\x87\x4d\x61\x91\xb6\x20\xe3\x26\x1b\xef\x68\x64\x99\x0d\xb6\xce\x98\x06\xf6\x6b\x79\x70\xfd\xff\x86\x17\x18\x7b\xb9\xff\xfd\xff"
encryption aes_128_ctr "\x2b\x7e\x15\x16\x28\xae\xd2\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c" "\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff" 0
log "ctr-first.bin" 0 7 MEMORY_FILE
log "ctr-second.bin" 7 25 MEMORY_FILE
set MEMORY_FILE binary "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
encryption rc4 "\x01\x02\x03\x04\x05" "" 1
log "rc4.bin" 0 16 MEMORY_FILE
encryption sha256 ""
log MEMORY_FILE2 0 8
log MEMORY_FILE3 8 16
print "sha256:%QUICKBMS_HEXHASH%"
encryption "hmac sha256" "key"
log MEMORY_FILE4 0 24
print "hmac:%QUICKBMS_HEXHASH%"
]=])
execute_process(COMMAND "${QUICKBMS}" -Y -o "${work}/extract.bms"
    "${work}/input.txt" "${work}/output"
    RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE errors TIMEOUT 60)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "QuickBMS extraction failed (${result})\n${output}\n${errors}")
endif()
foreach(name copy zlib xmem)
    file(READ "${work}/output/${name}.txt" actual)
    if(NOT actual STREQUAL "QuickBMS portable build!")
        message(FATAL_ERROR "${name} extraction differs from the known payload")
    endif()
endforeach()
foreach(vector
    "aes:3ad77bb40d7a3660a89ecaf32466ef97"
    "ctr-first:6bc1bee22e409f"
    "ctr-second:96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51"
    "rc4:b2396305f03dc027ccc3524a0a1118a8")
    string(REPLACE ":" ";" fields "${vector}")
    list(GET fields 0 name)
    list(GET fields 1 expected)
    file(READ "${work}/output/${name}.bin" actual HEX)
    if(NOT actual STREQUAL expected)
        message(FATAL_ERROR "${name} differs from its NIST/RFC known answer: ${actual}")
    endif()
endforeach()
string(TOLOWER "${output}\n${errors}" hash_output)
foreach(answer
    "sha256:5a573dbce07f2ab4b98899c3d916cf5ef4cf3a7a382738e93fe5895ce3015224"
    "hmac:77ae7dfccd0eb02298f41df4ff534ead25f1222d6935f258eff3847bdfe79e09")
    string(FIND "${hash_output}" "${answer}" found)
    if(found EQUAL -1)
        message(FATAL_ERROR "OpenSSL hash differs from the known answer ${answer}\n${hash_output}")
    endif()
endforeach()
message(STATUS "CLI smoke passed: Unicode paths, extraction, zlib, XMem LZX, AES-128 ECB/CTR, RC4 legacy provider, incremental SHA-256, HMAC-SHA-256")
