/*        
  8 bit multiplication, written by Damon Slye
  call:	  accu: multiplier
      	  x-register: multiplicant
  return:   product in accu (hibyte) and x-register (lowbyte)
*/
mult:
        cpx #$00
	beq end
	dex
	stx mod+1
	lsr
	sta $02
	lda #$00
	ldx #$08
loop:   bcc skip
mod:    adc #$00
skip:   ror     
	ror $02
	dex
	bne loop
	ldx $02
	rts
end:    txa
	rts

/*
   16-bit addition: var_add2 = var_add0 + var_add1
*/
add2:
        clc
        lda var_add0
        adc var_add1
        sta var_add2
        lda var_add0+1
        adc var_add1+1
        sta var_add2+1
        rts
        
/*
   16-bit addition: var_add3 = var_add0 + var_add1 + var_add2
*/
add3: 
        // process add1 first 
        clc 
        lda var_add0 
        adc var_add1 
        sta var_add3 
        lda var_add0+1 
        adc var_add1+1 
        sta var_add3+1 
        // now add add2 
        clc 
        lda var_add3 
        adc var_add2 
        sta var_add3 
        lda var_add3+1 
        adc var_add2+1 
        sta var_add3+1 
        rts

/*        
add3:
        clc
        lda var_add0
        adc var_add1
        adc var_add2
        sta var_add3
        lda var_add0+1
        adc var_add1+1
        adc var_add2+1
        sta var_add3+1
        rts
*/        
        
        