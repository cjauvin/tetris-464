:BasicUpstart2(start) // autostart macro

.pc = $2000 "Variables"
pos:    .byte 0, 17 // starting pos: top center
cntr:   .byte 0     // multi-purpose counter
vb0:    .byte 0 // multi-purpose var (byte)
vb1:    .byte 0 // var (byte)
vb2:    .byte 0 // var (byte)
vb3:    .byte 0 // var (byte)
vw0:    .byte 0,0 // var (word, i.e. 16 bits)
vw1:    .byte 0,0 // var (word)
vw2:    .byte 0,0 // var (word)
vw3:    .byte 0,0 // var (word)
        
.import source "math.asm"
        
grid_side:      ldx #0
        ldy #0
!loop:  clc         // (($fb) += 40) X 21
        lda $fb,y
        adc #40
        sta $fb
        lda $fc,y
        adc #00
        sta $fc
        lda #160
        sta ($fb),y
        inx
        cpx #21
        bne !loop-
        rts
        
start:  jsr $e544   // clear screen

        // grid bottom
        lda #160    // 32 | 128 (space in rev video)
        ldx #0
!loop:  sta $07a6,x // $07a6 = 1024 + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-

        // grid left
        lda #$36    // $fb -> $0436 = 1024 + (1 * 40) + 14
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_side

        // grid right
        lda #$41    // $fb -> $0442 = 1024 + (1 * 40) + 14 + 11
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_side

        // place 'O' at pos
        lda #0
        sta cntr // counter from 0 to 15

        lda #0
        sta vb0 // x: 0 to 3 (rows)

row4:       lda #0
            sta vb1 // y: 0 to 3 (cols)

                // target cell address: 1024 + (pos[0] * 40) + pos[1]
col4:           lda #0 // vw0 <- 1024
                sta vw1
                lda #4
                sta vw0+1

                lda pos // vw1 <- pos[x] * 40
                clc
                adc vb0
                ldx #40
                jsr mult
                stx vw1  
                sta vw1+1

                lda pos+1 // vw2 <- pos[y]
                clc
                adc vb1
                sta vw2
                lda #0
                sta vw2+1

                jsr add3 // vw3 = vw0 + vw1 + vw2
        
                lda vw3
                sta $fb
                lda vw3+1
                sta $fc

                lda #32 // off
                ldy cntr
                ldx $1001,y
                beq off
                lda #160 // on
off:            ldy #0
                sta ($fb),y

                inc cntr
        
                ldy vb1
                iny
                sty vb1
                cpy #4
                bne col4

           ldx vb0
           inx
           stx vb0
           cpx #4
           bne row4
                
        jmp *

        
.pc = $1000 "Tetrominoes data"
        // 'O' piece
        .byte 1 // number of states
        .byte 0,0,0,0,0,0,1,1,0,0,1,1,0,0,0,0
        //.byte 1,0,1,0,0,1,0,1,1,0,1,0,0,1,0,1

        