;----------------------------------------------------------------------
; CBDOS Main
;----------------------------------------------------------------------
; (C)2020 Michael Steil, License: 2-clause BSD

.import sdcard_init

.import fat32_init
.import fat32_dirent
.import sync_sector_buffer
.importzp krn_ptr1, read_blkptr, bank_save

; cmdch.s
.import execute_command, set_status, acptr_status

; dir.s
.import open_dir, acptr_dir

; geos.s
.import cbmdos_GetNxtDirEntry, cbmdos_Get1stDirEntry, cbmdos_CalcBlksFree, cbmdos_GetDirHead, cbmdos_ReadBlock, cbmdos_ReadBuff, cbmdos_OpenDisk

; functions.s
.export cbdos_init

; parser.s
.import parse_cbmdos_filename, create_unix_path, unix_path, buffer, overwrite_flag
.import find_wildcards
.import file_mode, buffer_len, buffer_overflow
.import r1s, r1e

; functions.s
.import medium, soft_check_medium_a

; file.s
.export CONTEXT_NONE ; XXX
.export channel, context_for_channel, ieee_status

.include "banks.inc"

;.include "common.inc"
IMPORTED_FROM_MAIN=1

.feature labels_without_colons

.include "fat32/fat32.inc"
.include "fat32/regs.inc"
.include "fcntl.inc"
;.include "65c02.inc"


.include "file.inc"

ieee_status = status

via1        = $9f60
via1porta   = via1+1 ; RAM bank

.macro BANKING_START
	pha
	lda via1porta
	sta bank_save
	stz via1porta
	pla
.endmacro

.macro BANKING_END
	pha
	lda bank_save
	sta via1porta
	pla
.endmacro

.segment "cbdos_data"

; Commodore DOS variables
initialized:
	.byte 0
MAGIC_INITIALIZED  = $7A
listen_cmd:
	.byte 0
channel:
	.byte 0
is_receiving_filename:
	.byte 0

context_for_channel:
	.res 16, 0
CONTEXT_NONE = $ff
CONTEXT_DIR  = $fd

.segment "cbdos"
; $C000

	jmp cbdos_secnd
	jmp cbdos_tksa
	jmp cbdos_acptr
	jmp cbdos_ciout
	jmp cbdos_untlk
	jmp cbdos_unlsn
	jmp cbdos_listn
	jmp cbdos_talk
; GEOS
	jmp cbmdos_OpenDisk
	jmp cbmdos_ReadBuff
	jmp cbmdos_ReadBlock
	jmp cbmdos_GetDirHead
	jmp cbmdos_CalcBlksFree
	jmp cbmdos_Get1stDirEntry
	jmp cbmdos_GetNxtDirEntry

; detection
	jmp cbdos_sdcard_detect

;---------------------------------------------------------------
; Initialize CBDOS data structures
;
; This has to be done once and is triggered by
; cbdos_sdcard_detect.
;---------------------------------------------------------------
cbdos_init:
	lda #MAGIC_INITIALIZED
	cmp initialized
	bne :+
	rts

:	sta initialized
	phx
	phy

	ldx #14
	lda #CONTEXT_NONE
:	sta context_for_channel,x
	dex
	bpl :-

	lda #$73
	jsr set_status

	; TODO error handling
	jsr fat32_init

	ply
	plx
	rts

;---------------------------------------------------------------
; Detect SD card
;
; Returns Z=1 if SD card is present
;---------------------------------------------------------------
cbdos_sdcard_detect:
	BANKING_START
	jsr cbdos_init

	; re-init the SD card
	; * first write back any dirty sectors
	jsr sync_sector_buffer
	; * then init it
	jsr sdcard_init

	lda #0
	rol
	eor #1          ; Z=0: error
	BANKING_END
	rts

;---------------------------------------------------------------
; LISTEN
;
; Nothing to do.
;---------------------------------------------------------------
cbdos_listn:
	rts

;---------------------------------------------------------------
; SECOND (after LISTEN)
;
;   In:   a    secondary address
;---------------------------------------------------------------
cbdos_secnd:
	BANKING_START
	phx
	phy

	; The upper nybble is the command:
	; $Fx OPEN
	;     The bytes sent by the host until UNLISTEN will be
	;     a filename to be associated with the given channel.
	; $6x LISTEN
	;     The bytes sent by the host until UNLISTEN will be
	;     received into the given channel. (The channel has
	;     to be open.)
	; $Ex CLOSE
	;     Close the given channel, no more bytes will be sent
	;     to it.

; separate into cmd and channel
	tax
	and #$f0
	sta listen_cmd ; we need it for UNLISTEN
	txa
	and #$0f
	sta channel

; special-case command channel:
; ignore OPEN/CLOSE
	cmp #15
	beq @secnd_rts

	stz is_receiving_filename

	lda listen_cmd
	cmp #$f0
	beq @secnd_open
	cmp #$e0
	beq @second_close

; switch to context
	jsr file_second
	bra @secnd_rts

;---------------------------------------------------------------
; CLOSE
@second_close:
	ldx channel
	lda context_for_channel,x
	bmi @secnd_rts

	jsr file_close
	bra @secnd_rts

;---------------------------------------------------------------
; Initiate OPEN
@secnd_open:
	inc is_receiving_filename
	stz buffer_len

@secnd_rts:
	ply
	plx
	BANKING_END
	rts

;---------------------------------------------------------------
; CIOUT (send)
;---------------------------------------------------------------
cbdos_ciout:
	BANKING_START
	phx
	phy

	stz ieee_status

	ldx channel
	cpx #15
	beq @ciout_buffer

	ldx is_receiving_filename
	bne @ciout_buffer

	jsr file_write
	bra @ciout_end

@ciout_buffer:
	ldx buffer_len
	sta buffer,x
	inc buffer_len
	bne :+
	inc buffer_overflow
:

@ciout_end:
	clc
	ply
	plx
	BANKING_END
	rts

;---------------------------------------------------------------
; UNLISTEN
;---------------------------------------------------------------
cbdos_unlsn:
	BANKING_START
	phx
	phy

	lda buffer_overflow
	beq :+
	lda #$32
	jsr set_status
	bra @unlsn_end
:

; special-case command channel
	lda channel
	cmp #$0f
	beq @unlisten_cmdch

	lda listen_cmd
	cmp #$f0
	bne @unlsn_end; != OPEN? -> UNLISTEN does nothing

;---------------------------------------------------------------
; Execute OPEN with filename
	lda buffer
	cmp #'$'
	bne @unlsn_open_file
	lda channel
	bne @unlsn_open_file ; only on channel 0

;---------------------------------------------------------------
; OPEN directory
	lda buffer_len ; filename length
	jsr open_dir
	bcs @unlsn_end

	lda #CONTEXT_DIR
	ldx channel
	sta context_for_channel,x
	bra @unlsn_end

;---------------------------------------------------------------
; OPEN file
@unlsn_open_file:
	jsr file_open
	bra @unlsn_end

;---------------------------------------------------------------
; Execute Command
;
; UNLISTEN on command channel will ignore whether it was
; and OPEN command; it will always trigger command execution
@unlisten_cmdch:
	jsr execute_command

@unlsn_end:
	stz buffer_len
	stz buffer_overflow

	ply
	plx
	BANKING_END
	rts


;---------------------------------------------------------------
; TALK
;
; Nothing to do.
;---------------------------------------------------------------
cbdos_talk:
	rts


;---------------------------------------------------------------
; SECOND (after TALK)
;---------------------------------------------------------------
cbdos_tksa: ; after talk
	BANKING_START
	phx
	phy

	and #$0f
	sta channel

	jsr file_second

	ply
	plx
	BANKING_END
	rts


;---------------------------------------------------------------
; RECEIVE
;---------------------------------------------------------------
cbdos_acptr:
	BANKING_START
	phx
	phy

	ldx channel
	cpx #15
	bne @nacptr_status

; *** STATUS
	jsr acptr_status
	bra @acptr_eval

@nacptr_status:
	lda context_for_channel,x
	bpl @acptr_file ; actual file

	cmp #CONTEXT_DIR
	bne @acptr_none

; *** DIR
	jsr acptr_dir
	bra @acptr_eval

; *** NONE
@acptr_none:
	; #CONTEXT_NONE
	lda #$42 ; EOI + timeout/file not found
	ora ieee_status
	sta ieee_status
	lda #199
	bra @acptr_end

; *** FILE
@acptr_file:
	jsr file_read

@acptr_eval:
	bcc @acptr_end_neoi

	pha
	lda #$40 ; EOI
	ora ieee_status
	sta ieee_status

	ldx channel
	lda context_for_channel,x
	bmi @nfile_close

	jsr file_close2

@nfile_close:
	pla
	bra @acptr_end

@acptr_end_neoi:
	stz ieee_status
@acptr_end:
	clc
	ply
	plx
	BANKING_END
	rts

;---------------------------------------------------------------
; UNTALK
;---------------------------------------------------------------
cbdos_untlk:
	rts

.segment "IRQB"
	.word banked_irq
