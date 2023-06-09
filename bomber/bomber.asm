    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with VCS register memory mapping and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare variables starting from memory address $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80

JetXPos         byte                ; player0 x-position
JetYPos         byte                ; player0 y-position
BomberXPos      byte                ; player1 x-position
BomberYPos      byte                ; player1 y-position

JetSpritePtr    word                ; pointer to player0 sprite lookup table
JetColorPtr     word                ; pointer to player0 color lookup table
BomberSpritePtr word                ; pointer to player1 sprite lookup table
BomberColorPtr  word                ; pointer to player1 color lookup table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JET_HEIGHT = 9                      ; 
BOMBER_HEIGHT = 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code at memory address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg Code
    org $F000

Reset:
    CLEAN_START                 ; call macro to reset memory and registers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize RAM variables and TIA registers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #10
    sta JetYPos                 ; JetYPos = 10

    lda #60
    sta JetXPos                 ; JetXPos = 60

    lda #83
    sta BomberYPos

    lda #54
    sta BomberXPos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize the pointers to the correct lookup table addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #<JetSprite
    sta JetSpritePtr            ; lo-byte pointer for jet sprite lookup table
    lda #>JetSprite
    sta JetSpritePtr+1          ;hi-byte pointer for jet sprite lookup table

    lda #<JetColor
    sta JetColorPtr            
    lda #>JetColor
    sta JetColorPtr+1          

    lda #<BomberSprite
    sta BomberSpritePtr            
    lda #>BomberSprite
    sta BomberSpritePtr+1          

    lda #<BomberColor
    sta BomberColorPtr            
    lda #>BomberColor
    sta BomberColorPtr+1          
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start the main display loop and frame rendering
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display VSYNC and VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK                  ; turn on VBLANK
    sta VSYNC                   ; turn on VSYNC

    REPEAT 3 
        sta WSYNC               ; display 3 recommended lines of VSYNC
    REPEND
    lda #0
    sta VSYNC                   ; turn off VSYNC

    REPEAT 37
        sta WSYNC               ; display the 37 lines of VBLANK
    REPEND
    sta VBLANK                  ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display the 96 visible scanlines of our main game (2-line kernel)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:
    lda #$84                    ; Blue
    sta COLUBK                  ; set background colour
    lda #$C2                    ; Green
    sta COLUPF                  ; set playfield colour
    lda #%00000001
    sta CTRLPF                  ; enable playfield reflection

    ; playfield pattern
    lda #$F0
    sta PF0 
    lda #$FC
    sta PF1
    lda #0
    sta PF2


    ldx #96                    ; X counts the number of remaining scanlines
.GameLineLoop:
.AreWeInsideJetSprite:
    txa                         ; transfer x to accumulator
    sec                         ; set carry flag
    sbc JetYPos                 ; current scanline - JetYPos
    cmp JET_HEIGHT
    bcc .DrawSpriteP0           ; if result < SpriteHeight, call the draw routine
    lda #0                      ; else, set lookup index to 0

.DrawSpriteP0
    tay                         ; Y is the only register that handles indirect addressing
    lda (JetSpritePtr),Y        ; load player0 bitmap data from lookup table
    sta WSYNC
    sta GRP0                    ; set graphics for player0
    lda (JetColorPtr),Y         ; load player colour from lookup table
    sta COLUP0                  ; set color of player 0

.AreWeInsideBomberSprite:
    txa                         ; transfer x to accumulator
    sec                         ; set carry flag
    sbc BomberYPos              ; current scanline - BomberYPos
    cmp BOMBER_HEIGHT
    bcc .DrawSpriteP1           ; if result < SpriteHeight, call the draw routine
    lda #0                      ; else, set lookup index to 0

.DrawSpriteP1
    tay                         ; Y is the only register that handles indirect addressing

    lda #%00000101
    sta NUSIZ1                  ; stretch bomber sprite

    lda (BomberSpritePtr),Y     ; load player1 bitmap data from lookup table
    sta WSYNC
    sta GRP1                    ; set graphics for player1
    lda (BomberColorPtr),Y      ; load bomber colour from lookup table
    sta COLUP1                  ; set color of player 1


    dex                         ; --x
    bne .GameLineLoop           ; repeat next main game scanline until finished

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display Overscan
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK
    REPEAT 30
        sta WSYNC
    REPEND
    lda #0
    sta VBLANK                  ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop back to start the frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame              ; continue to display the next frame


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JetSprite:
        .byte #%00000000;$00
        .byte #%01010100;$34
        .byte #%01111100;$04
        .byte #%01111100;$04
        .byte #%01111100;$02
        .byte #%00111000;$02
        .byte #%00111000;$04
        .byte #%00111000;$04
        .byte #%00010000;$08

JetSpriteTurn:
        .byte #%00000000;$00
        .byte #%01010100;$34
        .byte #%01111100;$04
        .byte #%00111000;$04
        .byte #%00111000;$02
        .byte #%00111000;$02
        .byte #%00111000;$04
        .byte #%00010000;$04
        .byte #%00010000;$08

JetColor:
        .byte #$00;
        .byte #$34;
        .byte #$04;
        .byte #$04;
        .byte #$02;
        .byte #$02;
        .byte #$04;
        .byte #$04;
        .byte #$08;

BomberSprite:
        .byte #%00000000;$00
        .byte #%00000000;$30
        .byte #%00101000;$30
        .byte #%11111110;$30
        .byte #%01111100;$30
        .byte #%01010100;$30
        .byte #%00010000;$30
        .byte #%00010000;$30
        .byte #%00010000;$30

BomberColor:
        .byte #$00;
        .byte #$30;
        .byte #$30;
        .byte #$30;
        .byte #$30;
        .byte #$30;
        .byte #$30;
        .byte #$30;
        .byte #$30;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size with exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                   ; Move to position $FFFC
    word Reset                  ; 
    word Reset