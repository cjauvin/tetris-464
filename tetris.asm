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
       $f7: start of current video page (flips between $0400 and $0800)
       $f9: working ptr for draw/erase operations (gets incremented from ($f7))
       $fb: buffer of "solidifed" cells (outline grid + fixed pieces)
       $fd: current piece data

   Keyboard controls:
       'A': left
       'D': right
       (W/S not still implemented)
        
*/        
        
:BasicUpstart2(main) // autostart macro

.pc = $2000 "Variables and data"
solidified:     .fill 1000, 0
page:           .byte 0     // last bit as toggle
use_page_flipping:
                .byte 1     // set to 0 to turn off
pos:            .byte 0, 18 // starting pos: top center        
pos_ahead:      .word 0     // move lookahead
state:          .byte 0     //
state_ahead:    .byte 0        
i:              .byte 0     // 0 to 3
j:              .byte 0     // 0 to 3
k:              .byte 0     // i * 4 + j
timer1:         .byte 0, 30 // current value, target
timer2:         .byte 0, 5  // 
is_falling:     .byte 0     // bool
check_keyboard: .byte 0     // bool
var_add0:       .word 0     // used by math.asm add2 and add3 
var_add1:       .word 0  
var_add2:       .word 0 
var_add3:       .word 0
is_w_key_pressed:
                .byte 0     // bool
// tetromino data        
piece_i:        
        .byte 2 // number of states
        .byte 0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0 // |
        .byte 0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0 // -
piece_o:        
        .byte 1 
        .byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
// ..others soon to come!        

.import source "math.asm"

//////////////////////////////////////////////////////////////////////

// set kbd and falling anim flags according to timers        
raster_interrupt_handler:
        pha // not sure if register state preserving is really needed?
        txa
        pha
        tya
        pha
check_timer1:   
        lda timer1
        cmp timer1+1
        bne !wait+
        lda #1
        sta is_falling // set falling animation flag
        lda #0
        sta timer1     // reset animation timer
        jmp check_timer2
!wait:
        inc timer1
check_timer2:
        lda timer2
        cmp timer2+1
        bne !wait+
        lda #1
        sta check_keyboard // set check kbd flag
        lda #0
        sta timer2     // reset kbd check timer
        jmp !done+
!wait:
        inc timer2        
!done:
        lda #$ff  // needed?
        sta $d019
        pla 
        tay 
        pla
        tax  
        pla  
        rti  
        
//////////////////////////////////////////////////////////////////////
        
// toggles video ram between $0400 and $0800
flip_page:
        lda use_page_flipping
        bne !continue+
        rts
!continue:                
        ldx $d018
        lda page
        and #1
        beq flop
flip:
        lda #$00
        sta $f7
        lda #$08
        sta $f8
        txa
        and #%00001111
        ora #%00010000
        jmp !continue+
flop:
        lda #$00
        sta $f7
        lda #$04
        sta $f8
        txa
        and #%00001111
        ora #%00100000
!continue:
        sta $d018
        inc page
        rts
        
//////////////////////////////////////////////////////////////////////

// draw piece in current video ram, at current position (pos)
draw_piece:                
        lda $f7         // var_add0 = ($f7)
        sta var_add0    
        lda $f8
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
        sta $f9
        lda var_add3+1
        sta $fa
        lda #0
        sta k   // 0 to 15 (i * 4 + j)
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
        sta ($f9),y   
!cell_off:
        inc k
        inc j
        lda j
        cmp #4
        bne !col_j-
        lda $f9        // += 40 (i.e. go to next line)
        sta var_add0
        lda $fa
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $f9
        lda var_add2+1
        sta $fa
        inc i
        lda i
        cmp #4
        bne !row_i-        
        rts

//////////////////////////////////////////////////////////////////////

// functions to add grid outline "fixed" cells to the "solidified" buffer
        
init_grid_outline_side:
        ldx #0
        ldy #0
!loop:
        clc         
        lda $fb
        adc #40
        sta $fb
        lda $fc
        adc #00
        sta $fc
        lda #160
        sta ($fb),y
        inx
        cpx #21
        bne !loop-
        rts

init_grid_outline:

        // (1) bottom        
        lda #1
        ldx #0
!loop:
        sta $23a6,x // 8192 + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-

        // (2) left
        lda #$36    // 8192 + (1 * 40) + 14
        sta $fb
        lda #$20
        sta $fc        
        jsr init_grid_outline_side
        
        // (3) right
        lda #$41    // 8192 + (1 * 40) + 25
        sta $fb
        lda #$20
        sta $fc        
        jsr init_grid_outline_side

        rts

//////////////////////////////////////////////////////////////////////

// blank screen while adding current solidified cells      
redraw_screen:  
        lda $f7 // copy video ptr to working ptr
        sta $f9
        lda $f8
        sta $fa

        lda #<solidified
        sta $fb
        lda #>solidified
        sta $fc
        
        ldx #0
!xloop4:        
        ldy #0                
!yloop250:
        lda ($fb),y // if solidified cell at location..
        bne cell_on // set cell on
        lda #32 // if not, set cell off
        jmp !continue+
cell_on:
        lda #160
!continue:        
        sta ($f9),y
        iny
        cpy #250
        bne !yloop250-

        // switch to next block of 250 cells        
        lda $f9           // current video pointer += 250
        sta var_add0
        lda $fa
        sta var_add0+1
        lda #250
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $f9
        lda var_add2+1
        sta $fa
        
        lda $fb           // solidified pointer += 250
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

//////////////////////////////////////////////////////////////////////

/*
   Input:  
      acc: 0=down, 1=left, 2=right, 3=rotate
   Output:
      acc=bool
*/
can_move:       
        ldx pos         // pos_ahead is the queried possible next position
        ldy pos+1
        stx pos_ahead
        sty pos_ahead+1
        ldx state
        stx state_ahead
        cmp #0
        beq test_down
        cmp #1
        beq test_left
        cmp #2
        beq test_right
        cmp #3
        beq test_rotate
test_down:
        inc pos_ahead
        jmp !continue+
test_left:
        dec pos_ahead+1
        jmp !continue+
test_right:
        inc pos_ahead+1
        jmp !continue+
test_rotate:
        ldx state_ahead
        inx
        cpx piece_i // piece_i is hardcoded for the moment
        bne !inc_state_ahead+
        ldx #0
!inc_state_ahead:
        stx state_ahead
        ldy #1 // use state_ahead
        jsr update_piece_data_pointer
        
!continue:        
        lda $f7         // var_add0 = ($f7)
        sta var_add0    
        lda $f8
        sta var_add0+1        
        lda pos_ahead
        ldx #40
        jsr mult
        stx var_add1  
        sta var_add1+1  // var_add1 = pos[0] * 40
        lda pos_ahead+1
        sta var_add2
        lda #0
        sta var_add2+1  // var_add2 = pos[1]
        jsr add3        // var_add3 = var_add0 + var_add1 + var_add2
        lda var_add3
        sta $f9
        lda var_add3+1
        sta $fa

        lda #<solidified
        sta var_add0    
        lda #>solidified
        sta var_add0+1        
        lda pos_ahead
        ldx #40
        jsr mult
        stx var_add1  
        sta var_add1+1  
        lda pos_ahead+1
        sta var_add2
        lda #0
        sta var_add2+1  
        jsr add3        
        lda var_add3
        sta $fb
        lda var_add3+1
        sta $fc
        
        lda #0
        sta k   // 0 to 15 (i * 4 + j)
        lda #0
        sta i   // 0 to 3
!row_i:        
        lda #0
        sta j   // 0 to 3
!col_j:        
        ldy k
        lda ($fd),y   // use tetromino data offset (k): is there a cell at location?
        beq !continue+
        ldy j
        lda ($fb),y   // and is there also a solidified cell at loc?
        beq !continue+
        ldy #0 // restore normal state ptr
        jsr update_piece_data_pointer
        lda #0
        rts           // if yes, collision detected, return right away
!continue:
        inc k
        inc j
        lda j
        cmp #4
        bne !col_j-

        lda $f9        // current video ptr += 40 (i.e. go to next line)
        sta var_add0
        lda $fa
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $f9
        lda var_add2+1
        sta $fa

        lda $fb        // solidified ptr += 40 (i.e. go to next line)
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
        lda #1        // no collision found
        ldy #0 // restore normal state ptr
        jsr update_piece_data_pointer
        rts

//////////////////////////////////////////////////////////////////////

// make $fd point to piece data (with respect to piece and state vars)
// y: 0=use state, 1=use state_ahead
update_piece_data_pointer:      
        lda #<piece_i // piece_i is hardcoded for the moment
        sta $fd
        lda #>piece_i
        sta $fe
        lda $fd
        sta var_add0
        lda $fe
        sta var_add0+1

        cpy #1
        beq !use_state_ahead+
        lda state
        jmp !continue+
!use_state_ahead:
        lda state_ahead

!continue:        
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
        rts
        
//////////////////////////////////////////////////////////////////////
        
main:

        lda #$00
        sta $f7
        lda #$08
        sta $f8        
        jsr redraw_screen // clear page 1

        lda #$00
        sta $f7
        lda #$04
        sta $f8        
        jsr redraw_screen // clear page 0 (that's the one we're first pointing to)

        jsr init_grid_outline
                        
        lda #0
        sta state
        ldy #0 // use state (i.e. not state_ahead)
        jsr update_piece_data_pointer
        
        jsr redraw_screen
        jsr draw_piece
        jsr flip_page
        
        // set interrupt handler
        // taken from: http://codebase64.org/doku.php?id=base:introduction_to_raster_irqs
        sei        //disable maskable IRQs
        lda #$7f
        sta $dc0d  //disable timer interrupts which can be generated by the two CIA chips
        sta $dd0d  //the kernal uses such an interrupt to flash the cursor and scan the keyboard, so we better
                   //stop it.
        lda $dc0d  //by reading this two registers we negate any pending CIA irqs.
        lda $dd0d  //if we don't do this, a pending CIA irq might occur after we finish setting up our irq.
                   //we don't want that to happen.
        lda #$01   //this is how to tell the VICII to generate a raster interrupt
        sta $d01a
        lda #$fc   //this is how to tell at which rasterline we want the irq to be triggered
        sta $d012
        lda #$1b   //as there are more than 256 rasterlines, the topmost bit of $d011 serves as
        sta $d011  //the 8th bit for the rasterline we want our irq to be triggered.
                   //here we simply set up a character screen, leaving the topmost bit 0.
        lda #$35   //we turn off the BASIC and KERNAL rom here
        sta $01    //the cpu now sees RAM everywhere except at $d000-$e000, where still the registers of
                   //SID/VICII/etc are visible
        lda #<raster_interrupt_handler  //this is how we set up
        sta $fffe  //the address of our interrupt code
        lda #>raster_interrupt_handler
        sta $ffff
        cli        //enable maskable interrupts again

//////////////////////////////////////////////////////////////////////
        
main_loop:
        lda is_falling
        bne do_fall
        lda check_keyboard
        bne scan_keyboard
        jmp main_loop
scan_keyboard: 
        lda #$fd // check A key
        sta $dc00
        lda $dc01
        cmp #$fb
        beq do_left
        lda #$fb // check D key
        sta $dc00
        lda $dc01
        cmp #$fb
        beq do_right

        lda is_w_key_pressed // is W already pressed?
        bne debounce_w // yes, debounce it
        lda #$fd // no, check it
        sta $dc00
        lda $dc01
        cmp #$fd
        bne main_loop // not pressed
        lda #1        // yes, set for debounce
        sta is_w_key_pressed
        
        jmp main_loop
        
debounce_w:
        lda #$fd // check for not-W (i.e. W release)
        sta $dc00
        lda $dc01
        cmp #$fd
        bne do_rotate
        jmp main_loop        
do_fall:
        lda #0
        jsr can_move // can move down?
        beq !continue+
        jsr redraw_screen // prepare next page
        inc pos
        jsr draw_piece
        jsr flip_page
!continue:        
        lda #0
        sta is_falling // stop falling
        jmp main_loop        
do_left:
        lda #1
        jsr can_move // move left possible?
        beq !continue+
        jsr redraw_screen // prepare next page
        dec pos+1         // piece left
        jsr draw_piece
        jsr flip_page
!continue:        
        lda #0
        sta check_keyboard       
        jmp main_loop        
do_right:
        lda #2
        jsr can_move // move right possible??
        beq !continue+
        jsr redraw_screen // prepare next page
        inc pos+1       // piece right
        jsr draw_piece
        jsr flip_page
!continue:        
        lda #0
        sta check_keyboard        
        jmp main_loop
do_rotate:

        lda #3
        jsr can_move // rotation possible?
        beq !continue+
        
        ldx state
        inx
        cpx piece_i // piece_i is hardcoded for the moment
        bne !inc_state+
        ldx #0
!inc_state:
        stx state
        ldy #0 // use state
        jsr update_piece_data_pointer
                        
        jsr redraw_screen // prepare next page
        jsr draw_piece
        jsr flip_page

!continue:        
        lda #0
        sta check_keyboard        

        lda #0        // reset key
        sta is_w_key_pressed

        jmp main_loop
        