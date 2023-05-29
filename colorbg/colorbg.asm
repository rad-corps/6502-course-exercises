    processor 6502 

    include "vcs.h"
    include "macro.h"

    seg code
    org $f000             ; defines the origin of the ROM at $F000
START:
    ;CLEAN_START           ; Macro to safely clear the memory

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set background luminosity color to yellow
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #$1E              ; Load color into A ($1E is NTSC yellow)
    sta COLUBK            ; store A to BackgrounColor Address $09

    jmp START

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill ROM size to exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
    org $FFFC             ; 
    .word START           ; Reset vector at $FFFC
    .word START           ; Interrupt vector at $FFFE
