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
        .byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
        //.byte 1,0,1,0,0,1,0,1,1,0,1,0,0,1,0,1
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        //.byte 0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0
                
.pc = $2000 "Variables"
fixed_cells:    .fill 1000, 32
pos:            .byte 0, 18 // starting pos: top center
pos_ahead:      .word 0
td_offset:      .byte 0     // tetromino data offset
timer1:         .byte 0, 30 // val, target
timer2:         .byte 0, 5
is_falling:     .byte 0    
is_moving:      .byte 0     // 1=left, 2=right, 3=..
i:              .byte 0
j:              .byte 0        
draw_mode:      .byte 0
gca_mode1:      .byte 0
gca_mode2:      .byte 0
var_add0:       .word 0 
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
        sta is_moving
        jmp !return+
test_right:
        cmp #$44      // 'D' key
        bne !return+
        lda #2
        sta is_moving
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
    target cell address: 1024|fixed_cells + (pos[0]+i * 40) + pos[1]+j
    acc=0: use video, store in $fb
    acc=1: use fixed_cells, store in $fd
    x=0: use pos
    x=1: use pos_ahead   
*/
get_cell_addr:
        sta gca_mode1
        stx gca_mode2
        lda gca_mode1
        bne !use_fixed+
!use_video:      
        lda #0 // var_add0 <- 1024
        sta var_add0
        lda #4
        sta var_add0+1
        jmp !continue+
!use_fixed:
        lda #<fixed_cells // var_add0 <- fixed_cells
        sta var_add0
        lda #>fixed_cells
        sta var_add0+1                
!continue:
        lda gca_mode2
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
        lda gca_mode2
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
        lda gca_mode1
        beq !use_video+
        bne !use_fixed+
!use_video:
        lda var_add3
        sta $fb
        jmp !continue+
!use_fixed:
        lda var_add3
        sta $fd
!continue:
        lda gca_mode1
        beq !use_video+
        bne !use_fixed+
!use_video:
        lda var_add3+1
        sta $fc
        jmp !return+
!use_fixed:
        lda var_add3+1
        sta $fe
!return:
        rts
        
/*
   Draw piece at pos
   acc=1 -> draw
   acc=0 -> erase
*/
draw_piece:

        sta draw_mode // 0:erase, 1:draw
        
        lda #0
        sta td_offset // from 0 to 15

        lda #0
        sta i // 0 to 3 (piece rows)
!prow:
        lda #0
        sta j // 0 to 3 (piece cols)                
!pcol:
        lda #0 // use video
        ldx #0 // use pos
        jsr get_cell_addr // -> $fb/$fc

        lda #1 // use fixed_cells
        ldx #0 // use pos
        jsr get_cell_addr // -> $fd/$fe

        lda draw_mode
        beq erase
draw:   
        ldy td_offset
        ldx $1001,y
        beq erase
        lda #160 // cell on
        ldy #0
        sta ($fb),y
        jmp !continue+
erase:
        ldy #0
        lda ($fd),y
        cmp #160
        beq !continue+                        
        lda #32 // cell off
        sta ($fb),y                
!continue:       
        inc td_offset
        ldy j
        iny
        sty j
        cpy #4
        bne !pcol-

        ldx i
        inx
        stx i
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
        sta td_offset // from 0 to 15

        lda #0
        sta i // 0 to 3 (piece rows)

!prow:
        lda #0
        sta j // 0 to 3 (piece cols)

!pcol:
        lda #1 // use fixed 
        ldx #1 // use pos ahead
        jsr get_cell_addr // -> $fd/$fe

        ldy #0
        lda ($fd),y
        cmp #32
        beq !continue+
        ldy td_offset
        ldx $1001,y
        beq !continue+
        lda #0 // collision detected
        rts

!continue:
        inc td_offset        
        ldy j
        iny
        sty j
        cpy #4
        bne !pcol-

        ldx i
        inx
        stx i
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
        lda is_falling
        cmp #1
        beq do_fall
        lda is_moving
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
        sta is_moving
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
        sta is_moving
        jmp main_loop
        