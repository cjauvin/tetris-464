/*
   tetris.asm (c=64)
   June 2012
   Christian Jauvin
   cjauvin@gmail.com
   http://christianjauv.in
*/
        
:BasicUpstart2(main) // autostart macro

.pc = $1000 "Tetrominoes data"
        // 'O' piece
        .byte 1 // number of states
        .byte 0,0,0,0,0,0,1,1,0,0,1,1,0,0,0,0
                
.pc = $2000 "Variables"
pos:    .byte 0, 17 // starting pos: top center
cntr:   .byte 0     // multi-purpose counter
vb0:    .byte 0 // multi-purpose vars (byte)
vb1:    .byte 0 
vb2:    .byte 0 
vb3:    .byte 0 
vw0:    .word 0 // word vars (16 bits)
vw1:    .word 0 
vw2:    .word 0 
vw3:    .word 0 
        
.import source "math.asm"

///////////////////////////////////////////////////////
        
/*
   Draw left and right grid sides
*/
grid_outline_side:
        ldx #0
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

/*
   Draw piece at pos
*/
draw_piece:
        lda #0
        sta cntr // counter from 0 to 15

        lda #0
        sta vb0 // i: 0 to 3 (piece rows)

prow:       lda #0
            sta vb1 // j: 0 to 3 (piece cols)

                // target cell address: 1024 + (pos[0]+i * 40) + pos[1]+j
pcol:           lda #0 // vw0 <- 1024
                sta vw0
                lda #4
                sta vw0+1

                lda pos // vw1 <- pos[0][i] * 40
                clc
                adc vb0 // i
                ldx #40
                jsr mult
                stx vw1  
                sta vw1+1

                lda pos+1 // vw2 <- pos[1][j]
                clc
                adc vb1 // j
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
                bne pcol

           ldx vb0
           inx
           stx vb0
           cpx #4
           bne prow

        rts

/////////////////////////////////////////////        

main:   jsr $e544   // clear screen

        // draw 3 parts of grid outline:        

        // (1) bottom
        lda #160    // 32 | 128 (space in rev video)
        ldx #0
!loop:  sta $07a6,x // $07a6 = 1024 + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-

        // (2) left
        lda #$36    // $fb -> $0436 = 1024 + (1 * 40) + 14
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_outline_side

        // (3) right
        lda #$41    // $fb -> $0442 = 1024 + (1 * 40) + 14 + 11
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_outline_side

        // start
        
        jsr draw_piece
        inc pos
        jsr draw_piece

        jmp * // infinite loop

