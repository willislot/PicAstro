             list p=16f1825
;**************************************************************
;*
;* Pinbelegung
;*      ---------------------------------- 
;*      PORTA:  0 ICSPDAT  
;*              1 ISCPCLK
;*              2 
;*              3 MCLR
;*              4 
;*		5 Key
;*      PORTC:  0 AN4 X
;*              1 AN5 Y
;*              2 CTS
;*              3 RTS
;*              4 TX
;*		5 RX
	     
;**************************************************************
; Für RFID Erkennung

;**************************************************************
; Includedatei für den 12F1840 einbinden
;
        #include <P16f1825.INC>
;
; Configuration 
;
; bis 4 MHz: Power on Timer, no Watchdog, XT-Oscillator
        __CONFIG  _CONFIG1,  _WDTE_OFF & _FOSC_INTOSC & _CLKOUTEN_OFF
	__CONFIG  _CONFIG2, _PLLEN_OFF & _STVREN_ON
;
;**************************************************************
t_clock		equ .96
timer_val	equ .50		
timeout		equ .200		
ll_cnt		equ .100
#define	altitude 0x11
#define azimut	0x10
; Altitude x
#define x_dir altitude
#define up_fast		0x09
#define	up_medium	0x07
#define up_slow		0x06
#define up_stop		0x00
#define down_fast	0x19
#define	down_medium	0x17
#define down_slow	0x16
#define down_stop	0x00
;Azimut y
#define y_dir azimut
#define right_fast	0x09
#define	right_medium	0x07
#define right_slow	0x06
#define right_stop	0x00
#define left_fast	0x19
#define	left_medium	0x17
#define left_slow	0x16
#define left_stop	0x00
		
reg_12		equ	0x20
reg_17		equ	0x21
res_x_cnt	equ	0x22
res_y_cnt	equ	0x23
cmd_x		equ	0x24
cmd_y		equ	0x25
rate_x		equ	0x26
rate_y		equ	0x27
snd_c_x		equ	0x28
snd_c_y		equ	0x29
snd_r_x		equ	0x2a
snd_r_y		equ	0x2B
check_sum	equ	0x2C
rec_poi		equ	0x2D
rec_cnt		equ	0x2E
snd_target	equ	0x2F
timerrec1	equ	0x30
timerrec2	equ	0x31
rec_mask	equ	0x32
key_ll		equ	0x33
key_cnt		equ	0x34
snd_buf		equ	0x38;-3FH
rec_buf1	equ	0x40	
rec_buf2	equ	0x50
a_reg		equ	0x70
b_reg		equ	0x71
c_reg		equ	0x72
bitleiste1	equ	0x73
x_adc		    equ	0x00
snd_lock	    equ	0x01
rec_quit	    equ	0x02
rec_echo	    equ	0x03
rec_ping	    equ	0x04
buf_ovl		    equ	0x05
buf_2		    equ	0x06
buf_1		    equ	0x07
bitleiste2	equ	0x74
key_act		equ	0x00
streceive	equ	0x75
stseriell	equ	0x76
stjoystick	equ	0x77
stadc		equ	0x78
;
; Bank 2

result_x	equ	0x20; -0x27
result_y	equ	0x24; -0x2f
	
		
	ORG     0x000             ; processor reset vector
		goto    init              ; go to beginning of program


		ORG     0x004             ; interrupt vector location
interrupt:
	    btfsc	INTCON,TMR0IF 
	    goto	timer0
int_t0ex:   movlw	0x00     ; switch to bank 0
	    movwf	BSR
	    btfsc	PIR1,RCIF
	    goto	rseriell
int_rvex:   movlw	0x01     ;  switch to bank 1
	    movwf	BSR
	    btfss	PIE1,TXIE
	    goto	int_txex
int_tsqex:  movlw	0x00    ;  switch to bank 0
	    movwf	BSR
	    btfsc	PIR1,TXIF
	    goto	tseriell
int_txex:    retfie


timer0:
;****************************************
;	timer
;	timeout after 10ms
;
;****************************************
	    movlw	0x00     ;  switch to bank 0
	    movwf	BSR
	    movlw	t_clock
	    movwf	TMR0
	    BANKSEL	LATA
	    movlw	0x04
	    xorwf	LATA,f
;            movlw	0x00
;            bcf		PORTA,RA2
;
;****************************************
;  Timeout Timerrec1
;****************************************
	    movlb	0x00
	    movfw	timerrec1
	    btfsc	STATUS,Z
	    bra		t0_rec1_end
	    sublw       0x01
	    btfss	STATUS,Z
	    bra		t0_rec1_end
	    bcf		bitleiste1,snd_lock
	    banksel	PIE1
	    bcf		PIE1,TXIE
	    clrf	BSR
t0_rec1_end: decf	timerrec1,1
;****************************************
;  send monitoring Timerrec2
;****************************************
	    movlb	0x00
	    movfw	timerrec2
	    btfsc	STATUS,Z
	    bra		t0_0count
	    sublw       0x01
	    btfss	STATUS,Z
	    bra		t0_rec1_2
	    bcf		bitleiste1,snd_lock
	   ; bcf		bitleiste1,rec_ping
	    bcf		bitleiste1,rec_echo
	    bcf		bitleiste1,rec_quit
	    movlw	0x01
	    movwf	BSR
	    bcf		PIE1,TXIE
	    clrf	BSR
t0_rec1_2:  decf	timerrec2,1
t0_0count:
;****************************************
;  sec counter
;****************************************
t0_s_count:  decf	reg_12,1
	    btfss	STATUS,Z
	    goto	t0_exit
            clrf	BSR
	    movlw	0x64	
	    movwf	reg_12
;*******************************************
;*10 sec                          *
;*******************************************
t0_end:	    incf	reg_17,1		;
	    movfw	reg_17		;
	    sublw	0x0a	;
	    btfss	STATUS,Z	;
	    goto	t0_exit		;
	    clrf	reg_17		;
	    
t0_exit:    bcf		INTCON,TMR0IF
	    goto	int_t0ex
rseriell:
;*****************************************
;*  serial Interrupt receive         *
;*****************************************
	    movlw	0x03
	    movwf	BSR
	    movlw	high  jmp_rcv
	    movwf	PCLATH
	    bcf		STATUS,C
	    				    ; übernahme aus 8051
	    movf	streceive,w
	    andlw	0x0f
	    addwf	PCL,f
jmp_rcv:     goto  rcv_0                   ; Ruhezustand, warte auf Flagbyte
             goto  rcv_1                   ; Kontrolle der Sendebytes: Flag
             goto  rcv_2                   ; Kontrolle der Sendebytes: Meldung
             goto  rcv_3
             goto  rcv_4                   ; Empfang der Meldung
             goto  rcv_5                   ; Empfang der Meldung
             goto  rcv_6                   ;
             goto  rcv_7                   ;
;******************************************;
;* 0:idle wait for Flag           *;
;******************************************;
rcv_0:	    
	    banksel	RCREG
	    movf	RCREG,w
	    sublw	0x3B
	    btfss	STATUS,Z
	    goto	rec_end                 ; und Ende
	    movfw	RCREG
	    movlb	0x00
	    movwf	rec_buf1
	    movlb	0x00
	    movlw	0x01
	    movwf	streceive
	    btfss	bitleiste1,buf_1
	    goto	rcv_0ex
	    addlw	(rec_buf2-rec_buf1)
	    bsf		bitleiste1,buf_ovl
	    movwf	rec_poi
	    movlw	0x3B
	    movwf	rec_buf2
	    goto	rec_end
rcv_0ex:    movwf	rec_poi
	    goto	rec_end
;******************************************;
;* 2 : wait for length                  *;
;******************************************;
rcv_1:      movlb	0x00
	    clrf	FSR0H
	    movlw	rec_buf1
	    addwf	rec_poi,w
	    incf	rec_poi,f
	    movwf	FSR0L
	    banksel	RCREG
	    movf	RCREG,W
	    movwf	INDF0
	    movlb	0x00
	    movwf	rec_cnt
	    movlw	0x02
	    movwf	streceive
	    goto    rec_end                 ; und Ende
;******************************************;
;*2:  receive  message                *;
;******************************************;
rcv_2:      movlb	0x00
	    clrf	FSR0H
	    movlw	rec_buf1
	    addwf	rec_poi,w
	    incf	rec_poi,f
	    movwf	FSR0L
	    banksel	RCREG
	    movf	RCREG,W
	    movwf	INDF0
	    movlb	0x00
	    decfsz	rec_cnt,f
	    goto	rec_end
	    movlw	0x03
	    movwf	streceive
	    goto        rec_end                 ; Ende
;******************************************;
;*3: receive CRC                          *;
;******************************************;
rcv_3:      movlb	0x00
	    clrf	FSR0H
	    movlw	rec_buf1
	    addwf	rec_poi,w
	    incf	rec_poi,f
	    movwf	FSR0L
	    banksel	RCREG
	    movf	RCREG,W
	    movwf	INDF0
	    clrf	streceive
	    btfsc	bitleiste1,buf_ovl
	    goto	rcv_3_ex
	    bsf		bitleiste1,buf_1
	    goto        rec_end
rcv_3_ex:   bcf		bitleiste1,buf_ovl
	    bsf		bitleiste1,buf_2
	    goto	rec_end
;
rcv_4:
rcv_5:
rcv_6:            goto       rec_end                 ; und Ende
;******************************************;
;*4: dummies       *;
;******************************************;
rcv_7:
rec_end:    
rec_ex:     
	     goto	int_rvex
;******************************************;
;* End  receive                 *;
;******************************************;

tseriell:
;******************************************;
;* Start  sending	                   *;
;******************************************;
 
ser_send:    
	    movlb	0x00
	    movlw	0x1F 
	    andwf	stseriell,W             ; Zustand laden
            bcf		STATUS,C
 	    brw
jmp_ser:     goto  ser_0                   ; Ruhezustand
             goto  ser_1                   ; 
             goto  ser_2                   ; 
             goto  ser_3                   ; 
             goto  ser_4                   ;
             goto  ser_5                   ; senden Füllzeichn
             goto  ser_6                   ; Senden der Parität
             goto  ser_7                   ; Warten aufs Ende
             goto  ser_8                   ; 
             goto  ser_9                  ; 
             goto  ser_A                   ;
	     goto  ser_B                  ; 
             goto  ser_C                   ;
             goto  ser_D                   ; Start Ping 10
	     goto  ser_E                   ;
             goto  ser_F                  ;
             goto  ser_10                  ; 
;******************************************;
;* idle                            *;
;******************************************;
ser_0:       
	    banksel	PIE1
	    bcf		PIE1,TXIE
	    goto  seriell_ex
;******************************************;
;*  1:x cmd send length                  *;
;******************************************;
ser_1:      movlw	0x03		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x04		    ;Meldungslänge
	    movwf	check_sum
	    banksel	TXREG
	    movwf	TXREG
	    goto	seriell_ex
;******************************************;
;*  2:y cmd send length                     *;
;******************************************;
ser_2:      movlw	0x04		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x04		    ;Meldungslänge
	    movwf	check_sum
	    banksel	TXREG
	    movwf	TXREG
	    goto       seriell_ex              ;
;******************************************;
;*  3 x originator                      *;
;******************************************;
ser_3:      movlw	0x05		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x20		    ;Absender
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
	    goto	seriell_ex
 ;******************************************;
;* 4: y originator                                *;
;******************************************;
ser_4:      movlw	0x06		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x20		    ;Absender
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
	    goto       seriell_ex              ;
;******************************************;
;* 5:target ALT Controller                        *;
;******************************************;
ser_5:      movlw	0x07		    ;nächster Zustand
	    movwf	stseriell
	    movfw	snd_target	    ;Ziel
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
            goto       seriell_ex        ;
;******************************************;
;* 6: targe AZM Controller                   *;
;******************************************;
ser_6:      movlw	0x08		    ;nächster Zustand
	    movwf	stseriell
	    movfw	snd_target		    ;Ziel
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
            goto	 seriell_ex
;******************************************;
;*  7: message ID X                       *;
;******************************************;
ser_7:      movlw	0x09		    ;nächster Zustand
	    movwf	stseriell
	    movf	snd_c_x,w		    ;message ID
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG		    ;
	    movwf	TXREG		    ;
            goto	seriell_ex
;******************************************;
;*  12: message ID y                     *;
;******************************************;
ser_8:      movlw	0x0A		    ;nächster Zustand
	    movwf	stseriell
	    movf	snd_c_y,w		    ;message ID
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG		    ;
	    movwf	TXREG		    ;
            goto       seriell_ex              ;
;******************************************;
;*   9 :Rate X                             *;
;******************************************;
ser_9:      movlw	0x0B		    ;nächster Zustand
	    movwf	stseriell
	    movf	snd_r_x,w		    ;Speed
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG		    ;
	    movwf	TXREG		    ;
            goto	seriell_ex
;******************************************;
;*  16: Rate y                    *;
;******************************************;
ser_A:      movlw	0x0B		    ;nächster Zustand
	    movwf	stseriell
	    movf	snd_r_y,w		    ;Speed
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG		    ;
	    movwf	TXREG		    ;
            goto       seriell_ex
;******************************************;
;* B: Checksum                            *;
;******************************************;
ser_B:      movlw	0x0C		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0xFF		    ;komplement
	    xorwf	check_sum,w	    ;Chesksum berechnen
	    incf	WREG,W
	    banksel	TXREG		    ;
	    movwf	TXREG		    ;
            goto	seriell_ex
;******************************************;
;*  C: EOT                  *;
;******************************************;
ser_C:	    
	    banksel	PIE1
	    bcf		PIE1,TXIE
	    clrf	stseriell
	    goto	seriell_ex
;******************************************;
;*   D: Length Ping                        *;
;******************************************;
ser_D:      movlw	0x0E		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x03		    ;Meldungslänge
	    movwf	check_sum
	    banksel	TXREG
	    movwf	TXREG
	    goto	seriell_ex
;
;******************************************;
;*  E: source Ping                        *;
;******************************************;
ser_E:      movlw	0x0F		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x20		    ;Absender
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
	    goto       seriell_ex
;******************************************;
;*   F: target Ping    *;
;******************************************;
ser_F:      movlw	0x10		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x10		    ;Absender
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
	    goto       seriell_ex
;******************************************;
;*   10: Ping    *;
;******************************************;
ser_10:      movlw	0x0B		    ;nächster Zustand
	    movwf	stseriell
	    movlw	0x01		    ;Absender
	    addwf	check_sum,f	    ;Chesksum berechnen
	    banksel	TXREG
	    movwf	TXREG
	    goto       seriell_ex
seriell_ex:
		movlb	0x00
	     movlw	timer_val
		banksel	PIR1
	     btfsc	PIR1,RCIF
	     goto       rseriell               ; sonst zum Empfangsprogramm
seriell_end:
	     goto	int_txex

	    
	    
	    
	    
	    
init:
; setup clock
	    banksel	OSCCON
;	    bcf		OSCCON,IRCF0	
;	    bsf		OSCCON,IRCF1
;	    bsf		OSCCON,IRCF2
;	    bsf		OSCCON,IRCF3
	    movlw	b'01011010'
			;b'11110000'
	    movwf	OSCCON
	    
; configure Ports 	
	    movlw   0x00     ; 
	    banksel	ANSELA
	    clrf	ANSELA
	    banksel	ANSELC
	    movlw	b'00000011'
	    movwf	ANSELC
	    movlw	0x01     ; switch to Bank 1
	    movwf	BSR
	    movlw	b'11101011' ;port A 
	    banksel	TRISA
	    movwf	TRISA
	    banksel	WPUA
	    movlw	b'00100000'
	    movwf       WPUA	    ; Pull up RA5
	    movlw	b'00101011' ; PortC  -/-/RX/TX/RTS/CTS/AN5/AN4
	    banksel	TRISC
	    movwf	TRISC
	    banksel	WPUC
	    clrf        WPUC	    ; Pull up off
	    
 ; USART Baudrate 
	    banksel	SPBRGL
	    movlw	.12	    ; 25 = 19200 bd
	    MOVWF	SPBRGL
	    banksel	SPBRGH
	    clrf	SPBRGH
	    banksel	TXSTA
	    BSF		TXSTA,BRGH     ; BRGH=1
	    banksel	BAUDCON
	    bsf		BAUDCON,BRG16	; BRG16=1
;initialize USART 
 	    banksel     APFCON0
	    bcf		APFCON0,RXDTSEL	;bcf = RC5
	    bcf		APFCON0,TXCKSEL	; bcf=RC4
	    banksel	TXSTA
  	    bcf		TXSTA,SYNC
	    bsf		TXSTA,TXEN
	    bcf		TXSTA,TX9
	    banksel	RCSTA
	    bCf		RCSTA,SYNC
	    bsf		RCSTA,CREN
	    bsf		RCSTA,SPEN
; Timer0 initialize 10ms
	    banksel	OPTION_REG
	    bcf		OPTION_REG,TMR0CS   ; Funktion = Timer
	    bsf		OPTION_REG,0	    ; Vorteiler 16
	    bsf		OPTION_REG,1	    ; 256000/16 = 16000
	    bcf		OPTION_REG,2	    ;
	    bcf		OPTION_REG,PSA	    ;Vorteiler aktivieren
	    bcf		OPTION_REG,7	    ;WPUEN
	    banksel	TMR0
	    movlw	t_clock	;
	    movwf	TMR0	;
; configure ADC
	    banksel	FVRCON	    ;
	    movlw	B'00000000'	    ;AD-Referenz aus und 2,048V
			;B'10000010'
	    movwf	FVRCON
	    banksel	ADCON1
	    movlw	B'00000000'	    ;Fosc/64 Vref=Vdd linksbündig
	    movwf	ADCON1
	    banksel	ADCON0
	    movlw   	B'00100001'	    ; chs = Ad4;ADC Stop ADC enabled
	    movwf	ADCON0	
; enable/disable Interrupts 
	    banksel	INTCON
	    bsf		INTCON,PEIE	;Peripherer Interrupt
	    bsf		INTCON,TMR0IE	; Timerinterrupt freigeben
	    banksel	PIE1
	    bsf		PIE1,RCIE	; Serielle Schnittstelle Empfang und
	    bcf		PIE1,TXIE	; SendeInterrupt erstmal sperren
	    banksel	INTCON
	    bsf		INTCON,GIE
	    movlb	0x00
	    clrf	stseriell
	    clrf	streceive
	    clrf	bitleiste1
	    clrf	bitleiste2
	    movlw	0x40
	    movwf	c_reg
	    clrf	FSR0H
	    movlw	0x01
	    movwf	FSR1H
	    movlw	0x20
	    movwf	FSR0L
	    movwf	FSR1L
	    movlw	0x00
init_loop:	movwi	    INDF0++
		movwi	    INDF1++
		decfsz	    c_reg,f
	    bra		init_loop
	    movlw	0x24
	    movwf	snd_c_y
	    movwf	snd_c_x
	    banksel	ADCON0
	    bsf		ADCON0,1	    ;ADC starten
	    banksel	LATC
	    bsf		LATC,0x02
	    movlb	0x00
	    bsf		bitleiste1,snd_lock
	    movlw	.50
	    movwf	timerrec1
	    clrf	timerrec2
loop:
;*****************************************************
;Main Routine Do-forever-loop,                       *
;*                                                   *
;****************************************************

main_l:	    
	    banksel	LATA
	    bsf		LATA,RA0
	    movlw	0x00     ; switch to bank 0
	    movwf	BSR
;*****************************************
;*  Start ADC                            *
;*****************************************
proc_adc:   
	    banksel	ADCON0			; 
	    movf	ADCON0,w
	    btfsc	ADCON0,ADGO		; ADC ready?
	    bra		no_adc			; no? then end
	    
	    btfss	bitleiste1,x_adc
	    bra		adc_y
adc_x:	    movlb	0x00
	    movlw	0x01			; Indexregister 1
	    movwf	FSR0H			;initialize
	    incf	res_x_cnt,w
	    andlw	0x03
	    movwf	res_x_cnt
	    movwf	FSR0L
	    movlw	result_x		; pointer 0 to result			
    	    addwf	FSR0L,f
	    banksel	ADRESH
	    movf	ADRESH,w
	    movwf	INDF0
	    banksel	ADCON0
	    movlw	B'00010101'		;Registercontent for Ad1
	    movwf	ADCON0
	    bcf		bitleiste1,x_adc
	    bsf		ADCON0,ADGO
	    goto	no_adc		; forward to read Register 
adc_y:	    movlb	0x00
	    movlw	0x01			; Indexregister 1
	    movwf	FSR0H			;initialize
	    incf	res_y_cnt,w
	    andlw	0x03
	    movwf	res_y_cnt
	    movwf	FSR0L
	    movlw	result_y		; pointer to result			
    	    addwf	FSR0L,f
	    banksel	ADRESH
	    movf	ADRESH,w
	    movwf	INDF0
	    banksel	ADCON0
	    movlw	B'00010001'		;Registercontent  Ad1
	    movwf	ADCON0
	    bsf		bitleiste1,x_adc
	    bsf		ADCON0,ADGO
	    goto	no_adc		; forward to read Register 
no_adc:	    movlb	0x00
	    movlw	0x01		; address result_X array 
	    movwf	FSR0H
	    movlw	result_x
	    movwf	FSR0L
	    movlw	0x4		; counter set to 4
	    movwf	c_reg
	    clrf	a_reg		;
	    clrf	b_reg		;delete temporary memory
x_loop:		moviw	INDF0++		; load value
		addwf	a_reg,f		; add
		btfsc	STATUS,C	;if carry
		incf	b_reg,f		;then increment 
		decfsz	c_reg,f		;count loop
	    bra		x_loop		;
	    bcf		STATUS,C
	    ;lsrf	b_reg,f
	    ;rrf		a_reg,f
	    lsrf	b_reg,f
	    rrf		a_reg,f
	    lsrf	b_reg,f
	    rrf		a_reg,w		;div /4
	    call	x_rate_val
	    movwf	a_reg
	    andlw	0x0F		; only rate
	    btfsc	STATUS,Z
	    bra		x_l_zero
	    btfsc	bitleiste2,key_act; test if key was pressed
	    addlw	0xFD		;yes, use slower rate
x_l_zero:   movwf	rate_x		;store rate
	    
	    btfsc	STATUS,Z
	    bra		x_no_cha
	    swapf	a_reg,w
	    andlw	0x0F
	    addlw	0x24
	    movwf	cmd_x		; store command
	    bra		y_start
x_no_cha:   movlw	0x24
	    iorwf	cmd_x,f
y_start:    movlw	0x4		;now Y ((index should be ok )
	    movwf	c_reg		;
	    clrf	a_reg		; like before
	    clrf	b_reg
y_loop:		moviw	INDF0++
		addwf	a_reg,f
		btfsc	STATUS,C
		incf	b_reg,f
		decfsz	c_reg,f
	    bra		y_loop
	    bcf		STATUS,C
	    lsrf	b_reg,f
	    rrf		a_reg,f
	    lsrf	b_reg,f
	    rrf		a_reg,w		;div 4
	    movwf	b_reg
	    call	y_rate_val
	    movwf	a_reg
	    andlw	0x0F
	    sublw	0x09
	    btfsc	STATUS,Z
	    nop
	    movfw	a_reg
	    andlw	0x0F
	    btfsc	STATUS,Z
	    bra		y_l_zero
	    btfsc	bitleiste2,key_act; test if key was pressed
	    addlw	0xFD		;yes, use slower rate
y_l_zero:   movwf	rate_y		;store rate
	    btfsc	STATUS,Z
	    bra		y_no_cha
	    swapf	a_reg,w
	    andlw	0x0F
	    addlw	0x24
	    movwf	cmd_y	      ; store command	    
	    bra		key_start
y_no_cha:   movlw	0x24
	    iorwf	cmd_y,f


key_start:   
	    banksel	PORTA
	    movf	PORTA,W
	    andlw	b'00100000' ;RA5
	    xorwf	key_ll		;test for edge
	    btfsc	STATUS,Z
	    goto	key_equal	;
	    movlb	0x00
	    movwf	key_ll
	    movlw	ll_cnt
	    movwf	key_cnt
	    goto	key_end
key_equal:  movf	key_cnt,f
	    btfsc	STATUS,Z
	    goto	key_end
	    decfsz	key_cnt,f
	    goto	key_end
	    movf	key_ll,f
	    btfss	STATUS,Z
	    goto	key_end
	    btfsc	bitleiste2,key_act
	    goto	key_deact
	    bsf		bitleiste2,key_act
	    goto	key_end
key_deact:  bcf		bitleiste2,key_act
key_end:
	    
comm_start:
    
	    banksel	TRISC
	    bcf		TRISC,4
	    movlb	0x00
	    btfsc	bitleiste1,snd_lock ; sending process busy?
	    goto	end_send
	    btfsc	bitleiste1,rec_ping ;already ack fo ping received?
	    goto	tst_snd_x
	    bsf		bitleiste1,snd_lock
	    movlw	0x0D		    ;start Ping 
	    movwf	stseriell
	    movlw	0x3b
	    banksel	TXREG
	    movwf	TXREG
	    banksel	PIE1
	    bsf		PIE1,TXIE
	    movlb	0x00
	    movlw	timeout
	    movwf	timerrec1
	    bra		end_send
tst_snd_x:  btfsc	bitleiste1,rec_quit
	    goto	end_send
	    btfsc	bitleiste1,rec_echo
	    goto	end_send
	    movf	cmd_x,w		
	    subwf	snd_c_x,w
	    btfss	STATUS,Z
	    bra		snd_cmd_x
	    movf	rate_x,w
	    subwf	snd_r_x,w
	    btfsc	STATUS,Z
	    bra		tst_snd_y
snd_cmd_x:  bsf		bitleiste1,snd_lock
	    movlw	0x01
	    movwf	stseriell
	    movf	rate_x,w
	    movwf	snd_r_x
	    movf	cmd_x,w
	    movwf	snd_c_x
	    movlw	x_dir
	    movwf	snd_target
	    movlw	0x3B
	    banksel	TXREG
	    movwf	TXREG
	    banksel	PIE1
	    bsf		PIE1,TXIE
	    movlb	0x00
	    movlw	timer_val
	    movwf	timerrec2
	    bsf		bitleiste1,rec_echo
	    bsf		bitleiste1,rec_quit
	    bra		end_send
tst_snd_y:  movlb	0x00
	    movf	cmd_y,w		
	    subwf	snd_c_y,w
	    btfss	STATUS,Z
	    bra		snd_cmd_y
	    movf	rate_y,w
	    subwf	snd_r_y,w
	    btfsc	STATUS,Z
	    bra		end_send
snd_cmd_y:  bsf		bitleiste1,snd_lock
	    movlw	0x02
	    movwf	stseriell
	    movf	rate_y,w
	    movwf	snd_r_y
	    movf	cmd_y,w
	    movwf	snd_c_y
	    movlw	y_dir
	    movwf	snd_target
	    movlw	0x3b
	    banksel	TXREG
	    movwf	TXREG
	    banksel	PIE1
	    bsf		PIE1,TXIE
	    movlb	0x00
	    movlw	timer_val
	    movwf	timerrec2
	    bsf		bitleiste1,rec_echo
	    bsf		bitleiste1,rec_quit
	    bra		end_send
end_send:  
	    
rec_start:  clrf	FSR0H
	    btfss	bitleiste1,buf_1
	    goto	rec_sta2
	    movlw	rec_buf1
	    movwf	FSR0L
	    movlw	0x7F
	    movwf	rec_mask
	    bra		rec_pars
rec_sta2:   btfss	bitleiste1,buf_2
	    goto	rec_term
	    movlw	rec_buf2
	    movwf	FSR0L
	    movlw	0xBF
	    movwf	rec_mask
rec_pars:   btfsc	bitleiste1,rec_ping	; already Ping ack received?
	    bra		r_p_echo
	    movlw	HIGH ping_response
	    movwf	FSR1H
	    movlw	LOW ping_response
	    movwf	FSR1L
	    movlw	0x05
	    movwf	c_reg
	    call	rec_comp
	    btfss	STATUS,Z
	    goto	rec_exit
	    clrf	timerrec1
	    bsf		bitleiste1,rec_ping
	    bcf		bitleiste1,snd_lock
	    goto	rec_exit
r_p_echo:   moviw	++INDF0
	    sublw	0x04
	    btfss	STATUS,Z
	    bra		r_p_quit
	    moviw	++INDF0
	    sublw	0x20
	    btfss	STATUS,Z
	    bra		r_p_quit
	    moviw	++INDF0
	    subwf	snd_target
	    btfss	STATUS,Z
	    bra		r_p_quit
	    movf	snd_c_x,w	    
	    btfsc	snd_target,0	    ; Target y?
	    movf	snd_c_y,w	    ;load with y value
	    movwf	a_reg
	    moviw	++INDF0
	    subwf	a_reg
	    btfss	STATUS,Z
	    bra		r_p_quit
	    bcf		bitleiste1,rec_echo
	    bcf		bitleiste1,snd_lock
	    bra		rec_exit
r_p_quit:   moviw	++INDF0
	    sublw	0x03
	    btfss	STATUS,Z
	    bra		rec_exit
	    moviw	++INDF0
	    subwf	snd_target
	    btfss	STATUS,Z
	    bra		rec_exit
	    moviw	++INDF0
	    sublw	0x20
	    btfss	STATUS,Z
	    bra		rec_exit
	    movf	snd_c_x,w	    
	    btfsc	snd_target,0	    ; Target y?
	    movf	snd_c_y,w	    ;load with y value
	    movwf	a_reg
	    moviw	++INDF0
	    subwf	a_reg
	    btfss	STATUS,Z
	    bra		rec_exit
	    bcf		bitleiste1,rec_quit
	    clrf	timerrec2
rec_exit:   movf	rec_mask,w
	    andwf	bitleiste1,F
	    movf	bitleiste1,w
	    andlw	0xC0
	    btfss	STATUS,Z
	    bra		rec_start
rec_term:    
	    banksel	ADRESH
	    movf	ADRESH,w
	    goto	loop

	    
	    
rec_comp:   moviw	INDF0++
	    movwf	a_reg
	    moviw	INDF1++
	    subwf	a_reg,w
	    btfss	STATUS,Z
	    retlw	0x01
	    decfsz	c_reg,f
	    bra		rec_comp
	    retlw	0x00
x_rate_val:	brw
		retlw		down_fast		;0x00
		retlw		down_fast		;0x01
		retlw		down_fast		;0x02
		retlw		down_fast		;0x03
		retlw		down_fast		;0x04
		retlw		down_fast		;0x05
		retlw		down_fast		;0x06
		retlw		down_fast		;0x07
		retlw		down_fast		;0x08
		retlw		down_fast		;0x09
		retlw		down_fast		;0x0A
		retlw		down_fast		;0x0B
		retlw		down_fast		;0x0C
		retlw		down_fast		;0x0D
		retlw		down_fast		;0x0E
		retlw		down_fast		;0x0F
		retlw		down_fast		;0x10
		retlw		down_fast		;0x11
		retlw		down_fast		;0x12
		retlw		down_fast		;0x13
		retlw		down_fast		;0x14
		retlw		down_fast		;0x15
		retlw		down_fast		;0x16
		retlw		down_fast		;0x17
		retlw		down_fast		;0x18
		retlw		down_medium		;0x19
		retlw		down_medium		;0x1A
		retlw		down_medium		;0x1B
		retlw		down_medium		;0x1C
		retlw		down_medium		;0x1D
		retlw		down_medium		;0x1E
		retlw		down_medium		;0x1F
		retlw		down_medium		;0x20
		retlw		down_medium		;0x21
		retlw		down_medium		;0x22
		retlw		down_medium		;0x23
		retlw		down_medium		;0x24
		retlw		down_medium		;0x25
		retlw		down_medium		;0x26
		retlw		down_medium		;0x27
		retlw		down_medium		;0x28
		retlw		down_medium		;0x29
		retlw		down_medium		;0x2A
		retlw		down_medium		;0x2B
		retlw		down_medium		;0x2C
		retlw		down_medium		;0x2D
		retlw		down_medium		;0x2E
		retlw		down_medium		;0x2F
		retlw		down_medium		;0x30
		retlw		down_medium		;0x31
		retlw		down_medium		;0x32
		retlw		down_medium		;0x33
		retlw		down_medium		;0x34
		retlw		down_medium		;0x35
		retlw		down_medium		;0x36
		retlw		down_medium		;0x37
		retlw		down_medium		;0x38
		retlw		down_medium		;0x39
		retlw		down_medium		;0x3A
		retlw		down_medium		;0x3B
		retlw		down_medium		;0x3C
		retlw		down_medium		;0x3D
		retlw		down_medium		;0x3E
		retlw		down_medium		;0x3F
		retlw		down_slow		;0x40
		retlw		down_slow		;0x41
		retlw		down_slow		;0x42
		retlw		down_slow		;0x43
		retlw		down_slow		;0x44
		retlw		down_slow		;0x45
		retlw		down_slow		;0x46
		retlw		down_slow		;0x47
		retlw		down_slow		;0x48
		retlw		down_slow		;0x49
		retlw		down_slow		;0x4A
		retlw		down_slow		;0x4B
		retlw		down_slow		;0x4C
		retlw		down_slow		;0x4D
		retlw		down_slow		;0x4E
		retlw		down_slow		;0x4F
		retlw		down_slow		;0x50
		retlw		down_slow		;0x51
		retlw		down_slow		;0x52
		retlw		down_slow		;0x53
		retlw		down_slow		;0x54
		retlw		down_slow		;0x55
		retlw		down_slow		;0x56
		retlw		down_slow		;0x57
		retlw		down_slow		;0x58
		retlw		down_slow		;0x59
		retlw		down_slow		;0x5A
		retlw		down_slow		;0x5B
		retlw		down_slow		;0x5C
		retlw		down_slow		;0x5D
		retlw		down_slow		;0x5E
		retlw		down_slow		;0x5F
		retlw		down_slow		;0x60
		retlw		down_slow		;0x61
		retlw		down_slow		;0x62
		retlw		down_slow		;0x63
		retlw		down_slow		;0x64
		retlw		down_slow		;0x65
		retlw		down_slow		;0x66
		retlw		down_slow		;0x67
		retlw		down_slow		;0x68
		retlw		down_slow		;0x69
		retlw		down_slow		;0x6A
		retlw		down_slow		;0x6B
		retlw		down_slow		;0x6C
		retlw		down_slow		;0x6D
		retlw		down_slow		;0x6E
		retlw		down_slow		;0x6F
		retlw		down_slow		;0x70
		retlw		down_slow		;0x71
		retlw		down_slow		;0x72
		retlw		down_slow		;0x73
		retlw		down_slow		;0x74
		retlw		down_slow		;0x75
		retlw		down_slow		;0x76
		retlw		down_slow		;0x77
		retlw		down_slow		;0x78
		retlw		down_stop		;0x79
		retlw		down_stop		;0x7A
		retlw		down_stop		;0x7B
		retlw		down_stop		;0x7C
		retlw		down_stop		;0x7D
		retlw		down_stop		;0x7E
		retlw		down_stop		;0x7F
		retlw		down_stop		;0x80
		retlw		down_stop		;0x81
		retlw		down_stop		;0x82
		retlw		down_stop		;0x83
		retlw		down_stop		;0x84
		retlw		down_stop		;0x85
		retlw		down_stop		;0x86
		retlw		down_stop		;0x87
		retlw		up_slow		;0x88
		retlw		up_slow		;0x89
		retlw		up_slow		;0x8A
		retlw		up_slow		;0x8B
		retlw		up_slow		;0x8C
		retlw		up_slow		;0x8D
		retlw		up_slow		;0x8E
		retlw		up_slow		;0x8F
		retlw		up_slow		;0x90
		retlw		up_slow		;0x91
		retlw		up_slow		;0x92
		retlw		up_slow		;0x93
		retlw		up_slow		;0x94
		retlw		up_slow		;0x95
		retlw		up_slow		;0x96
		retlw		up_slow		;0x97
		retlw		up_slow		;0x98
		retlw		up_slow		;0x99
		retlw		up_slow		;0x9A
		retlw		up_slow		;0x9B
		retlw		up_slow		;0x9C
		retlw		up_slow		;0x9D
		retlw		up_slow		;0x9E
		retlw		up_slow		;0x9F
		retlw		up_slow		;0xA0
		retlw		up_slow		;0xA1
		retlw		up_slow		;0xA2
		retlw		up_slow		;0xA3
		retlw		up_slow		;0xA4
		retlw		up_slow		;0xA5
		retlw		up_slow		;0xA6
		retlw		up_slow		;0xA7
		retlw		up_slow		;0xA8
		retlw		up_slow		;0xA9
		retlw		up_slow		;0xAA
		retlw		up_slow		;0xAB
		retlw		up_slow		;0xAC
		retlw		up_slow		;0xAD
		retlw		up_slow		;0xAE
		retlw		up_slow		;0xAF
		retlw		up_slow		;0xB0
		retlw		up_slow		;0xB1
		retlw		up_slow		;0xB2
		retlw		up_slow		;0xB3
		retlw		up_slow		;0xB4
		retlw		up_slow		;0xB5
		retlw		up_slow		;0xB6
		retlw		up_slow		;0xB7
		retlw		up_slow		;0xB8
		retlw		up_slow		;0xB9
		retlw		up_slow		;0xBA
		retlw		up_slow		;0xBB
		retlw		up_slow		;0xBC
		retlw		up_slow		;0xBD
		retlw		up_slow		;0xBE
		retlw		up_slow		;0xBF
		retlw		up_medium		;0xC0
		retlw		up_medium		;0xC1
		retlw		up_medium		;0xC2
		retlw		up_medium		;0xC3
		retlw		up_medium		;0xC4
		retlw		up_medium		;0xC5
		retlw		up_medium		;0xC6
		retlw		up_medium		;0xC7
		retlw		up_medium		;0xC8
		retlw		up_medium		;0xC9
		retlw		up_medium		;0xCA
		retlw		up_medium		;0xCB
		retlw		up_medium		;0xCC
		retlw		up_medium		;0xCD
		retlw		up_medium		;0xCE
		retlw		up_medium		;0xCF
		retlw		up_medium		;0xD0
		retlw		up_medium		;0xD1
		retlw		up_medium		;0xD2
		retlw		up_medium		;0xD3
		retlw		up_medium		;0xD4
		retlw		up_medium		;0xD5
		retlw		up_medium		;0xD6
		retlw		up_medium		;0xD7
		retlw		up_medium		;0xD8
		retlw		up_medium		;0xD9
		retlw		up_medium		;0xDA
		retlw		up_medium		;0xDB
		retlw		up_medium		;0xDC
		retlw		up_medium		;0xDD
		retlw		up_medium		;0xDE
		retlw		up_medium		;0xDF
		retlw		up_fast		;0xE0
		retlw		up_fast		;0xE1
		retlw		up_fast		;0xE2
		retlw		up_fast		;0xE3
		retlw		up_fast		;0xE4
		retlw		up_fast		;0xE5
		retlw		up_fast		;0xE6
		retlw		up_fast		;0xE7
		retlw		up_fast		;0xE8
		retlw		up_fast		;0xE9
		retlw		up_fast		;0xEA
		retlw		up_fast		;0xEB
		retlw		up_fast		;0xEC
		retlw		up_fast		;0xED
		retlw		up_fast		;0xEE
		retlw		up_fast		;0xEF
		retlw		up_fast		;0xF0
		retlw		up_fast		;0xF1
		retlw		up_fast		;0xF2
		retlw		up_fast		;0xF3
		retlw		up_fast		;0xF4
		retlw		up_fast		;0xF5
		retlw		up_fast		;0xF6
		retlw		up_fast		;0xF7
		retlw		up_fast		;0xF8
		retlw		up_fast		;0xF9
		retlw		up_fast		;0xFA
		retlw		up_fast		;0xFB
		retlw		up_fast		;0xFC
		retlw		up_fast		;0xFD
		retlw		up_fast		;0xFE
		retlw		up_fast		;0xFF
y_rate_val:	brw
		retlw		right_fast		;0x00
		retlw		right_fast		;0x01
		retlw		right_fast		;0x02
		retlw		right_fast		;0x03
		retlw		right_fast		;0x04
		retlw		right_fast		;0x05
		retlw		right_fast		;0x06
		retlw		right_fast		;0x07
		retlw		right_fast		;0x08
		retlw		right_fast		;0x09
		retlw		right_fast		;0x0A
		retlw		right_fast		;0x0B
		retlw		right_fast		;0x0C
		retlw		right_fast		;0x0D
		retlw		right_fast		;0x0E
		retlw		right_fast		;0x0F
		retlw		right_fast		;0x10
		retlw		right_fast		;0x11
		retlw		right_fast		;0x12
		retlw		right_fast		;0x13
		retlw		right_fast		;0x14
		retlw		right_fast		;0x15
		retlw		right_fast		;0x16
		retlw		right_fast		;0x17
		retlw		right_fast		;0x18
		retlw		right_medium		;0x19
		retlw		right_medium		;0x1A
		retlw		right_medium		;0x1B
		retlw		right_medium		;0x1C
		retlw		right_medium		;0x1D
		retlw		right_medium		;0x1E
		retlw		right_medium		;0x1F
		retlw		right_medium		;0x20
		retlw		right_medium		;0x21
		retlw		right_medium		;0x22
		retlw		right_medium		;0x23
		retlw		right_medium		;0x24
		retlw		right_medium		;0x25
		retlw		right_medium		;0x26
		retlw		right_medium		;0x27
		retlw		right_medium		;0x28
		retlw		right_medium		;0x29
		retlw		right_medium		;0x2A
		retlw		right_medium		;0x2B
		retlw		right_medium		;0x2C
		retlw		right_medium		;0x2D
		retlw		right_medium		;0x2E
		retlw		right_medium		;0x2F
		retlw		right_medium		;0x30
		retlw		right_medium		;0x31
		retlw		right_medium		;0x32
		retlw		right_medium		;0x33
		retlw		right_medium		;0x34
		retlw		right_medium		;0x35
		retlw		right_medium		;0x36
		retlw		right_medium		;0x37
		retlw		right_medium		;0x38
		retlw		right_medium		;0x39
		retlw		right_medium		;0x3A
		retlw		right_medium		;0x3B
		retlw		right_medium		;0x3C
		retlw		right_medium		;0x3D
		retlw		right_medium		;0x3E
		retlw		right_medium		;0x3F
		retlw		right_slow		;0x40
		retlw		right_slow		;0x41
		retlw		right_slow		;0x42
		retlw		right_slow		;0x43
		retlw		right_slow		;0x44
		retlw		right_slow		;0x45
		retlw		right_slow		;0x46
		retlw		right_slow		;0x47
		retlw		right_slow		;0x48
		retlw		right_slow		;0x49
		retlw		right_slow		;0x4A
		retlw		right_slow		;0x4B
		retlw		right_slow		;0x4C
		retlw		right_slow		;0x4D
		retlw		right_slow		;0x4E
		retlw		right_slow		;0x4F
		retlw		right_slow		;0x50
		retlw		right_slow		;0x51
		retlw		right_slow		;0x52
		retlw		right_slow		;0x53
		retlw		right_slow		;0x54
		retlw		right_slow		;0x55
		retlw		right_slow		;0x56
		retlw		right_slow		;0x57
		retlw		right_slow		;0x58
		retlw		right_slow		;0x59
		retlw		right_slow		;0x5A
		retlw		right_slow		;0x5B
		retlw		right_slow		;0x5C
		retlw		right_slow		;0x5D
		retlw		right_slow		;0x5E
		retlw		right_slow		;0x5F
		retlw		right_slow		;0x60
		retlw		right_slow		;0x61
		retlw		right_slow		;0x62
		retlw		right_slow		;0x63
		retlw		right_slow		;0x64
		retlw		right_slow		;0x65
		retlw		right_slow		;0x66
		retlw		right_slow		;0x67
		retlw		right_slow		;0x68
		retlw		right_slow		;0x69
		retlw		right_slow		;0x6A
		retlw		right_slow		;0x6B
		retlw		right_slow		;0x6C
		retlw		right_slow		;0x6D
		retlw		right_slow		;0x6E
		retlw		right_slow		;0x6F
		retlw		right_slow		;0x70
		retlw		right_slow		;0x71
		retlw		right_slow		;0x72
		retlw		right_slow		;0x73
		retlw		right_slow		;0x74
		retlw		right_slow		;0x75
		retlw		right_slow		;0x76
		retlw		right_slow		;0x77
		retlw		right_slow		;0x78
		retlw		right_stop		;0x79
		retlw		right_stop		;0x7A
		retlw		right_stop		;0x7B
		retlw		right_stop		;0x7C
		retlw		right_stop		;0x7D
		retlw		right_stop		;0x7E
		retlw		right_stop		;0x7F
		retlw		right_stop		;0x80
		retlw		right_stop		;0x81
		retlw		right_stop		;0x82
		retlw		right_stop		;0x83
		retlw		right_stop		;0x84
		retlw		left_slow		;0x85
		retlw		left_slow		;0x86
		retlw		left_slow		;0x87
		retlw		left_slow		;0x88
		retlw		left_slow		;0x89
		retlw		left_slow		;0x8A
		retlw		left_slow		;0x8B
		retlw		left_slow		;0x8C
		retlw		left_slow		;0x8D
		retlw		left_slow		;0x8E
		retlw		left_slow		;0x8F
		retlw		left_slow		;0x90
		retlw		left_slow		;0x91
		retlw		left_slow		;0x92
		retlw		left_slow		;0x93
		retlw		left_slow		;0x94
		retlw		left_slow		;0x95
		retlw		left_slow		;0x96
		retlw		left_slow		;0x97
		retlw		left_slow		;0x98
		retlw		left_slow		;0x99
		retlw		left_slow		;0x9A
		retlw		left_slow		;0x9B
		retlw		left_slow		;0x9C
		retlw		left_slow		;0x9D
		retlw		left_slow		;0x9E
		retlw		left_slow		;0x9F
		retlw		left_slow		;0xA0
		retlw		left_slow		;0xA1
		retlw		left_slow		;0xA2
		retlw		left_slow		;0xA3
		retlw		left_slow		;0xA4
		retlw		left_slow		;0xA5
		retlw		left_slow		;0xA6
		retlw		left_slow		;0xA7
		retlw		left_slow		;0xA8
		retlw		left_slow		;0xA9
		retlw		left_slow		;0xAA
		retlw		left_slow		;0xAB
		retlw		left_slow		;0xAC
		retlw		left_slow		;0xAD
		retlw		left_slow		;0xAE
		retlw		left_slow		;0xAF
		retlw		left_slow		;0xB0
		retlw		left_slow		;0xB1
		retlw		left_slow		;0xB2
		retlw		left_slow		;0xB3
		retlw		left_slow		;0xB4
		retlw		left_slow		;0xB5
		retlw		left_slow		;0xB6
		retlw		left_slow		;0xB7
		retlw		left_medium		;0xB8
		retlw		left_medium		;0xB9
		retlw		left_medium		;0xBA
		retlw		left_medium		;0xBB
		retlw		left_medium		;0xBC
		retlw		left_medium		;0xBD
		retlw		left_medium		;0xBE
		retlw		left_medium		;0xBF
		retlw		left_medium		;0xC0
		retlw		left_medium		;0xC1
		retlw		left_medium		;0xC2
		retlw		left_medium		;0xC3
		retlw		left_medium		;0xC4
		retlw		left_medium		;0xC5
		retlw		left_medium		;0xC6
		retlw		left_medium		;0xC7
		retlw		left_medium		;0xC8
		retlw		left_medium		;0xC9
		retlw		left_medium		;0xCA
		retlw		left_medium		;0xCB
		retlw		left_medium		;0xCC
		retlw		left_medium		;0xCD
		retlw		left_medium		;0xCE
		retlw		left_medium		;0xCF
		retlw		left_medium		;0xD0
		retlw		left_medium		;0xD1
		retlw		left_medium		;0xD2
		retlw		left_medium		;0xD3
		retlw		left_medium		;0xD4
		retlw		left_medium		;0xD5
		retlw		left_medium		;0xD6
		retlw		left_medium		;0xD7
		retlw		left_medium		;0xD8
		retlw		left_medium		;0xD9
		retlw		left_medium		;0xDA
		retlw		left_medium		;0xDB
		retlw		left_medium		;0xDC
		retlw		left_medium		;0xDD
		retlw		left_medium		;0xDE
		retlw		left_medium		;0xDF
		retlw		left_fast		;0xE0
		retlw		left_fast		;0xE1
		retlw		left_fast		;0xE2
		retlw		left_fast		;0xE3
		retlw		left_fast		;0xE4
		retlw		left_fast		;0xE5
		retlw		left_fast		;0xE6
		retlw		left_fast		;0xE7
		retlw		left_fast		;0xE8
		retlw		left_fast		;0xE9
		retlw		left_fast		;0xEA
		retlw		left_fast		;0xEB
		retlw		left_fast		;0xEC
		retlw		left_fast		;0xED
		retlw		left_fast		;0xEE
		retlw		left_fast		;0xEF
		retlw		left_fast		;0xF0
		retlw		left_fast		;0xF1
		retlw		left_fast		;0xF2
		retlw		left_fast		;0xF3
		retlw		left_fast		;0xF4
		retlw		left_fast		;0xF5
		retlw		left_fast		;0xF6
		retlw		left_fast		;0xF7
		retlw		left_fast		;0xF8
		retlw		left_fast		;0xF9
		retlw		left_fast		;0xFA
		retlw		left_fast		;0xFB
		retlw		left_fast		;0xFC
		retlw		left_fast		;0xFD
		retlw		left_fast		;0xFE
		retlw		left_fast		;0xFF

ping_response dw 0x3B,0x06,0x10,0x20,0x01,0x00,0x00,0x00,0xC9 
 end




