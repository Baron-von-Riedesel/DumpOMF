@echo off
rem using jwasm & jwlink
jwasm -coff -Fl -Sg DumpOmf.asm
rem jwlink format win pe f DumpOmf.obj lib Lib\msvcrt.lib, Lib\kernel32.lib op m, q
jwlink format win pe f DumpOmf.obj lib Lib\libc32s.lib, Lib\dkrnl32.lib op m, q
goto end
:m$
rem using masm & MS link
ml -c -coff -Fl -Sg DumpOmf.asm
link /subsystem:console DumpOmf.obj Lib\libc32s.lib Lib\kernel32.lib /map /nologo /filealign:0x200
:end
