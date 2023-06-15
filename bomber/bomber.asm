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
JetAnimOffset   byte                ; player0 sprite frame offset for animation

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

    lda #0
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
;; Calculations and tasks performed in the pre-VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda JetXPos
    ldy #0
    jsr SetObjectXPos           ; set player 0 horizontal position

    lda BomberXPos
    ldy #1
    jsr SetObjectXPos           ; set player 1 horizontal position

    sta WSYNC
    sta HMOVE                   ; apply the horizontal offset previously set
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
    clc
    adc JetAnimOffset           ; jump to the correct sprite frame address in memory
    
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

    lda #0
    sta JetAnimOffset           ; reset jet animation to 0 each frame

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
;; Process Joystick Input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckP0Up:
    lda #%00010000
    bit SWCHA
    bne CheckP0Down
    ;;;;;;;;;;;
    ;; Here goes logic if down
    ;;;;;;;;;;;
    inc JetYPos
    lda #0                  
    sta JetAnimOffset               ; reset sprite animation offset

CheckP0Down:
    lda #%00100000
    bit SWCHA
    bne CheckP0Left
    ;;;;;;;;;;;
    ;; Here goes logic if down
    ;;;;;;;;;;;
    dec JetYPos
    lda #0                  
    sta JetAnimOffset               ; reset sprite animation offset


CheckP0Left:
    lda #%01000000
    bit SWCHA
    bne CheckP0Right
    ;;;;;;;;;;;
    ;; Here goes logic if left
    ;;;;;;;;;;;
    dec JetXPos
    lda JET_HEIGHT                  ; 9
    sta JetAnimOffset               ; set animation offset to the second frame

CheckP0Right:
    lda #%10000000
    bit SWCHA
    bne EndInputCheck
    ;;;;;;;;;;;
    ;; Here goes logic if right
    ;;;;;;;;;;;
    inc JetXPos
    lda JET_HEIGHT                  ; 9
    sta JetAnimOffset               ; set animation offset to the second frame


EndInputCheck:                  ; Fallback when no input was performed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculations to update position for next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateBomberPosition:
    lda BomberYPos
    clc
    cmp #0                          ; compare bomber Y pos with 0
    bmi .ResetBomberPosition        ; if bomber Y pos < 0, reset Y position to top of screen
    dec BomberYPos                  ; else, decrement enemy y-position for next frame
    jmp EndPositionUpdate

.ResetBomberPosition
    lda #96
    sta BomberYPos

    ;; TODO: set bomber X position to random number

EndPositionUpdate:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop back to start the frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame              ; continue to display the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle object horizontal position with fine offset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A is the target x-coordinate position in pixels of our object
;; Y is the object type (0:player0, 1:player1, 2:missile0, 3:missile1, 4:ball)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetObjectXPos subroutine
    sta WSYNC
    sec
.Div15Loop
    sbc #15
    bcs .Div15Loop              ; loop until carry flag is clear
    eor #7                      ; transform to offset range from -8 to 7
    asl
    asl
    asl
    asl
    sta HMP0,Y                  ; store the fine offset to the correct HMxx
    sta RESP0,Y                 ; fix object position in 15-step increment
    rts


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

JetColorTurn:
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
