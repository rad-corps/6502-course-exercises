    processor 6502
    seg Code ; Define a new segment named "Code"
    org $F000 ; Define the origin of the ROM code at memory address $F000
Start:

    lda #10                ; Load the A register with the decimal value 10
    sta $80                ; Store the value from A into memory position $80
    inc $80                ; Increment the value inside a (zero page) memory position $80
    dec $80                ; Decrement the value inside a (zero page) memory position $80
   

    org $FFFC ; End the ROM by adding required values to memory position $FFFC
    .word Start ; Put 2 bytes with the reset address at memory position $FFFC
    .word Start ; Put 2 bytes with the break address at memory position $FFFE