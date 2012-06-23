/*
   tetris.asm (C=64 + KickAssembler)
   =================================
   June 2012
   Christian Jauvin
   cjauvin@gmail.com
   http://christianjauv.in
*/
        
:BasicUpstart2(main) // autostart macro

.import source "math.asm"

.pc = $1000 "Tetrominoes data"
        // 'O' piece
        .byte 1 // number of states
        .byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
        //.byte 1,0,1,0,0,1,0,1,1,0,1,0,0,1,0,1
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
                
.pc = $2000 "Variables"
fixed: .fill 1000, 32
pos:    .byte 0, 18 // starting pos: top center
pos_ahead: .word 0
cntr:   .byte 0     // multi-purpose counter
timer1: .byte 0, 30     // val, target
timer2: .byte 0, 5
falling: .byte 0    
moving:  .byte 0    // 1=left, 2=right, 3=..
vb0:    .byte 0     // multi-purpose vars (byte)
vb1:    .byte 0 
vb2:    .byte 0 
vb3:    .byte 0 
vw0:    .word 0     // word vars (16 bits)
vw1:    .word 0 
vw2:    .word 0 
vw3:    .word 0
        
///////////////////////////////////////////////////////

/*
   Interrupt handler
*/
interrupt_handler:
        // animate piece fall
        lda timer1
        cmp timer1+1
        bne !wait+
        lda #1
        sta falling
        lda #0
        sta timer1
        jmp !return+
        jmp keyboard_input
!wait:
        inc timer1
keyboard_input: 
        lda timer2
        cmp timer2+1
        bne !wait+
        lda #0
        sta timer2
        jsr $ffe4
        beq !return+
test_left:      
        cmp #$41      // 'A' key
        bne test_right
        lda #1
        sta moving
        jmp !return+
test_right:
        cmp #$44      // 'D' key
        bne !return+
        lda #2
        sta moving
        lda #2        
        jmp !return+
!wait:
        inc timer2
!return:
        jmp $ea31 // $ea31=full, $ea81=pop registers only
        
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
   
*/
get_cell_addr:
        lda #0 // vw0 <- 1024
        sta vw0
        lda #4
        sta vw0+1

        lda pos // vw1 <- pos[0][i] * 40
        clc
        adc vb1 // i
        ldx #40
        jsr mult
        stx vw1  
        sta vw1+1

        lda pos+1 // vw2 <- pos[1][j]
        clc
        adc vb2 // j
        sta vw2
        lda #0
        sta vw2+1

        jsr add3 // vw3 = vw0 + vw1 + vw2

        lda vw3
        sta $fb
        lda vw3+1
        sta $fc

        rts
        
/*
   Draw piece at pos
   acc=1 -> draw
   acc=0 -> erase
*/
draw_piece:

        sta vb0 // acc -> vb0 -> 0:erase, 1:draw
        
        lda #0
        sta cntr // counter from 0 to 15

        lda #0
        sta vb1 // i: 0 to 3 (piece rows)

!prow:      lda #0
            sta vb2 // j: 0 to 3 (piece cols)

                // target cell address: 1024 + (pos[0]+i * 40) + pos[1]+j
!pcol:
                jsr get_cell_addr
        
                lda vb0
                beq erase
draw:   
                lda #32 // off
                ldy cntr
                ldx $1001,y
                beq off
                lda #160 // on
off:            ldy #0
                sta ($fb),y

                inc cntr
                jmp !continue+

erase:
                lda #32 // off
                ldy #0
                sta ($fb),y                

!continue:       
                ldy vb2
                iny
                sty vb2
                cpy #4
                bne !pcol-

           ldx vb1
           inx
           stx vb1
           cpx #4
           bne !prow-

        rts

/*
   Input:  
      acc=0: down, acc=1: left, acc=2: right
   Output:
      acc=1: yes, acc=0: no
*/
can_move:

        ldx pos
        ldy pos+1
        stx pos_ahead
        sty pos_ahead+1

        cmp #0
        beq down
        cmp #1
        beq left
        cmp #2
        beq right

down:   inc pos_ahead
        jmp !continue+
left:   dec pos_ahead+1
        jmp !continue+
right:  inc pos_ahead+1
        jmp !continue+
       
!continue:
        lda #0
        sta cntr // counter from 0 to 15

        lda #0
        sta vb1 // i: 0 to 3 (piece rows)

!prow:      lda #0
            sta vb2 // j: 0 to 3 (piece cols)

                // target cell address: fixed + (pos_ahead[0]+i * 40) + pos_ahead[1]+j
!pcol:        
                lda #<fixed // vw0 <- fixed
                sta vw0
                lda #>fixed
                sta vw0+1

                lda pos_ahead // vw1 <- pos_ahead[0][i] * 40
                clc
                adc vb1 // i
                ldx #40

                jsr mult
                stx vw1  
                sta vw1+1

                lda pos_ahead+1 // vw2 <- pos_ahead[1][j]
                clc
                adc vb2 // j
                sta vw2
                lda #0
                sta vw2+1

                jsr add3 // vw3 = vw0 + vw1 + vw2

                lda vw3
                sta $fb
                lda vw3+1
                sta $fc

                ldy #0
                lda ($fb),y
                cmp #32
                beq !continue+
                ldy cntr
                ldx $1001,y
                beq !continue+
                lda #0 // collision detected
                rts

!continue:
                inc cntr        
                ldy vb2
                iny
                sty vb2
                cpy #4
                bne !pcol-

           ldx vb1
           inx
           stx vb1
           cpx #4
           bne !prow-

        lda #1 // no collision found
        rts
                
/////////////////////////////////////////////        

main:
        jsr $e544   // clear screen

        lda #128
        sta $028a // set key autorepeat
                
        // draw 3 parts of grid outline:        

        // (1) bottom        
        lda #160    // 32 | 128 (space in rev video)
        ldx #0
!loop:  sta $07a6,x // $07a6 = 1024 + (23 * 40) + 14
        sta $23a6,x // $23a6 = 8192 + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-

        // (2) left
        lda #$36    // $fb -> $0436 = 1024 + (1 * 40) + 14
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_outline_side

        lda #$36    // $fb -> $2036 = 8192 + (1 * 40) + 14
        sta $fb
        lda #$20
        sta $fc        
        jsr grid_outline_side
        
        // (3) right
        lda #$41    // $fb -> $0442 = 1024 + (1 * 40) + 25
        sta $fb
        lda #$04
        sta $fc        
        jsr grid_outline_side

        lda #$41    // $fb -> $2041 = 8192 + (1 * 40) + 25
        sta $fb
        lda #$20
        sta $fc        
        jsr grid_outline_side
        
        lda #1
        jsr draw_piece

        // set interrupt handler
        sei       
        lda #<interrupt_handler
        sta 788   
        lda #>interrupt_handler
        sta 789
        cli       
        
main_loop:
        lda falling
        cmp #1
        beq do_fall
        lda moving
        cmp #1
        beq do_left
        cmp #2
        beq do_right
        jmp main_loop
do_fall:
        lda #0
        jsr draw_piece
        inc pos
        lda #1
        jsr draw_piece
        lda #0
        sta falling
        jmp main_loop        
do_left:
        lda #1
        jsr can_move // can move left?
        beq main_loop
        lda #0
        jsr draw_piece
        dec pos+1       // piece left
        lda #1
        jsr draw_piece
        lda #0
        sta moving
        jmp main_loop
do_right:
        lda #2
        jsr can_move // can move right?
        beq main_loop
        lda #0
        jsr draw_piece
        inc pos+1       // piece right
        lda #1
        jsr draw_piece
        lda #0
        sta moving
        jmp main_loop
        