
;--- DumpOMF.asm: display OMF object files. Public Domain.
;--- How to create the binary?
;--- j tools:
;--- assemble: jwasm -coff dumpomf.asm
;---     link: jwlink format win pe file dumpomf.obj lib Lib\libc32s.lib, Lib\kernel32.lib
;--- ms tools:
;--- assemble: ml -c -coff dumpomf.asm
;---     link: link /subsystem:console dumpomf.obj Lib\libc32s.lib Lib\kernel32.lib

	.386
	.model flat, stdcall
	option casemap:none
	option proc:private

LPVOID typedef ptr

	include stdio.inc
	include omfspec.inc

CStr macro text:vararg	;define a constant text
local xxx
CONST$2 segment dword flat public 'CONST'
xxx db text,0
CONST$2 ends
	exitm <offset xxx>
	endm

;--- Masm sometimes needs a nop at procedure start
masmnop macro
ifndef __JWASM__
	nop
endif
endm

	.data?

lnamidx dd ?	;name index for LNAMES
segidx  dd ?	;name index for SEGDEF
grpidx  dd ?	;name index for GRPDEF
extidx  dd ?	;name index for EXTDEF
cursiz  dd ?
curpos  LPVOID ?

;--- rcmd and rlen must be consecutive
rcmd	db ?	;record cmd byte
rlen	dw ?	;record length
lchksum	db ?	;checksum calculated

	align

recbuf  db 10000h dup (?)	;OMF record buffer

	.const

cmdname macro args:VARARG
	for name,<args>
	db name
	if @SizeStr(name) eq 8
		db 0
	endif
	db 0
	endm
endm

cmdtab label byte
	cmdname "RHEADR" ,"REGINT", "REDATA", "RIDATA", "OVLDEF", "ENDREC", "BLKDEF";6E-7A
	cmdname "BLKEND" ,"DEBSYM", "THEADR", "LHEADR", "PEDATA", "PIDATA", "COMENT";7C-88
	cmdname "MODEND" ,"EXTDEF", "TYPDEF", "PUBDEF", "LOCSYM", "LINNUM", "LNAMES";8A-96
	cmdname "SEGDEF" ,"GRPDEF", "FIXUPP", "??????", "LEDATA", "LIDATA", "LIBHED";98-A4
	cmdname "LIBNAM" ,"LIBLOC", "LIBDIC", "??????", "??????", "COMDEF", "BAKPAT";A6-B2
	cmdname "LEXTDEF","LPUBDEF","LCOMDEF","COMFIX", "CEXTDEF","??????", "SELDEF";B4-C0
	cmdname "COMDAT" ,"LINSYM", "ALIAS ", "NBKPAT", "LLNAMES",                  ;C2-CA

algntab label ptr
	LPVOID CStr("Abs  ")
	LPVOID CStr("Byte ")
	LPVOID CStr("Word ")
	LPVOID CStr("Para ")
	LPVOID CStr("Page ")
	LPVOID CStr("Dword")
	LPVOID CStr("Algn6")
	LPVOID CStr("Algn7")

cmbtab label ptr
	LPVOID CStr("Private")
	LPVOID CStr("Cbn1   ")
	LPVOID CStr("Public ")
	LPVOID CStr("Cbn3   ")
	LPVOID CStr("Public ")
	LPVOID CStr("Stack  ")
	LPVOID CStr("Common ")
	LPVOID CStr("Public ")

loctab label ptr
	LPVOID CStr("Low8")
	LPVOID CStr("Offs16")
	LPVOID CStr("Seg16")
	LPVOID CStr("Ptr16")
	LPVOID CStr("High8")
	LPVOID CStr("LROffs16")
	LPVOID 0  ;6,7,8,10 and 12 are "reserved"
	LPVOID 0
	LPVOID 0
	LPVOID CStr("Offs32")
	LPVOID 0
	LPVOID CStr("Ptr32")
	LPVOID 0
	LPVOID CStr("LROffs32")
	LPVOID 0
	LPVOID 0

frmmethod label ptr
	LPVOID CStr("SegIdx")
	LPVOID CStr("GrpIdx")
	LPVOID CStr("ExtIdx")
	LPVOID CStr("03!   ")	;value 3 is invalid (ABS in OW)
	LPVOID CStr("Loc   ")	;determined by segment index of last LEDATA/LIDATA
	LPVOID CStr("Target")	;determined by Target's index
	LPVOID CStr("06!   ")	;value 6 is invalid
	LPVOID CStr("07!   ")	;value 7 is invalid
tgtmethod0 label ptr
	LPVOID CStr("SegIdx")
	LPVOID CStr("GrpIdx")
	LPVOID CStr("ExtIdx")
	LPVOID CStr("03!   ")	;value 3 is invalid (ABS in OW)
tgtmethod1 label ptr
	LPVOID CStr("Thrd 0")
	LPVOID CStr("Thrd 1")
	LPVOID CStr("Thrd 2")
	LPVOID CStr("Thrd 3")

	.code

;--- print char

putchr proc char:sbyte			;masm needs signed parameter!
	invoke fputc, char, stdout
	ret
putchr endp

;--- print asciiz string in <text>

putstrz proc text:ptr byte
	invoke fputs, text, stdout
	ret
putstrz endp

;--- print byte in AL in hex

byte_out proc
	push eax
	shr al,4
	call nibout
	mov al,[esp]
	call nibout
	pop eax
	ret
nibout:
	and al,0Fh
	add al,'0'
	cmp al,'9'
	jle @F
	add al,07h
@@:
	invoke putchr, al
	retn
byte_out endp

;--- print word in AX in hex

word_out proc
	push eax
	xchg al,ah
	call byte_out
	xchg al,ah
	call byte_out
	pop eax
	ret
word_out endp

;--- print dword in EAX in hex

dword_out proc
	push eax
	shr eax, 16
	call word_out
	pop eax
	jmp word_out
dword_out endp

;--- print <nSize> bytes of string <pText>

putstrN proc uses esi pText:ptr byte, nSize:dword
	cld
	mov esi, pText
	mov ecx, nSize
	.while ecx
		lodsb
		push ecx
		invoke putchr, al
		pop ecx
		dec ecx
	.endw
	ret
putstrN endp

;--- display <nSize> ascii text starting from <pStart>

putascN proc uses esi pStart:ptr, nSize:dword

	mov esi,pStart
nextitem:
	lodsb
	cmp al,' '
	jnb @F
	mov al,'.'
@@:
	invoke putchr, al
	dec nSize
	jnz nextitem
	ret
putascN endp

;--- fill last line with spaces to position at the ascii block

fillspc proc nSize:sbyte
next:
	invoke putchr, ' '
	invoke putchr, ' '
	invoke putchr, ' '
	dec nSize
	jnz next
	ret
fillspc endp

;--- display <nSize> bytes starting from <pStart> in hex and ascii

puthexb proc pStart:ptr, nSize:dword

local linebeg:ptr
local bytesout:sbyte	;masm needs signed parameter!

	mov esi, pStart
	.while nSize
		mov linebeg, esi
		invoke putstrz, CStr('    ')
		mov eax, esi
		sub eax, pStart
		call word_out
		invoke putchr, ':'
		invoke putchr, ' '
		mov bytesout,00
		.while nSize && bytesout < 16
			lodsb
			call byte_out
			inc bytesout
			.if bytesout == 8
				invoke putchr, '-'
			.else
				invoke putchr, ' '
			.endif
			dec nSize
		.endw
		.if ( bytesout < 16 )
			mov al,16
			sub al,bytesout
			invoke fillspc, al
		.endif
		invoke putchr, ' '
		invoke putascN, linebeg, bytesout
		invoke putchr, 10
	.endw
	ret
puthexb endp

;--- display record size and chksum - read[calculated]
;--- this procedure decrements cursiz!

length_out proc
	masmnop
	invoke putstrz, CStr(' Length:')
	dec cursiz	;don't count chksum
	mov eax,cursiz
	call word_out
	invoke putstrz, CStr(" Cks:")
	mov eax,cursiz
	add eax,curpos
	mov al,[eax]
	call byte_out
	invoke putchr, '['
	mov al, lchksum
	call byte_out
	invoke putchr, ']'
	ret
length_out endp

;--- display 1-byte size-prefixed string at esi
;--- updates esi

name_out proc
	lodsb
	movzx eax, al
	lea ecx, [eax+esi]
	push ecx
	invoke putstrN, esi, eax
	pop esi
	ret
name_out endp

;--- display an index field
;--- if bit 7 of first byte is 1
;--- the value is stored in 2 bytes, high byte first (80-7FFF)
;--- else the value is just one byte ( 0-7F )
;--- updates esi

index_out proc
	mov ah,0
	lodsb
	test al,80h
	jz @F
	and al,7Fh
	mov ah,al
	lodsb
@@:
	movzx eax, ax
	invoke printf, CStr("%u"), eax
	ret
index_out endp

;--- display word/dword depending on current record type
;--- updates esi

wdw_out proc
	.if ( rcmd & 1 )
		lodsd
		call dword_out
	.else
		lodsw
		call word_out
	.endif
	ret
wdw_out endp

;--- display base structure
;--- it's either a grp/seg index pair or a frame (16-bit value)
;--- updates esi

base_out proc
	.if word ptr [esi] == 0
		add esi, 2
		invoke putstrz, CStr(' Frame:')
		lodsw
		call word_out
	.else
		invoke putstrz, CStr(' Grp:')
		call index_out
		invoke putstrz, CStr(' Seg:')
		call index_out
	.endif
	ret
base_out endp

;--- used by fixupp_out and modend_out
;--- updates esi

putfixup proc

local method:byte

	lodsb
	mov method, al

	invoke putstrz, CStr(' Frame:')
	mov al, method
;--- get bits 4-7
	shr al, 4
	.if al & 8 
		and al, 3
		movzx eax, al
		invoke putstrz, [eax*4+tgtmethod1]
	.else
		and al, 07h
		movzx eax, al
		invoke putstrz, [eax*4+frmmethod]
	.endif
	invoke putstrz, CStr(' Target:')
;--- get bits 0-3
	.if method & 8	;is target a target thread?
		mov al, method
		and al, 3
		movzx eax, al
		invoke putstrz, [eax*4+tgtmethod1]
		invoke putstrz, CStr(' P:')
		mov al,method
		and al,4
		shr al,2
		add al,'0'
		invoke putchr, al
	.else
		mov al, method
		and al, 3
		movzx eax, al
		invoke putstrz, [eax*4+tgtmethod0]
	.endif

	mov al, method
	shr al, 4
	and al, 0fh
	.if ( al < 3 )
		invoke putstrz, CStr(' FrDat:')
		call index_out
	.endif
	mov al, method
	and al, 1011b
	.if ( al < 3 )
		invoke putstrz, CStr(' TgDat:')
		call index_out
	.endif
	mov al, method
	and al, 0100b
	.if ( !al )
		invoke putstrz, CStr(' Disp:')
		call wdw_out
	.endif
	ret
putfixup endp

;--- the following *_out procedures
;--- may modify registers esi and edi

;--- THEADR record out
;--- esi=record start

theadr_out proc
	invoke name_out 
	invoke putchr, 10
	ret
theadr_out endp

;--- dos date:
;--- bit 0-4: day 
;--- bit 5-8: month
;--- bit 9-15: year
;--- dos time:
;--- bit 0-4: second/2
;--- bit 5-10: minute
;--- bit 11-15: hour

DOS_DATETIME struct
time WORD ?
date WORD ?
DOS_DATETIME ends

dostime_out proc
	movzx eax,[esi].DOS_DATETIME.date
	mov edx,eax
	mov ecx,eax
	and eax,1Fh
	shr edx,5
	and edx,0fh
	shr ecx,9
	add ecx,1980
	invoke printf, CStr(" %u.%u.%u"), eax, edx, ecx
	movzx eax,[esi].DOS_DATETIME.time
	mov edx,eax
	mov ecx,eax
	and eax,1fh
	shl eax, 1
	shr edx,5
	and edx,3fh
	shr ecx,11
	invoke printf, CStr(" %02u:%02u:%02u"), ecx, edx, eax
	add esi, 4
	ret
dostime_out endp

;--- COMENT record out
;--- esi=record start

coment_out proc

local class:byte
local ordflag:byte

	masmnop
	invoke putstrz, CStr( " Type:")
	lodsb
	call byte_out
	invoke putstrz, CStr( " Class:")
	lodsb
	mov class, al
	call byte_out
	mov curpos, esi
	sub cursiz, 2
	call length_out
	invoke putchr, 10
	.if class == CMT_DOSSEG
		invoke putstrz, CStr("    DOSSEG directive",10)
	.elseif class == CMT_DEFAULT_LIBRARY
		invoke putstrz, CStr("    Default Library:'")
		invoke putstrN, esi, cursiz
		invoke putstrz, CStr("'",10)
		mov cursiz, 0
	.elseif class == CMT_OMF_EXT
		invoke putstrz, CStr("    OMF extension, subtype:")
		lodsb
		call byte_out
		dec cursiz
		mov curpos, esi
		.if al == CMT_EXT_IMPDEF
			invoke putstrz, CStr(" - IMPDEF", 10 )
			invoke putstrz, CStr("    Ordinal flag:")
			lodsb
			mov ordflag, al
			call byte_out
			invoke putstrz, CStr(" IntName:'")
			call name_out
			invoke putstrz, CStr("' Module:'")
			call name_out
			invoke putchr, "'"
			.if ordflag
				invoke putstrz, CStr(" Ord:")
				lodsw
				invoke word_out
			.elseif byte ptr [esi] 
				invoke putstrz, CStr(" Entry:'")
				call name_out
				invoke putchr, "'"
			.endif
			mov cursiz, 0
		.elseif al == CMT_EXT_EXPDEF
			invoke putstrz, CStr(" - EXPDEF", 10 )
			invoke putstrz, CStr("    Flag:")
			lodsb
			mov ordflag, al
			call byte_out
			invoke putstrz, CStr(" ExpName:'")
			call name_out
			invoke putchr, "'"
			.if byte ptr [esi]
				invoke putstrz, CStr(" IntName:'")
				call name_out
				invoke putchr, "'"
			.endif
			.if ordflag & 80h
				invoke putstrz, CStr(" Ordinal: ")
				lodsw
				call word_out
			.endif
			invoke putchr, 10
			mov cursiz, 0
		.else
			invoke putchr, 10
		.endif
	.elseif class == CMT_MS_OMF
		invoke putstrz, CStr("    New OMF extension ( debug info included )" )
		.if cursiz == 3 
			invoke putstrz, CStr(" Version:" )
			lodsb
			call byte_out
			invoke putstrz, CStr(" Style:" )
			invoke putstrN, esi, 2
			mov cursiz, 0
		.endif
		invoke putchr, 10
	.elseif class == CMT_MS_END_PASS1
		invoke putstrz, CStr("    Link Pass Separator, subtype:" )
		lodsb
		call byte_out
		invoke putchr, 10
		mov cursiz, 0
	.elseif class == CMT_WKEXT
		mov edi, cursiz
		dec edi
		add edi, esi
		.while esi < edi
			invoke putstrz, CStr("    WKEXT: weak EXTDEF Idx:")
			call index_out
			invoke putstrz, CStr(" default Res. EXTDEF Idx:")
			call index_out
			invoke putchr, 10
		.endw
		mov cursiz, 0
	.elseif class == CMT_BL_SRC_FILE
		invoke putstrz, CStr("    Borland source file ")
		call index_out
		invoke putstrz, CStr(": ")
		call name_out
		invoke putstrz, CStr(" timestamp:")
		invoke dostime_out
		invoke putchr, 10
		mov cursiz, 0
	.elseif class == CMT_BL_DEP_FILE
		.if cursiz == 0
			invoke putstrz, CStr("    End of Dependency list")
		.else
			invoke putstrz, CStr("    Borland dependency file, timestamp:")
			invoke dostime_out
			invoke putstrz, CStr(" file:")
			call name_out
			mov cursiz, 0
		.endif
		invoke putchr, 10
	.endif
	invoke puthexb, curpos, cursiz
	ret
coment_out endp

;--- MODEND record out
;--- esi=record start

modend_out proc
	masmnop
	invoke putstrz, CStr(' MType:')
	lodsb
	push eax
	call byte_out
	pop eax
	.if al & 40h
		call putfixup
	.endif
	invoke putchr, 10
	ret
modend_out endp

;--- EXTDEF/LEXTDEF record out
;--- esi=record start

extdef_out proc

	mov edi, cursiz
	dec edi
	add edi, esi
	call length_out
	invoke putchr, 10

	.while esi < edi
		invoke putstrz, CStr("    ")
		inc extidx
		invoke printf, CStr("%5u='"), extidx
		call name_out
		invoke putstrz, CStr("' Type:")
		call index_out
		invoke putchr, 10
	.endw
	ret
extdef_out endp

;--- PUBDEF/LPUBDEF record out
;--- esi=record start

pubdef_out proc

	mov edi, cursiz
	dec edi
	add edi, esi

	call base_out
	call length_out
	invoke putchr, 10

	.while esi < edi
		invoke putstrz, CStr("    '")
		call name_out
		invoke putstrz, CStr("' Offs:")
		call wdw_out
		invoke putstrz, CStr(" Type:")
		call index_out
		invoke putchr, 10
	.endw
	ret
pubdef_out endp

;--- LINNUM record out
;--- esi=record start

linnum_out proc uses ebx
	mov edi, cursiz
	dec edi
	add edi, esi

	call base_out
	call length_out
	invoke putchr, 10

	.while esi < edi
		invoke putstrz, CStr("    ")
		mov ebx, 4
		.while ebx && esi < edi
			lodsw
			movzx eax, ax
			invoke printf, CStr("%5u="), eax
			call wdw_out
			invoke putstrz, CStr('  ')
			dec ebx
		.endw
		invoke putchr, 10
	.endw
	ret
linnum_out endp

;--- LNAMES/LLNAMES record out
;--- esi=record start

lnames_out proc

	mov edi, cursiz
	dec edi
	add edi, esi
	call length_out
	invoke putchr, 10

	.while esi < edi
		inc lnamidx
		invoke putstrz, CStr("    ")
		invoke printf, CStr("%5u='"), lnamidx
		invoke name_out
		invoke putchr, "'"
		invoke putchr, 10
	.endw
	ret
lnames_out endp

;--- SEGDEF record out
;--- esi=record start

segdef_out proc

local attr:byte

	lodsb
	mov attr, al

	inc segidx
	invoke printf, CStr("%u "), segidx
	mov al, attr
	shr al, 5
	and al, 7
	movzx eax, al
	invoke putstrz, [eax*4+algntab]

	;invoke putstrz, CStr(' Comb:')
	invoke putstrz, CStr(' ')
	mov al, attr
	shr al, 2
	and al, 7
	movzx eax, al
	invoke putstrz, [eax*4+cmbtab]

	.if ( attr & 1 )
		invoke putstrz, CStr(" 32-bit" )
	.else
		invoke putstrz, CStr(" 16-bit" )
	.endif

	mov al, attr
	.if ( !(al & 0E0h) )	;absolute segment?
		invoke putstrz, CStr(" Frame:" )
		lodsw 
		call word_out
		invoke putstrz, CStr('/')
		lodsb
		call byte_out
	.endif

	invoke putstrz, CStr(' Length:')
	.if ( attr & 2 )	;big bit set?
		invoke putchr, '1'
	.endif
	call wdw_out

	invoke putstrz, CStr(' Name:')
	call index_out
	invoke putstrz, CStr(' Class:')
	call index_out
	invoke putstrz, CStr(' Ovl:')
	call index_out

	invoke putchr,10
	ret
segdef_out endp

;--- GRPDEF record out
;--- esi=record start

grpdef_out proc

	inc grpidx
	invoke printf, CStr("%u"), grpidx

	mov edi, cursiz
	dec edi
	add edi, esi

	invoke putstrz, CStr(' Name:')
	call index_out

	mov eax, esi
	sub eax, curpos
	mov curpos,esi
	sub cursiz,eax

	call length_out

	.while esi < edi
		invoke putchr, 10
		invoke putstrz, CStr('    Type:')
		lodsb
		call byte_out
		invoke putstrz, CStr(' Seg:')
		call index_out
	.endw
	invoke putchr,10
	ret
grpdef_out endp

;--- FIXUPP record out
;--- esi=record start

fixupp_out proc

local method:byte
local lbyte:byte

	mov edi, cursiz
	dec edi
	add edi, esi

	call length_out

	.while esi < edi
		invoke putchr, 10
		lodsb
		mov lbyte, al
		.if ( al & 80h )
			invoke putstrz, CStr('    Fixup: ')
			lodsb
			mov ah, lbyte
			and ax, 3FFh
			call word_out
			.if lbyte & 40h
				invoke putstrz, CStr('  Seg')
			.else
				invoke putstrz, CStr(' Self')
			.endif
			invoke putstrz, CStr(' Loc:')
			mov al,lbyte
			shr al,2
			and al, 0Fh
			movzx eax, al
			.if [eax*4+loctab]
				invoke putstrz, [eax*4+loctab]
			.else
				call byte_out
			.endif

			call putfixup

		.else
			invoke putstrz, CStr('    Thrd: ')
			mov al,lbyte
			shr al, 2
			.if lbyte & 40h
				and al,7
				mov method, al
				invoke putstrz, CStr('  Frame[')
			.else
				and al,3
				mov method, al
				invoke putstrz, CStr(' Target[')
			.endif
			mov al,lbyte
			and al,3
			call byte_out
			invoke putstrz, CStr('] Method:')
			mov al, method
			call byte_out
			.if ( method < 3 )
				invoke putstrz, CStr(' Idx:')
				call index_out
			.endif
		.endif
	.endw
	invoke putchr,10
	ret
fixupp_out endp

;--- LEDATA record out
;--- esi=record start

ledata_out proc

	masmnop
	invoke putstrz, CStr(' Segment:')
	call index_out
	invoke putstrz, CStr(' Offs:')
	call wdw_out

	mov eax, esi
	sub eax, curpos
	mov curpos,esi
	sub cursiz,eax

	call length_out
	invoke putchr,10
	invoke puthexb, curpos, cursiz
	ret
ledata_out endp

;--- the COMDEF record contains DWORD values.
;--- these are encoded a bit funny,
;--- depending on the first byte ( <=80h, ==81h, ==84h, ==88h )

comlength_out proc
	lodsb
	cmp al,80h		;size 1?
	jbe len1
	cmp al,81h		;size 2?
	jz len2
	cmp al,84h		;size 3?
	jz len3
	cmp al,88h		;size 4?
	jz len4
	call byte_out	;anything else assume size 1
	invoke putstrz, CStr("?")
	ret
len1:
	call byte_out
	ret
len2:
	lodsw
	call word_out
	ret
len3:
	lodsw
	push eax
	lodsb
	call byte_out
	pop eax
	call word_out
	ret
len4:
	lodsd
	call dword_out
	ret
comlength_out endp

;--- COMDEF/LCOMDEF record out
;--- esi=record start

comdef_out proc

	mov edi, cursiz
	dec edi
	add edi, esi
	call length_out
	invoke putchr, 10

	.while esi < edi
		invoke putstrz, CStr("    ")
		inc extidx
		invoke printf, CStr("%5u='"), extidx
		call name_out
		invoke putstrz, CStr("' Type:")
		call index_out
		invoke putstrz, CStr(" Dtyp:")
		lodsb
		.if al == 61h
			invoke putstrz, CStr(" Far ")
			invoke putstrz, CStr(" Length:")
			call comlength_out
			invoke putchr, '*'
			call comlength_out
		.elseif al == 62h
			invoke putstrz, CStr(" Near")
			invoke putstrz, CStr(" Length:")
			call comlength_out
		.else
			call byte_out
			invoke putstrz, CStr(" Length:")
			call comlength_out
		.endif
		invoke putchr, 10
	.endw
	ret
comdef_out endp

;--- CEXTDEF record out
;--- such a record defines an external index for a COMDAT symbol
;--- it is needed when a FIXUPP record refers to a COMDAT symbol.
;--- esi=record start

cextdef_out proc
	mov edi, cursiz
	dec edi
	add edi, esi
	call length_out
	invoke putchr, 10

	.while esi < edi
		invoke putstrz, CStr("    ")
		inc extidx
		invoke printf, CStr("%5u="), extidx
		invoke putstrz, CStr(" Idx:")
		call index_out
		invoke putstrz, CStr(" Type:")
		call index_out
		invoke putchr,10
	.endw
	ret
cextdef_out endp

;--- COMDAT record out
;--- esi=record start

comdat_out proc

local flags:byte
local attr:byte

	masmnop
	invoke putstrz, CStr(' Flags:')
	lodsb
	mov flags, al
	call byte_out
	invoke putstrz, CStr(' Attr:')
	lodsb
	mov attr, al
	call byte_out
	invoke putstrz, CStr(' Align:')
	lodsb
	call byte_out
	invoke putstrz, CStr(' Offs:')
	call wdw_out
	invoke putstrz, CStr(' Type:')
	call index_out
	mov al,attr
	and al,0Fh		;get allocation type
	.if (al == 0)	;COMDAT_EXPLICIT?
		call base_out
	.endif

	invoke putstrz, CStr(' PubName:')
	call index_out

	mov eax, esi
	sub eax, curpos
	sub cursiz,eax
	mov curpos,esi

	call length_out
	invoke putchr,10
	invoke puthexb, curpos, cursiz
	ret
comdat_out endp

;--- LINSYM record out
;--- esi=record start

linsym_out proc uses ebx
	mov edi, cursiz
	dec edi
	add edi, esi
	invoke putstrz, CStr("    Flags:")
	lodsb
	call byte_out
	invoke putstrz, CStr("    PubName:")
	call index_out
	invoke putchr, 10
	.while esi < edi
		invoke putstrz, CStr("    ")
		mov ebx, 4
		.while ebx && esi < edi
			lodsw
			movzx eax, ax
			invoke printf, CStr("%5u="), eax
			call wdw_out
			invoke putstrz, CStr('  ')
			dec ebx
		.endw
		invoke putchr, 10
	.endw
	ret
linsym_out endp

;--- ALIAS record out
;--- esi=record start

alias_out proc
	mov edi, cursiz
	dec edi
	add edi, esi
	call length_out
	invoke putchr, 10
	.while esi < edi
		invoke putstrz, CStr("    '")
		call name_out
		invoke putstrz, CStr("' = '")
		call name_out
		invoke putstrz, CStr("'", 10)
	.endw
	ret
alias_out endp

;--- display one record
;--- modifies registers esi and edi

displayrec proc
	mov al, rcmd
	call byte_out
	invoke putchr, ' '
	mov al,rcmd
	cmp al,CMD_START	;command byte
	jc recbad
	cmp al,CMD_END 		;records are 6E - CA
	jnb recbad
	sub al,CMD_START
	shr al,1			;if bit 0 is set, it is the 32bit variant
	movzx eax, al
	shl eax, 3			;8 bytes per cmd name
	mov esi,offset cmdtab
	add esi,eax
	test rcmd,1
	jz recok
	invoke putstrN, esi, 4
	invoke putstrz, CStr("32")	;it's the 32bit variant
	jmp pr5
recbad:
	mov esi, CStr('??????')	;it's an unknown (invalid) record cmd
recok:
	invoke putstrz, esi
pr5:
	invoke putchr, ' '
	mov esi,offset recbuf
	mov curpos,esi

	mov al,rcmd
	and al,0FEh

	.if al==CMD_THEADR
		call theadr_out
	.elseif al==CMD_COMENT
		call coment_out
	.elseif al==CMD_MODEND
		call modend_out
	.elseif al==CMD_EXTDEF || al==CMD_LEXTDEF
		call extdef_out
	.elseif al==CMD_PUBDEF || al==CMD_LPUBDEF
		call pubdef_out
	.elseif al==CMD_LINNUM
		call linnum_out
	.elseif al==CMD_LNAMES || al==CMD_LLNAMES
		call lnames_out
	.elseif al==CMD_SEGDEF
		call segdef_out
	.elseif al==CMD_GRPDEF
		call grpdef_out
	.elseif al==CMD_FIXUPP
		call fixupp_out
	.elseif al==CMD_LEDATA
		call ledata_out
	.elseif al==CMD_LIDATA
		call ledata_out
	.elseif al==CMD_COMDEF || al==CMD_LCOMDEF
		call comdef_out
	.elseif al==CMD_CEXTDEF
		call cextdef_out
	.elseif al==CMD_COMDAT
		call comdat_out
	.elseif al==CMD_LINSYM
		call linsym_out
	.elseif al==CMD_ALIAS
		call alias_out
	.else
		call length_out
		invoke putchr, 10
		invoke puthexb, curpos, cursiz
	.endif
	ret
displayrec endp

;--- calculate checksum

getchksum proc uses esi
	mov ah,0 
	mov esi, offset rcmd
	mov ecx, 3
next1:
	lodsb
	add ah,al
	loop next1
	mov esi, offset recbuf
	mov cx,rlen
	dec ecx	;don't use chksum byte!
	jecxz done
next2:
	lodsb
	add ah,al
	loop next2
done:
	neg ah
	ret
getchksum endp

;--- main - display one OMF file
;--- modifies ebx, esi and edi

main proc c public argc:dword, argv:ptr ptr

local fpos:dword
local fh:ptr	;file handle

	cmp argc, 2
	jb nofile
	mov ebx, argv
	mov esi, [ebx+4]
	invoke fopen, esi, CStr("rb")
	and eax, eax
	jz filenotfound
	mov fh,eax
	mov fpos, 0
	.while (1)
		invoke fread, offset rcmd, 1, 3, fh	;read 3-byte record header
		.break .if ( eax == 0 )
		cmp eax,3
		jnz readerror
		add fpos, 3
		movzx eax,rlen		;record length
		cmp eax, 1			;record size must be at least 1 ( the chksum )
		jbe readerror
		mov cursiz,eax
		invoke fread, offset recbuf, 1, eax, fh
		cmp eax,cursiz
		jnz readerror
		add fpos, eax
		call getchksum
		mov lchksum, ah
		call displayrec		;display record
	.endw
	invoke fclose, fh
	xor eax, eax
	ret

readerror:
	invoke putstrz, CStr('unexpected end of file, last position=')
	mov eax, fpos
	call dword_out
	invoke putchr, 10
	invoke fclose, fh
	jmp errexit
filenotfound:
	invoke putstrz, CStr("file '")
	invoke putstrz, esi
	invoke putstrz, CStr("' not found",10)
	jmp errexit
nofile:
	invoke putstrz, CStr('dumpomf v1.6, displays contents of OMF object files.',10)
	invoke putstrz, CStr('usage: dumpomf filename',10)
errexit:
	mov eax, 1
	ret

main endp

if 0 ;activate if binary is to be linked with msvcrt.dll
	include crtexe.inc
else
extern c mainCRTStartup:proc
endif

	end mainCRTStartup
