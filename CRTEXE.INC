
;--- needed if msvcrt.dll is used instead of libc32s.lib

STARTUPINFOA struct 8
cb              DWORD   ?
lpReserved      LPVOID  ?
lpDesktop       LPVOID  ?
lpTitle         LPVOID  ?
dwX             DWORD   ?
dwY             DWORD   ?
dwXSize         DWORD   ?
dwYSize         DWORD   ?
dwXCountChars   DWORD   ?
dwYCountChars   DWORD   ?
dwFillAttribute DWORD   ?
dwFlags         DWORD   ?
wShowWindow     WORD    ?
cbReserved2     WORD    ?
lpReserved2     LPVOID  ?
hStdInput       LPVOID  ?
hStdOutput      LPVOID  ?
hStdError       LPVOID  ?
STARTUPINFOA ends

__getmainargs proto c :ptr, :ptr, :ptr, :dword, :ptr
exit          proto c :dword
_cinit        proto c

GetStartupInfoA proto stdcall :ptr STARTUPINFOA

    .CODE

mainCRTStartup proc c public 

    local argc:dword
    local argv:LPVOID
    local environ:LPVOID
    local _si:STARTUPINFOA

    mov _si.cb, sizeof STARTUPINFOA
    invoke GetStartupInfoA, addr _si
    invoke __getmainargs, addr argc, addr argv, addr environ, 0, addr _si
    invoke main, argc, argv
    invoke exit, eax

mainCRTStartup endp

