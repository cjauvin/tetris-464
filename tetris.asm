/*
    tetris.asm (C=64)
    =================
    Christian Jauvin
    June 2012
    cjauvin@gmail.com
    http://christianjauv.in

    Assemble into a ".prg" with KickAssembler (http://theweb.dk/KickAssembler),
    and optionally run with x64 (from the VICE emu suite):
    
    $ java -jar KickAss.jar tetris.asm [-execute x64]

    With the "-execute" option, it should autoload/start.
        
    Keyboard controls:
        'A': left
        'D': right
        'W': rotate
        'S': speed up fall        

    ZP pointers (for data structures requiring indirect indexing):
        $f7: start of current video page (flips between $0400 and $0800)
        $f9: buffer of "frozen" cells (outline grid + fixed pieces)
        $fb: current piece data    
        $fd: current piece data state
        $b0: helper ptr        
*/        
        
:BasicUpstart2(main) // autostart macro

.pc = $2000 "Variables and data"
frozen:         .fill 1000, 0 // frozen cells (bools)
page:           .byte 0       // last bit as toggle
use_page_flipping:
                .byte 1       // set to 0 to turn off
is_page_flipping_required:
                .byte 0
d018_value:     .byte 0
pos:            .word 0       // lowbyte: row (0 to 24), hibyte: col (0 to 39)
pos_ahead:      .word 0       // lateral move lookahead for collision detection
state:          .byte 0       // piece rotation lookahead for collision detection
state_ahead:    .byte 0        
z:              .byte 0       /* used to map row/col piece indices to a single value (z = x * 4 + j)
                                 I suspect that there might a clever bitwise way of doing it (that wouldn't
                                 require a variable at all, but for the moment that will dd)
                              */
timer1:         .byte 0, 30   // falling animation (current value, target)
timer2:         .byte 0, 3    // keyboard check (idem)
is_falling:     .byte 0       // bool
check_keyboard: .byte 0       // bool
var_add0:       .word 0       // used by math.asm add2 and add3 
var_add1:       .word 0  
var_add2:       .word 0 
var_add3:       .word 0
is_w_key_pressed:
                .byte 0     // bool, to debounce
is_s_key_pressed:
                .byte 0     // idem
// tetromino data        
piece_i:        
        .byte 2 // number of states
        .byte 0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0 // |
        .byte 0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0 // -
piece_s:
        .byte 2
        .byte 0,0,0,0,0,0,1,0,0,1,1,0,0,1,0,0
        .byte 0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,0
piece_z:
        .byte 2
        .byte 0,0,0,0,1,0,0,0,1,1,0,0,0,1,0,0
        .byte 0,0,0,0,0,0,0,0,0,1,1,0,1,1,0,0
piece_t:
        .byte 4
        .byte 0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0 
        .byte 0,1,0,0,0,1,1,0,0,1,0,0,0,0,0,0 
        .byte 0,0,0,0,1,1,1,0,0,1,0,0,0,0,0,0 
        .byte 0,1,0,0,1,1,0,0,0,1,0,0,0,0,0,0
piece_o:        
        .byte 1 
        .byte 0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0
piece_l:
        .byte 4
        .byte 0,1,0,0,0,1,0,0,0,1,1,0,0,0,0,0
        .byte 0,0,0,0,1,1,1,0,1,0,0,0,0,0,0,0
        .byte 1,1,0,0,0,1,0,0,0,1,0,0,0,0,0,0
        .byte 0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0
piece_j:
        .byte 4
        .byte 0,1,0,0,0,1,0,0,1,1,0,0,0,0,0,0
        .byte 1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0
        .byte 0,1,1,0,0,1,0,0,0,1,0,0,0,0,0,0
        .byte 0,0,0,0,1,1,1,0,0,0,1,0,0,0,0,0
        
.import source "math.asm"

//////////////////////////////////////////////////////////////////////

// set kbd and falling anim flags according to timers        
raster_interrupt_handler:

        pha // not sure if register state preserving is really needed?
        txa
        pha
        tya
        pha        
        lda is_page_flipping_required // commit page flipping if required
        beq check_timer1
        lda d018_value
        sta $d018
        lda #0
        sta is_page_flipping_required        
check_timer1:   
        lda timer1
        cmp timer1+1
        bne !wait+
        lda #1         // timer1 has reached its target value
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
        
// toggles video ram between $0400 and $0800 (actually just engage it,
// as the actual toggling need to be performed in the raster irq)
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
        sta d018_value
        lda #1
        sta is_page_flipping_required // wait until until in the irq to commit the change to $d018
        inc page
        rts
        
//////////////////////////////////////////////////////////////////////

// draw piece in current video ram, at current position (pos)
draw_piece:                

        // jump to video location: base_loc + (pos[0] * 40) + pos[1]
                
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
        sta $b0         // working ptr (will be incremented)
        lda var_add3+1
        sta $b1
        lda #0
        sta z   // 0 to 15 (x * 4 + y)
        ldx #0  // 0 to 3
!row_x:        
        ldy #0  // 0 to 3
!col_y:
        tya
        pha // push y on stack (to let the z var use y)
        ldy z
        lda ($fd),y   // use tetromino data offset (k)
        beq !cell_off+
        pla // pop y back
        tay
        lda #160        
        sta ($b0),y
        jmp !continue+                
!cell_off:
        pla // pop y back
        tay
!continue:                
        inc z
        iny
        cpy #4
        bne !col_y-
        lda $b0        // += 40 (i.e. go to next line)
        sta var_add0
        lda $b1
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $b0
        lda var_add2+1
        sta $b1
        inx
        cpx #4
        bne !row_x-        
        rts

//////////////////////////////////////////////////////////////////////

// functions to add grid outline cells to the "frozen" buffer,
// to ease collision detection                
init_grid_outline_side:

        ldx #0
        ldy #0
!loop:
        clc         
        lda $f9
        adc #40
        sta $f9
        lda $fa
        adc #00
        sta $fa
        lda #1
        sta ($f9),y
        inx
        cpx #21
        bne !loop-
        rts

init_grid_outline:

        // (1) bottom        
        lda #1 /// cell on
        ldx #0
!loop:
        sta $23a6,x // frozen + (23 * 40) + 14
        inx
        cpx #12
        bne !loop-
        // (2) left
        lda #$36    // 8192 + (1 * 40) + 14
        sta $f9
        lda #$20
        sta $fa        
        jsr init_grid_outline_side        
        // (3) right
        lda #$41    // 8192 + (1 * 40) + 25
        sta $f9
        lda #$20
        sta $fa        
        jsr init_grid_outline_side
        rts

//////////////////////////////////////////////////////////////////////

// set cells off in frozen buffer (in 4 blocks of 250 cells)
clear_frozen:

        lda #<frozen
        sta $f9
        lda #>frozen
        sta $fa        
        ldx #0
!xloop4:        
        ldy #0                
!yloop250:
        lda #0 // cell off
        sta ($f9),y
        iny
        cpy #250
        bne !yloop250-
        // switch to next block of 250 cells        
        lda $f9           // frozen pointer += 250
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
        inx
        cpx #4
        bne !xloop4-
        rts
                
//////////////////////////////////////////////////////////////////////

// redraw video while adding current frozen cells (in 4 blocks of 250 cells)        
redraw_screen:  

        lda $f7 // copy video ptr to working ptr
        sta $b0
        lda $f8
        sta $b1

        lda #<frozen
        sta $f9
        lda #>frozen
        sta $fa
        
        ldx #0
!xloop4:        
        ldy #0                
!yloop250:
        lda ($f9),y // if frozen cell at location..
        bne cell_on // set cell on
        lda #32 // if not, set cell off
        jmp !continue+
cell_on:
        lda #160
!continue:        
        sta ($b0),y
        iny
        cpy #250
        bne !yloop250-

        // switch to next block of 250 cells        
        lda $b0           // current video pointer += 250
        sta var_add0
        lda $b1
        sta var_add0+1
        lda #250
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $b0
        lda var_add2+1
        sta $b1
        
        lda $f9           // frozen pointer += 250
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
        inc state_ahead
        lda state_ahead
        ldy #0
        cmp ($fb),y
        bne !inc_state_ahead+
        sty state_ahead // reset state to 0
!inc_state_ahead:
        ldy #1 // use state_ahead
        jsr update_piece_data_pointer        
!continue:        

        // jump to video location: base_loc + (pos[0] * 40) + pos[1]
        
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
        sta $b0
        lda var_add3+1
        sta $b1

        // jump to frozen location: base_loc + (pos[0] * 40) + pos[1]
                
        lda #<frozen
        sta var_add0    
        lda #>frozen
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
        sta $f9
        lda var_add3+1
        sta $fa

        lda #0
        sta z   // 0 to 15 (x * 4 + y)
        ldx #0    // 0 to 3
!row_x:        
        ldy #0    // 0 to 3        
!col_y:
        lda ($f9),y    // is there a frozen cell at loc?
        beq !continue+ // if not, no collision possible, continue
        tya
        pha // push y on stack (to let the z var use y)
        ldy z
        lda ($fd),y   // use tetromino data offset (k): is there also a piece cell at location (there's already a frozen cell)?
        beq !no_piece_coll+ // there's a frozen cell, but no piece cell, so no collision finally: pop y from stack, and continue
        pla         // clear stack of its item (very important!)
        ldy #0      // restore normal state ptr
        jsr update_piece_data_pointer
        lda #0
        rts         // collision detected, return right away
!no_piece_coll:
        pla         // pop y back
        tay                
!continue:
        inc z
        iny
        cpy #4
        bne !col_y-        

        lda $b0        // current video ptr += 40 (i.e. go to next line)
        sta var_add0
        lda $b1
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr add2
        lda var_add2
        sta $b0
        lda var_add2+1
        sta $b1

        lda $f9        // frozen ptr += 40 (i.e. go to next line)
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
        
        inx
        cpx #4        
        bne !row_x-        
        ldy #0     // restore normal state ptr
        jsr update_piece_data_pointer
        lda #1     // no collision found
        rts

//////////////////////////////////////////////////////////////////////

// make $fd point to piece data (with respect to piece and state vars)
// y: 0=use state, 1=use state_ahead
update_piece_data_pointer:      

        lda $fb
        sta $fd
        lda $fc
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

// transfer a piece to the frozen buffer              
freeze_piece:

        // jump to frozen location: base_loc + (pos[0] * 40) + pos[1]
        
        lda #<frozen 
        sta var_add0
        lda #>frozen
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
        sta $f9         // working ptr (will be incremented)
        lda var_add3+1
        sta $fa                

        lda #0
        sta z   // 0 to 15 (i * 4 + j)
        ldx #0  // 0 to 3
!row_x:        
        ldy #0  // 0 to 3
!col_y:
        tya
        pha // push y on stack (to let the z var use y)
        ldy z
        lda ($fd),y   // use tetromino data offset (k)
        beq !cell_off+
        pla // pop y back
        tay        
        lda #1 // cell on
        sta ($f9),y
        jmp !continue+
!cell_off:
        pla // pop y back
        tay
!continue:        
        inc z
        iny
        cpy #4        
        bne !col_y-
        lda $f9        // loc += 40 (i.e. go to next line)
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
        inx
        cpx #4
        bne !row_x-        
        rts

//////////////////////////////////////////////////////////////////////

// $f9 -= #40        
shift_frozen_ptr_to_row_above:
        lda $f9
        sta var_add0
        lda $fa
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr sub2
        lda var_add2
        sta $f9
        lda var_add2+1
        sta $fa        
        rts

// $b0 -= #40        
shift_frozen_helper_ptr_to_row_above:
        lda $b0
        sta var_add0
        lda $b1
        sta var_add0+1
        lda #40
        sta var_add1
        lda #0
        sta var_add1+1
        jsr sub2
        lda var_add2
        sta $b0
        lda var_add2+1
        sta $b1        
        rts
        
// x is already set at proper value (row at which to begin the collapse)
collapse:
        lda $f9 // get frozen helper ptr, pointing one row above
        sta $b0
        lda $fa
        sta $b1
        jsr shift_frozen_helper_ptr_to_row_above                
!row_x:
        ldy #0
!col_y:
        lda ($b0),y // get what's one row above
        sta ($f9),y // and copy it to current row        
        iny
        cpy #10
        bne !col_y-
        jsr shift_frozen_ptr_to_row_above
        jsr shift_frozen_helper_ptr_to_row_above                
        inx
        cpx #20
        bne !row_x-                
        rts
        
clear_rows:
        lda #$7f // start at bottom row: frozen + (22 * 40) + 15
        sta $f9
        lda #$23
        sta $fa
        ldx #0
!row_x:        
        ldy #0 // cols
!col_y:        
        lda ($f9),y
        beq incomplete // hole found, go to next row (above)
        iny
        cpy #10
        bne !col_y-
complete:
        //inc $d020 // debug: change border color
        jsr collapse
        jmp clear_rows // we possibly need to redo it up to 4 times
incomplete:
        jsr shift_frozen_ptr_to_row_above
        inx
        cpx #20
        bne !row_x-
        rts
        
//////////////////////////////////////////////////////////////////////

get_random_number:
        lda $d012 
        eor $dc04 
        sbc $dc05
        rts

//////////////////////////////////////////////////////////////////////

pick_random_piece:

        // uncomment to always get piece_i
/*        
        ldx #<piece_i
        ldy #>piece_i
        stx $fb
        sty $fc        
        rts
*/        
        
        jsr get_random_number
        and #%00000111
        cmp #%00000000
        bne !next+
        ldx #<piece_i
        ldy #>piece_i
        jmp !found+
!next:        
        cmp #%00000001
        bne !next+
        ldx #<piece_s
        ldy #>piece_s
        jmp !found+
!next:        
        cmp #%00000010        
        bne !next+
        ldx #<piece_z
        ldy #>piece_z
        jmp !found+
!next:        
        cmp #%00000011        
        bne !next+
        ldx #<piece_t
        ldy #>piece_t
        jmp !found+
!next:        
        cmp #%00000100        
        bne !next+
        ldx #<piece_o
        ldy #>piece_o
        jmp !found+
!next:        
        cmp #%00000101        
        bne !next+
        ldx #<piece_l
        ldy #>piece_l
        jmp !found+
!next:        
        cmp #%00000110        
        bne pick_random_piece    // xxxxx111
        ldx #<piece_j
        ldy #>piece_j
!found:        
        stx $fb
        sty $fc        
        rts

//////////////////////////////////////////////////////////////////////

// With the value reached by $f9 (ptr in frozen buffer) in the last
// call to can_move, we know where the last piece was set; if it's
// less than a certain value, we know we are too high in the grid, and
// can thus set the game over flag (which will simply restart the game)
is_game_over:

        lda $fa  // hibyte first 
        cmp #$20
        bne no
        lda $f9  // lowbyte
        cmp #$f0
        bcs no   // if ($fc) is <= $f0 (6 rows from the top): game over
        lda #1
        rts
no:
        lda #0
        rts
        
//////////////////////////////////////////////////////////////////////

// start point        
main:

        // clear frozen buffer (in case the game is restarting after game over)
        jsr clear_frozen // clear frozen buffer (in case the game is restarting after game over)
        
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

        jsr pick_random_piece
        
        // reset piece pos and state
        lda #0
        sta pos
        lda #18   // starting pos: row=0, col=18
        sta pos+1
        lda #0
        sta state
        ldy #0 // use state (i.e. not state_ahead)
        jsr update_piece_data_pointer
        
        jsr redraw_screen
        jsr draw_piece
        jsr flip_page
        
        // interrupt handler, taken from: http://codebase64.org/doku.php?id=base:introduction_to_raster_irqs
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
        lda #$fa   //this is how to tell at which rasterline we want the irq to be triggered
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
        beq *+5
        jmp do_fall
        lda check_keyboard
        bne scan_keyboard
        jmp main_loop

scan_keyboard: 
        // non-debounced keys (A/D)
        
        lda #$fd // check A key
        sta $dc00
        lda $dc01
        cmp #$fb
        bne *+5
        jmp do_left

        lda #$fb // check D key
        sta $dc00
        lda $dc01
        cmp #$fb
        bne *+5 // beq do_right is too far!
        jmp do_right

        // debounced keys (W/S)
                
        lda is_w_key_pressed // is W already pressed?
        bne debounce_w // yes, debounce it
        lda #$fd // no, check it
        sta $dc00
        lda $dc01
        cmp #$fd
        bne check_s // not pressed, continue to check_s
        lda #1        // pressed: set for debounce
        sta is_w_key_pressed        
check_s:        
        lda is_s_key_pressed // is S already pressed?
        bne debounce_s // yes, debounce it
        lda #$fd // no, check it
        sta $dc00
        lda $dc01
        cmp #$df
        bne main_loop // not pressed, continue
        lda #3       // pressed: speed up timer1
        sta timer1+1
        lda #0
        sta timer1
        lda #1        // and set for debounce
        sta is_s_key_pressed        
        jmp main_loop                

debounce_w:
        lda #$fd // check for not-W (i.e. W release)
        sta $dc00
        lda $dc01
        cmp #$fd
        beq *+5
        jmp do_rotate // W release: rotate
        jmp main_loop

debounce_s:
        lda #$fd // check for not-S (i.e. S release)
        sta $dc00
        lda $dc01
        cmp #$df
        bne *+5        
        jmp main_loop    // still pressed, continue
        lda #30
        sta timer1+1   // S release: timer1 back to slow
        lda #0
        sta timer1
        lda #0        // reset key
        sta is_s_key_pressed
        jmp main_loop
                
do_fall:
        lda #0
        jsr can_move // can move down?
        beq reached_bottom
        jsr redraw_screen // prepare next page
        inc pos
        jsr draw_piece
        jsr flip_page
        lda #0
        sta is_falling // stop falling
        jmp main_loop        

reached_bottom:
        jsr is_game_over
        beq *+5  // if no continue
        jmp main // if yes, restart game        
        jsr freeze_piece
        jsr clear_rows
        jsr redraw_screen // prepare next page
        jsr flip_page
        lda #0
        sta is_falling // stop falling
        jsr pick_random_piece
        lda #0
        sta pos
        lda #18
        sta pos+1
        lda #0
        sta state
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
        inc state
        lda state
        ldy #0
        cmp ($fb),y        
        bne !inc_state+
        sty state // reset state to 0
!inc_state:
        jsr update_piece_data_pointer // with y still 0 -> use state
        jsr redraw_screen // prepare next page
        jsr draw_piece
        jsr flip_page
!continue:        
        lda #0
        sta check_keyboard        
        lda #0        // reset key
        sta is_w_key_pressed
        jmp main_loop
