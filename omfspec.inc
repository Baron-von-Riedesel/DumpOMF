
;--- range of valid OMF record types
CMD_START  equ 06Eh
CMD_END    equ 0CCh

;--- OMF record types
CMD_THEADR  equ 080h
CMD_COMENT  equ 088h
CMD_MODEND  equ 08Ah
CMD_EXTDEF  equ 08Ch
CMD_PUBDEF  equ 090h
CMD_LINNUM  equ 094h
CMD_LNAMES  equ 096h
CMD_SEGDEF  equ 098h
CMD_GRPDEF  equ 09Ah
CMD_FIXUPP  equ 09Ch
CMD_LEDATA  equ 0A0h
CMD_LIDATA  equ 0A2h
CMD_COMDEF  equ 0B0h
CMD_LEXTDEF equ 0B4h
CMD_LPUBDEF equ 0B6h
CMD_LCOMDEF equ 0B8h
CMD_CEXTDEF equ 0BCh
CMD_COMDAT  equ 0C2h
CMD_LINSYM  equ 0C4h
CMD_ALIAS   equ 0C6h
CMD_LLNAMES equ 0CAh

;--- OMF COMENT classes
CMT_DOSSEG          equ 09eh ; DOSSEG directive
CMT_DEFAULT_LIBRARY equ 09fh ; Default library
CMT_OMF_EXT         equ 0a0h ; OMF extension
CMT_MS_OMF          equ 0a1h ; "new" OMF extension ( =debug info included )
CMT_MS_END_PASS1    equ 0a2h ; MS end of linker pass 1
CMT_WKEXT           equ 0a8h ; Weak external record
CMT_BL_SRC_FILE     equ 0e8h ; Borland source file
CMT_BL_DEP_FILE     equ 0e9h ; Borland dependency file

;--- OMF COMENT class A0 subtypes
CMT_EXT_IMPDEF  equ 01 ; Subtype IMPDEF
CMT_EXT_EXPDEF  equ 02 ; Subtype EXPDEF
CMT_EXT_INCDEF  equ 03 ; Subtype INCDEF
CMT_EXT_PMLIB   equ 04 ; Protected Memory Library
CMT_EXT_LNKDIR  equ 05 ; Subtype LNKDIR
CMT_EXT_BIGEND  equ 06
CMT_EXT_PRECOMP equ 07

