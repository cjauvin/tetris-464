/*
   tetris.asm (C=64 + KickAssembler)
   =================================
   Christian Jauvin
   June 2012
   cjauvin@gmail.com
   http://christianjauv.in
*/

/*
   ZP pointers:
       $f9: current video page ($0400 or $0800)
       $fb: draw/erase working page
       $fd: solid page
*/        
        
:BasicUpstart2(main) // autostart macro

.pc = $2000 "Variables and data"
solid:          .fill 1000, 0
page:           .byte 0     // only last bit 
pos:            .byte 0, 18 // starting pos: top center        
pos_ahead:      .word 0     // move lookahead
piece_state:    .byte 0
i:              .byte 0
j:              .byte 0
k:              .byte 0
timer1:         .byte 0, 30 // val, target
timer2:         .byte 0, 5  // val, target
is_falling:     .byte 0     // bool
moving_dir:     .byte 0    // 0:none, 1:left, 2:right
draw_mode:      .byte 0     // 0:erase, 1:draw, 
var_add0:       .word 0     // used by add2 and add3 
var_add1:       .word 0 
var_add2:       .word 0 
var_add3:       .word 0
// tetromino data        
piece_o:        
        .byte 1 // number of states
        .byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
piece_i:        
        .byte 2
        //.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0
        .byte 0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0

.import source "math.asm"

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

/////////////////////////////////////////
        
flip_page:
        ldx $d018
        lda page
        and #1
        beq flop
flip:
        lda #$00
        sta $f9
        lda #$08
        sta $fa
        txa
        and #%00001111
        ora #%00010000
        jmp !continue+
flop:
        lda #$00
        sta $f9
        lda #$04
        sta $fa
        txa
        and #%00001111
        ora #%00100000
!continue:
        sta $d018
        inc page
        rts
        
/////////////////////////////////////////
        
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

//////////////////////////////////////////

// explicitly set 1000 cells to off        
erase_screen:
        lda $f9 // copy to working ptr
        sta $fb
        lda $fa
        sta $fc
        ldx #0
!xloop4:        
        ldy #0                
!yloop250:
        lda #32 // cell off
        sta ($fb),y
        iny
        cpy #250
        bne !yloop250-
        // switch to next block of 250 cells        
        lda $fb
        sta var_add0
        lda $fc
        sta var_add0+1
        lda #250
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $fb
        lda var_add2+1
        sta $fc
        inx
        cpx #4
        bne !xloop4-
        rts

//////////////////////////////////////////

draw_piece:                
        lda $f9         // var_add0 = ($f9)
        sta var_add0    
        lda $fa
        sta var_add0+1        
        lda pos
        ldx #40
        jsr mult
        stx var_add1  
        sta var_add1+1  // var_add1 = pos[0] * 40
        lda pos+1
        sta var_add2
        lda #0
        sta var_add2+1  // var_add2 = pos[1]
        jsr add3        // var_add3 = var_add0 + var_add1 + var_add2
        lda var_add3
        sta $fb
        lda var_add3+1
        sta $fc
        lda #0
        sta k   // 0 to 15
        lda #0
        sta i   // 0 to 3
!row_i:        
        lda #0
        sta j   // 0 to 3
!col_j:        
        ldy k
        lda ($fd),y   // use tetromino data offset (k)
        beq !cell_off+
        lda #160
        ldy j
        sta ($fb),y   
!cell_off:
        inc k
        inc j
        lda j
        cmp #4
        bne !col_j-
        lda $fb        // add 40 (i.e. go to next line)
        sta var_add0
        lda $fc
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $fb
        lda var_add2+1
        sta $fc
        inc i
        lda i
        cmp #4
        bne !row_i-        
        rts

//////////////////////////////////////////

erase_piece: 
        lda $f9         // var_add0 = ($f9)
        sta var_add0    
        lda $fa
        sta var_add0+1        
        lda pos
        ldx #40
        jsr mult
        stx var_add1  
        sta var_add1+1  // var_add1 = pos[0] * 40
        lda pos+1
        sta var_add2
        lda #0
        sta var_add2+1  // var_add2 = pos[1]
        jsr add3        // var_add3 = var_add0 + var_add1 + var_add2
        lda var_add3
        sta $fb
        lda var_add3+1
        sta $fc
        ldx #0
!row_x:        
        ldy #0
!col_y:        
        lda #33
        sta ($fb),y
        iny 
        cpy #4
        bne !col_y-
        lda $fb        // add 40 (i.e. go to next line)
        sta var_add0
        lda $fc
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $fb
        lda var_add2+1
        sta $fc
        inx
        cpx #4
        bne !row_x-        
        rts
        
//////////////////////////////////////////
                        
main:

        lda #$00
        sta $f9
        lda #$04
        sta $fa        
        jsr erase_screen // clear page 1

        lda #$00
        sta $f9
        lda #$08
        sta $fa        
        jsr erase_screen // clear page 0
        
        lda #128
        sta $028a // set key autorepeat
                
        // set 3 parts of grid outline in solid:

        // (1) bottom        
        lda #1
        ldx #0
!loop:
        sta $2041,x // $07a6 = 1024 + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-

/*        
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
*/        
                        
        lda #0
        sta piece_state

        // make $fd point to piece data 
        lda #<piece_i
        sta $fd
        lda #>piece_i
        sta $fe
        lda $fd
        sta var_add0
        lda $fe
        sta var_add0+1        
        lda piece_state
        ldx #16
        jsr mult
        inx
        stx var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $fd
        lda var_add2+1
        sta $fe

        jsr draw_piece

/*
        jsr erase_piece
        inc pos
        jsr draw_piece
        jsr flip_page
        
        jsr erase_piece
        inc pos
        jsr draw_piece
        jsr flip_page
        
        jsr erase_piece
        inc pos
        jsr draw_piece
        jsr flip_page

        jmp *
        
        lda $d018
        and #%00001111
        ora #%00010000
        sta $d018
        
        jmp *

        jsr erase_piece
        inc pos
        jsr draw_piece
        jsr flip_page
        
        jmp *
*/
                        
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
        
        jsr erase_screen // prepare next page
        inc pos
        jsr draw_piece
        jsr flip_page
        
        lda #0
        sta is_falling
        jmp main_loop        
do_left:
        //lda #1
        //jsr can_move // can move left?
        //beq main_loop

        jsr erase_screen // prepare next page
        dec pos+1       // piece left
        jsr draw_piece
        jsr flip_page

        lda #0
        sta moving_dir
        jmp main_loop
do_right:
        //lda #2
        //jsr can_move // can move right?
        //beq main_loop

        jsr erase_screen // prepare next page
        inc pos+1       // piece right
        jsr draw_piece
        jsr flip_page

        lda #0
        sta moving_dir
        jmp main_loop
