$PAGEWIDTH 160 ; xiaolaba, format the listing file to be no 80 columns wrapping, no pages & breaks
$PAGELENGTH 1200
** copy Motorola AN463 software listing, removed all dummy content
** assembly with PE assembler, produce S19 file
** xiaolaba, 2018-OCT-16



***************************************************************
* INFRA RED REMOTE CONTROL FOR K0,K1                          *
***************************************************************
* WRITTEN BY A.BRESLIN    13.1.92                             *
***************************************************************
* THIS PROGRAM READS AND ENCODES A KEY FROM A 24 KEY KEYBOARD *
* TO A FORM OF BIPHASE PULSE CODE MODULATION (PCM) FOR INFRA  *
* RED TRANSMISSION. IT USES THE TRANSMISSION PROTOCOL OF THE  *
* MC144105 IR REMOTE CONTROL TRANSMITTER                      *
***************************************************************


porta   equ     00
portb   equ     01
ddra    equ     04
ddrb    equ     05
tcsr    equ     $08
papd    equ     $10

        org     $e0

keyst1  rmb     1               ; initial code from keyboard
keyst2  rmb     1               ; keycode
keyst3  rmb     1               ; code transmitted
dflag   rmb     1               ; flag for last and 9th bits


**************************************************************
* THE PORTS ARE SET UP USING PORTA 0-3 AS INPUTS MAKING USE  *
* OF THE INTERNAL INTERUPT GENERATION ON THESE I/0 LINES.    *
* STOP MODE IS ENTERED UNTIL A KEY IS PRESSED                *
**************************************************************

        org     $200

start   cli
wpres   bsr     setup
        rsp
        stop
        bra     wpres

setup   lda     #$f0            ; porta 0-3 inputs
        sta     ddra            ; 4-7 as outputs
        sta     porta           ; set outputs high
        sta     papd            ; 0-3 pulldown
        lda     #$03            ; portb 0-1 outputs
        sta     ddrb
        lda     #$01            ; set portb 0 high
        sta     portb
        rts

**************************************************************
* THE KEY READ IS DECODED FOR TRANSMISSION.                  *
* THE TRANSMISSION PROTOCOL REQUIRES A START MESSAGE OF 9    *
* ONES FOLLOWED BY THE KEYPRESSED CODE. THIS CODE IS         *
* CONTINUALLY RETRANSMITTED IF THE KEY IS HELD DOWN. AN END  *
* CODE OF 9 ONES TERMINATES THE TRANSMISSION AND THE DEVICE  *
* RETURNS TO STOP MODE.                                      *
**************************************************************

presd   bsr     keyscn          ; get key pressed
        lda     keyst2          ; save key to check
        sta     keyst1          ; if key held down
        bsr     decode          ; decode key pressed
        bset    1,dflag         ; set nineth bit to 1
        lda     #$ff            ; send start data
        sta     keyst3          ; to transmission routine
        bsr     trnmit          ; nine one's
sndagn  lda     keyst2          ; send key press message
        sta     keyst3          ; byte
        bclr    1,dflag         ; set nineth bit to 0
        bsr     trnmit
        lda     porta           ; check if key still pressed
        and     #$0f            ; end if no key pressed
        bne     endtrn
        bsr     keyscn          ; else check if same
        lda     keyst1          ; key pressed
        cmp     keyst2
        bne     endtrn          ; end if not
        ldx     #$c8            ; delay
tloop   decx                    ; before next
        bne     tloop           ; transmission
        bra     sndagn
endtrn  bset    1,dflag         ; send end message
        lda     #$ff            ; of nine ones
        sta     keyst3
        bsr     trnmit
        rti                     ; re-enter stop mode

**************************************************************
* WHEN A KEY IS PRESSED THE DEVICE COMES OUT OF STOP MODE    *
* THE KEYBOARD IS SCANNED TO SEE WHICH KEY IS PRESSED        *
**************************************************************

keyscn  jsr     datwt           ; wait for debounce
        lda     porta           ; check if key press
        sta     keyst1          ; store inputs
        and     #$0f            ; mask outputs
        beq     start           ; stop if no key pressed
        ldx     #$ef            ; set one row low
nxtrow  txa                     ; read ouput lines
        and     keyst1          ; combine with inputs
        sta     keyst2          ; store key code
        stx     porta           ; to find row which clears inputs
        lda     porta           ; check for inputs cleared
        and     #$0f            ; mask outputs
        beq     gotit           ; zero in key-press row clears inputs
        lslx                    ; check if last row
        incx                    ; set lsb to 1
        bcc     tryb            ; try portb output if not porta
        bra     nxtrow          ; try next porta output row

tryb    lda     keyst1
        sta     keyst2
        ldx     #$f0
        stx     porta           ; set all porta outputs high
        bclr    0,portb         ; set portb 0 output low
        lda     porta           ; check for inputs cleared
        and     #$0f            ; mask outputs
        beq     gotit           ; zero in key-press row clears inputs
        lda     keyst2          ;
        and     #$3f            ; set individual code since last row
        sta     keyst2          ; store code
gotit   bset    0,portb         ; set portb column high again
        rts

**************************************************************
* THE DECODE ROUTINE USES TWO ARRAYS. IT COMPARES THE KEY    *
* VALUE WITH THE ARRAY KEYDAT AND WHEN A MATCH IS FOUND THE  *
* CORRESPONDING ELEMENT IN THE ARRAY TVDAT BECOMES THE       *
* TRANSMITTED CODE.                                          *
**************************************************************

decode  ldx     #$18            ; data array offset to zero
nxtel   lda     keydat,x        ; look at each element of array
        cmp     keyst2          ; compare with key read
        beq     match           ; decode if match
        decx                    ; else try next element
        bne     nxtel           ; norm if no match found
match   lda     tvdat,x         ; get key code
        sta     keyst2          ; store code to transmit
        rts

**************************************************************
* THE TRANSMISSION PROTOCOL REQUIRES A PRE-BIT, A PRE-BIT    *
* PAUSE, A START BIT AND NINE DATA BITS, WHERE THE PRE-BIT   *
* AND THE START BIT ARE LOGIC '1'.                           *
**************************************************************

trnmit  bset    0,dflag         ; initialise for first bit
        bsr     send1           ; send pre-bit
        jsr     datwt           ; pre-bit pause
        jsr     datwt           ; equalling four half data period
        jsr     datwt           ;
        jsr     datwt           ;
        bsr     send1           ; send start bit
        ldx     #$08            ; transmit 8 data bits
nxtbit  lsr     keyst3          ; get next bit
        bcs     data1           ; send 1 if carry set
        bsr     send0           ; send 0 if carry clear
        bra     bitsnt
data1   bsr     send1
bitsnt  decx                    ; countdown bits sent
        bne     nxtbit          ; send next bit if count not zero
        brclr   1,dflag,send00  ; if flag set
        bsr     send1           ; send 1 as nineth bit
        bra     endend          ;
send00  bsr     send0           ; else send 0
endend  ldx     #$18
loopw   bsr     datwt           ; delay between successive
        bsr     datwt           ; transmissions
        bsr     datwt
        decx
        bne     loopw
        rts


**************************************************************
* TO TRANSMIT A LOGIC '1' A 32kHz PULSE TRAIN FOR 512us IS   *
* FOLLOWED BY A 512us PAUSE.                                 *
**************************************************************

send1   brclr   0,dflag,last0   ; check if last bit was zero
        lda     #$10            ; burst if last bit was 1
        bsr     burst           ; 32kHz pulse for 512us
last0   bsr     datwt           ; wait 512us
        bset    0,dflag         ; set flag as 1 sent
        rts

**************************************************************
* TO TRANSMIT A LOGIC '0' A 512us PAUSE IS FOLLOWED BY A     *
* 32kHz PULSE TRAIN FOR 512us. IF A LOGIC '1' FOLLOWS A '0'  *
* THE 32kHz IS CONTINUED FOR 1024us TO AVOID A PROCESSING    *
* DELAY                                                      *
**************************************************************

send0   bsr     datwt           ; wait 512us
        brset   0,keyst3,next1  ; check if next bit is 1
        lda     #$10            ; single burst if 1
        bra     datset          ; data set
next1   lda     #$20            ; double burst required
datset  bsr     burst           ; 32kHz pulse for 512us
        bclr    0,dflag         ; clear flag as 0 sent
        rts

**************************************************************
* THE 32kHz PULSE TRAIN HAS A MARK TO SPACE RATIO OF 1 TO 3  *
**************************************************************

burst   bclr    1,portb         ; portb 1 low
        brn     *
        bset    1,portb         ; portb 1 high
        brn     *
        bclr    1,portb         ; portb 1 low
        nop
        deca                    ; decrement count
        beq     endbur          ; end of burst ?
        bra     burst
endbur  rts


datwt   lda     #$52            ; count
loop    deca                    ; to provide 512us delay
        bne     loop            ; after instruction times
        rts

keydat  fcb     $31,$f1,$e1,$d1,$b1,$71
        fcb     $32,$f2,$e2,$d2,$b2,$72
        fcb     $34,$f4,$e4,$d4,$b4,$74
        fcb     $38,$f8,$e8,$d8,$b8,$78

tvdat   fcb     $11,$3e,$39,$10,$17,$14
        fcb     $12,$3d,$3b,$2c,$18,$15
        fcb     $13,$3c,$3a,$2d,$19,$16
        fcb     $00,$0d,$0c,$07,$06,$01


softin  rti

        org     $3fa

        fdb     presd           ; scan keybrd on int
        fdb     softin          ; software interrupt
        fdb     start           ; resett


;$NOLIST ; xiaolaba, format the listing file to be no 80 columns wrapping

