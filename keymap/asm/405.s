; Commander X16 PETSCII/ISO Keyboard Table
; ***this file is auto-generated!***
;
; Name:   Czech
; Locale: cs-CZ
; KLID:   405

.segment "KBDMETA"

	.byte "CS-CZ", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbtab_405

.segment "KBDTABLES"

kbtab_405:
	.incbin "asm/405.bin.lzsa"

; PETSCII
; PETSCII characters reachable on a C64 keyboard that are not reachable with this layout:
; chars: '£π←'
; graph: '\xa4\xa6\xa8\xa9\xba'
; *** THIS IS BAD! ***
; Unicode characters reachable with this layout on Windows but not covered by PETSCII:
; '\_{|}~¤§¨°´¸×ßáéí÷úýčĐđěŁłřšůžˇ˘˙˛˝€'

; ISO
; Unicode characters reachable with this layout on Windows but not covered by ISO-8859-15:
; '¤¨´¸čĐđěŁłřůˇ˘˙˛˝'
; ISO-8859-15 characters not reachable by this layout:
; 'ÃÆÐÑÕØÞãæðñõøþ'

