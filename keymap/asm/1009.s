; Commander X16 PETSCII/ISO Keyboard Table
; ***this file is auto-generated!***
;
; Name:   Canadian French
; Locale: en-CA
; KLID:   1009

.segment "KBDMETA"

	.byte "EN-CA", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbtab_1009

.segment "KBDTABLES"

kbtab_1009:
	.incbin "asm/1009.bin.lzsa"

; PETSCII
; PETSCII characters reachable on a C64 keyboard that are not reachable with this layout:
; chars: 'π←'
; graph: '\xa4\xa6\xa8\xa9\xba'
; *** THIS IS BAD! ***
; Unicode characters reachable with this layout on Windows but not covered by PETSCII:
; '\_{|}~¢¤¦§¨«¬­¯°±²³´µ¶¸»¼½¾Éé'

; ISO
; Unicode characters reachable with this layout on Windows but not covered by ISO-8859-15:
; '¤¦¨´¸¼½¾'
; ISO-8859-15 characters not reachable by this layout:
; 'ÃÅÆÐÑÕ×ØÞßãåæðñõ÷øþ'

