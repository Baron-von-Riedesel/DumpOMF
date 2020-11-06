@echo off
rem using jwasm & jwlink
jwasm -coff -FlRelease\ -Fo=Release\ -Sg DumpOmf.asm
rem jwlink format win pe f DumpOmf.obj lib Lib\msvcrt.lib, Lib\kernel32.lib op m, q
jwlink format win pe f Release\DumpOmf.obj n Release\DumpOmf.exe lib Lib\libc32s.lib, Lib\dkrnl32.lib op m=Release\DumpOmf, q
goto end
:m$
rem using masm & MS link
ml -c -coff -FlRelease\DumpOmf -FoRelease\DumpOmf -Sg DumpOmf.asm
link /nologo /subsystem:console Release\DumpOmf.obj /OUT:Release\DumpOmf Lib\libc32s.lib Lib\kernel32.lib /map:Release\DumpOmf /filealign:0x200
:end
