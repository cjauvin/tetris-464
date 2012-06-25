/*
   tetris.asm (C=64 + KickAssembler)
   =================================
   Christian Jauvin
   June 2012
   cjauvin@gmail.com
   http://christianjauv.in
*/
        
:BasicUpstart2(main) // autostart macro

.import source "math.asm"

.pc = $1000 "Tetrominoes data"
        // 'O' piece
        .byte 1 // number of states
        //.byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
        //.byte 1,0,1,0,0,1,0,1,1,0,1,0,0,1,0,1
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0
                
.pc = $2000 "Variables"
pos:            .byte 0, 18 // starting pos: top center
pos_ahead:      .word 0     // move lookahead
i:              .byte 0     // tetromino data row
j:              .byte 0     // td col   
k:              .byte 0     // td offset
timer1:         .byte 0, 30 // val, target
timer2:         .byte 0, 5  // val, target
is_falling:     .byte 0     // bool
moving_dir:      .byte 0    // 0:none, 1:left, 2:right
draw_mode:      .byte 0     // 0:erase, 1:draw, 
var_add0:       .word 0     // used by add2 and add3 
var_add1:       .word 0 
var_add2:       .word 0 
var_add3:       .word 0
        
///////////////////////////////////////////////////////

/*
   Interrupt handler: handle timers and set moving flags 
*/
interrupt_handler:
        // animate piece fall
        lda timer1
        cmp timer1+1
        bne !wait+
        lda #1
        sta is_falling
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
        sta moving_dir
        jmp !return+
test_right:
        cmp #$44      // 'D' key
        bne !return+
        lda #2
        sta moving_dir
        jmp !return+
!wait:
        inc timer2
!return:
        jmp $ea31 
        
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
        lda #$e6
        sta ($fb),y
        inx
        cpx #21
        bne !loop-
        rts

/*
    target cell address: 1024 + (pos[0]+i * 40) + pos[1]+j
    y=0: use pos
    y=1: use pos_ahead   
*/
get_cell_addr:
        lda #0 // var_add0 <- 1024
        sta var_add0
        lda #4
        sta var_add0+1
        cpy #0
        bne !use_ahead+
        lda pos 
        jmp !continue+
!use_ahead:
        lda pos_ahead
!continue:        
        clc
        adc i 
        ldx #40
        jsr mult
        stx var_add1  
        sta var_add1+1
        cpy #0
        bne !use_ahead+
        lda pos+1
        jmp !continue+
!use_ahead:
        lda pos_ahead+1
!continue:                
        clc
        adc j
        sta var_add2
        lda #0
        sta var_add2+1
        jsr add3 // var_add3 = var_add0 + var_add1 + var_add2
        lda var_add3
        sta $fb
        lda var_add3+1
        sta $fc
        rts
        
/*
   Draw piece at pos
   acc=1 -> draw
   acc=0 -> erase
*/
draw_piece:
        sta draw_mode // 0:erase, 1:draw        
        lda #0
        sta k // from 0 to 15
        sta i // 0 to 3 (piece rows)
!row:
        lda #0
        sta j // 0 to 3 (piece cols)                
!col:
        ldy #0 // use pos
        jsr get_cell_addr // -> $fb/$fc
        lda draw_mode
        beq erase
draw:   
        ldy k
        ldx $1001,y
        beq erase
        lda #160 // cell on
        ldy #0
        sta ($fb),y
        jmp !continue+
erase:
        ldy #0
        lda ($fb),y
        cmp #$e6 // solidified
        beq !continue+                        
        lda #32 // cell off
        sta ($fb),y                
!continue:       
        inc k
        inc j
        lda j
        cmp #4
        bne !col-
        inc i
        lda i
        cmp #4
        bne !row-
        rts
               
/*
   Input:  
      acc=0: down, acc=1: left, acc=2: right
   Output:
      acc=bool
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
!continue:
        lda #0
        sta k // from 0 to 15
        sta i // 0 to 3 (td rows)
!row:
        lda #0
        sta j // 0 to 3 (td cols)
!col:
        ldy #1 // use pos_ahead
        jsr get_cell_addr // -> $fb/$fc
        ldy #0
        lda ($fb),y
        cmp #$e6
        bne !continue+
        ldy k
        ldx $1001,y
        beq !continue+
        lda #0 // collision detected
        rts
!continue:
        inc k
        inc j
        lda j
        cmp #4
        bne !col-
        inc i
        lda i
        cmp #4
        bne !row-
        lda #1 // no collision found
        rts
                
/////////////////////////////////////////////        

main:
        jsr $e544   // clear screen

        lda #128
        sta $028a // set key autorepeat
                
        // draw 3 parts of grid outline:        

        // (1) bottom        
        lda #$e6    // solid char
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
        lda #$41    // $fb -> $0442 = 1024 + (1 * 40) + 25
        sta $fb
        lda #$04
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
        lda is_falling
        bne do_fall
        lda moving_dir
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
        sta is_falling
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
        sta moving_dir
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
        sta moving_dir
        jmp main_loop
        