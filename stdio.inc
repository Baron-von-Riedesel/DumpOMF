
;--- declarations from stdio.h

FILE struct 8
_ptr        LPVOID ?
_cnt        DWORD ?
_base       LPVOID ?
_flag       DWORD ?
_file       DWORD ?
_charbuf    DWORD ?
_bufsiz     DWORD ?
_tmpfname   LPVOID ?
FILE ends

;--- use this if the CRT is linked dynamically
externdef c _imp___iob: ptr FILE

_stdiob macro ofs
	mov eax, _imp___iob
	add eax, ofs * sizeof FILE
	exitm <eax>
endm

stdout equ <_stdiob(1)>

fopen   proto c :ptr, :ptr
fclose  proto c :ptr FILE
fread   proto c :ptr, :dword, :dword, :ptr FILE
fputc   proto c :dword, :ptr FILE
fputs   proto c :ptr, :ptr FILE
printf  proto c :ptr, :vararg

