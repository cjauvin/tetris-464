/*        
  8 bit multiplication, written by Damon Slye
  call:	  accu: multiplier
      	  x-register: multiplicant
  return:   product in accu (hibyte) and x-register (lowbyte)
*/
mult:   cpx #$00
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
   16-bit addition: vw2 = vw0 + vw1
*/
add2:   clc
        lda vw0
        adc vw1
        sta vw2
        lda vw0+1
        adc vw1+1
        sta vw2+1
        rts
/*
   16-bit addition: vw3 = vw0 + vw1 + vw2
*/
add3:   clc
        lda vw0
        adc vw1
        adc vw2
        sta vw3
        lda vw0+1
        adc vw1+1
        adc vw2+1
        sta vw3+1
        rts
        
        