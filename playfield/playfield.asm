
	processor 6502
	include "vcs.h"
	include "macro.h"

	org  $f000

Reset:
    CLEAN_START
    
    ldx #$80	        ; blue bg color
    stx COLUBK		; colour background
    
    ldx #$1C		; yellow
    stx COLUPF		; colour play field
    
StartFrame:
    lda #02		; turn on
    sta VBLANK
    sta VSYNC
    
    ; 3 lines of VSYNC
    REPEAT 3
        sta WSYNC
    REPEND
    lda #0
    sta VSYNC           ; turn off vsync
    
    
    ; 37 lines of VBLANK
    REPEAT 37
        sta WSYNC
    REPEND
    lda #0
    sta VBLANK           ; turn off vblank
    
    ; set the CTRLPF (control playfield) register to allow playfield reflection
    ldx #%00000001	; CTRLPF register (D0 means reflect the PF)
    stx CTRLPF
    
    ; Draw the 192 visible scanlines
    
    ; 7 scan lines with no PF set
    ldx #0
    stx PF0
    stx PF1
    stx PF2
    REPEAT 7
        sta WSYNC
    REPEND
    
    
    ; 7 scan lines with PF set
    ldx #%11100000
    stx PF0
    ldx #%11111111
    stx PF1
    stx PF2
    REPEAT 7
        sta WSYNC
    REPEND
    
    ; 164 with 3rd bit enabled
    ldx #%01100000
    stx PF0
    ldx #0
    stx PF1
    ldx #%10000000
    stx PF2
    REPEAT 164
    	sta WSYNC
    REPEND
    
    ; 7 scan lines with PF set
    ldx #%11100000
    stx PF0
    ldx #%11111111
    stx PF1
    stx PF2
    REPEAT 7
        sta WSYNC
    REPEND
    
    ; 7 scan lines with no PF set
    ldx #0
    stx PF0
    stx PF1
    stx PF2
    REPEAT 7
        sta WSYNC
    REPEND  
    
    ; VBLANK overscan
    lda #2
    sta VBLANK
    REPEAT 30
    	sta WSYNC
    REPEND
    lda #0
    sta VBLANK
    
    ; loop to next frame
    jmp StartFrame
    
    org $fffc
    .word Reset
    .word Reset



