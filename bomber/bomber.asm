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
Score           byte                ; 2 digit score stored as a BCD
Timer           byte                ; 2 digit timer stored as BCD
Temp            byte                ; auxillery value to score temporary score values
OnesDigitOffset word                ; lookup table offset for the score 1's digit
TensDigitOffset word                ; lookup table offset for the score 10's digit
JetSpritePtr    word                ; pointer to player0 sprite lookup table
JetColorPtr     word                ; pointer to player0 color lookup table
BomberSpritePtr word                ; pointer to player1 sprite lookup table
BomberColorPtr  word                ; pointer to player1 color lookup table
JetAnimOffset   byte                ; player0 sprite frame offset for animation
Random          byte                ; random number generated to set enemy position

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JET_HEIGHT = 9                      ; 
BOMBER_HEIGHT = 9
DIGITS_HEIGHT = 5

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

    lda #%11010100
    sta Random                  ; Random = $D4

    lda #0
    sta Score
    sta Timer                   ; Score = Timer = 0

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
    lda JetXPos                 ; x-position
    ldy #0                      ; object type
    jsr SetObjectXPos           ; set player 0 horizontal position

    lda BomberXPos              ; x-position
    ldy #1                      ; object type
    jsr SetObjectXPos           ; set player 1 horizontal position

    jsr CalculateDigitOffset    ; calculate the scoreboard digit lookup table offset

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
;; Display the scoreboard lines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #0                      ; clear TIA registers before each new frame
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    lda #$1C                    ; set scoreboard color to white
    sta COLUPF
    lda #%00000000
    sta CTRLPF                  ; do not reflect playfield
    REPEAT 20
        STA WSYNC               ; display 20 scanlines where the scoreboard goes
    REPEND

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


    ldx #84                    ; X counts the number of remaining scanlines
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
    jsr GetRandomBomberPos          ; call subroutine for next random enemy x-position


EndPositionUpdate:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check for object collision
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckCollisionP0P1:
    lda #%10000000                  ; CXPPMM bit 7 detects P0 and P1 collision
    bit CXPPMM                      ; check CXPPMM
    bne .CollisionP0P1
    jmp CheckCollisionP0PF          ; skit to the next check

.CollisionP0P1:
    jsr GameOver                    ; call game over subroutine

CheckCollisionP0PF:
    lda #%10000000                  ; CXP0FB bit 7 detects P0 and PF collision
    bit CXP0FB                      ; check CXP0FB bit 7 with the above pattern
    bne .CollisionP0PF
    jmp EndCollisionCheck           ; else skip to the final check

.CollisionP0PF:
    jsr GameOver                    ; call game over subroutine

EndCollisionCheck:                  ; fallback
    sta CXCLR                       ; clear all collision flags before next frame

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
;; Game over subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameOver subroutine
    lda #$30
    sta COLUBK
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to generate a Linear-Feedback Shift Register random number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generate a LFSR random number 
;; Divide the random value by 4 to limit the size of the result to match river
;; Add 30 to compensate for the left green playfield
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetRandomBomberPos subroutine
    lda Random 
    asl             ; shift left
    eor Random      ; exclusive or
    asl
    eor Random      ; exclusive or
    asl
    asl
    eor Random      ; exclusive or
    asl
    rol Random               ; performs a series of shifts and bit operations

    lsr 
    lsr             ; 2 right shifts to divide by 4
    sta BomberXPos  ; save it to the variable BomberXPos
    lda #30
    adc BomberXPos ; add 30 +BomberXPos
    sta BomberXPos  ; and sets the new value to the bomber x position

    lda #84
    sta BomberYPos  ; set y pos to top of screen

    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle scoreboard digits to be displayed on the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Convert the high and low nibbles of the variable Score and Timer
;; into the offsets of digits lookup table so the values can be displayed.
;; Each digit has a height of 5 bytes in the lookup table.
;;
;; For the low nibble we need to multiply by 5 (offset into lookup table)
;;   - we can use left shift to perform multiplication by 2
;;   - for any number N, the value of N*5 = (N*2*2)+N
;;
;; For the upper nibble, since its already times 16, we need to divide it by 16
;; and then multiply by 5
;;   - we can use right shifts to perform division by 2
;;   - for any number N, the value of (N/16)*5 = (N/2/2)+(N/2/2/2/2)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalculateDigitOffset subroutine
    ldx #1                  ; X register is the loop counter
.PrepareScoreLoop           ; this will loop twice, first X=1, then X=0

    lda Score,X             ; load A with Timer (X=1) or Score (X=0)
    and #$0F                ; remove the tens digit by masking 4 bits 00001111
    sta Temp                ; save the value of A into Temp

    dex                     ; --x
    bpl .PrepareScoreLoop   ; while X>= 0, loop to pass a second time
    
    rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Digits:
    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###

    .byte #%00100010        ;  #
    .byte #%00100010        ;  #
    .byte #%00100010        ;  #
    .byte #%00100010        ;  #
    .byte #%00100010        ;  #

    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###

    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%00110011        ;  ##
    .byte #%00010001        ;   #
    .byte #%01110111        ; ###
    
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%00010001        ;   #

    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%01110111        ; ###

    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###    

    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%00010001        ;   #
    .byte #%00010001        ;   #
    .byte #%00010001        ;   #

    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###

    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###
    .byte #%00010001        ;   #
    .byte #%01110111        ; ###

    .byte #%00100010        ;  #
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #

    .byte #%01110111        ; ###
    .byte #%01010101        ; # #
    .byte #%01100110        ; ##
    .byte #%01010101        ; # #
    .byte #%01110111        ; ###

    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01000100        ; #
    .byte #%01000100        ; #
    .byte #%01110111        ; ###

    .byte #%01100110        ; ##
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #
    .byte #%01010101        ; # #
    .byte #%01100110        ; ##

    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###

    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01110111        ; ###
    .byte #%01000100        ; #
    .byte #%01000100        ; #

JetSprite:
    .byte #%00000000         ;
    .byte #%00010100         ;   # #
    .byte #%01111111         ; #######
    .byte #%00111110         ;  #####
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

JetSpriteTurn:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00111110         ;  #####
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

BomberSprite:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00101010         ;  # # #
    .byte #%00111110         ;  #####
    .byte #%01111111         ; #######
    .byte #%00101010         ;  # # #
    .byte #%00001000         ;    #
    .byte #%00011100         ;   ###

JetColor:
    .byte #$00
    .byte #$FE
    .byte #$0C
    .byte #$0E
    .byte #$0E
    .byte #$04
    .byte #$BA
    .byte #$0E
    .byte #$08

JetColorTurn:
    .byte #$00
    .byte #$FE
    .byte #$0C
    .byte #$0E
    .byte #$0E
    .byte #$04
    .byte #$0E
    .byte #$0E
    .byte #$08

BomberColor:
    .byte #$00
    .byte #$32
    .byte #$32
    .byte #$0E
    .byte #$40
    .byte #$40
    .byte #$40
    .byte #$40
    .byte #$40


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size with exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                   ; Move to position $FFFC
    word Reset                  ; 
    word Reset
