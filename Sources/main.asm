;*****************************************************************
;* COE538 Project Robot Guidance Problem                         *
;* 501031027                                                     *
;* Timmy Ngo                                                     *
;*                                                               *
;* Used MC9S12C32                                                *
;*****************************************************************

; export symbols
              XDEF Entry, _Startup          ; export 'Entry' symbol
              ABSENTRY Entry                ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		      INCLUDE 'derivative.inc' 

; Equates section

LCD_DAT       EQU   PORTB                   ; LCD data port, bits - PB7,...,PB0
LCD_CNTR      EQU   PTJ                     ; LCD control port, bits - PJ7(E),PJ6(RS)
LCD_E         EQU   $80                     ; LCD E-signal pin
LCD_RS        EQU   $40                     ; LCD RS-signal pin

FWD_INT       EQU   69                      ; 3 second delay (at 23Hz)
REV_INT       EQU   69                      ; 3 second delay (at 23Hz)
FWD_TRN_INT   EQU   46                      ; 2 second delay (at 23Hz)
REV_TRN_INT   EQU   46                      ; 2 second delay (at 23Hz)
START         EQU   0                       ; Start state                   
FWD           EQU   1                       ; Forward state
REV           EQU   2                       ; Reverse state
ALL_STP       EQU   3
FWD_TRN       EQU   4
REV_TRN       EQU   5

; Equates for Guider

  ; Sensors
SENSOR_A      EQU
SENSOR_B      EQU
SENSOR_C      EQU
SENSOR_D      EQU
SENSOR_E      EQU
SENSOR_F      EQU

  ; LCD Addresses
CLEAR_HOME    EQU   $01                     ; Clear the display and home the cursor
INTERFACE     EQU   $38                     ; 8 bit interface, two line display
CURSOR_OFF    EQU   $0C                     ; Display on, cursor off
SHIRT_OFF     EQU   $06                     ; Address increments, no character shift
LCD_SEC_LINE  EQU   $64                     ; Starting addr. of 2nd line of LCD (note decimal value!)

  ; Other codes
NULL          EQU   00                      ; The string 'null terminator'
CR            EQU   $0D                     ; 'Carriage Return' character
SPACE         EQU   ' '                     ; The 'space' character



; variable section

              ORG   $3000                   ; TOF counter register is here

TOF_COUNTER   DC.B  0                       ; The timer, incremented at 23Hz
CRNT_STATE    DC.B  3                       ; Current state register
T_FWD         DS.B  1                       ; FWD time
T_REV         DS.B  1                       ; REV time
T_FWD_TRN     DS.B  1                       ; FWD_TURN time
T_REV_TRN     DS.B  1                       ; REV_TURN tine
TEN_THOUS     DS.B  1                       ; 10,000 digit
THOUSANDS     DS.B  1                       ; 1,000 digit
HUNDREDS      DS.B  1                       ; 100 digit
TENS          DS.B  1                       ; 10 digit
UNITS         DS.B  1                       ; 1 digit
NO_BLANK      DS.B  1                       ; Used in 'leading zero' blanking by BCD2ASC
BCD_SPARE     DS.B  10

  ; from Guider PDF
SENSOR_LINE   FCB   $01                     ; Storage for guider sensor readings
SENSOR_BOW    FCB   $23                     ; Initialized to test values
SENSOR_PORT   FCB   $45                     ;
SENSOR_MID    FCB   $67                     ;
SENSOR_STBD   FCB   $89                     ;
SENSOR_NUM    RMB   1                       ; The currently selected sensor

TOP_LINE      RMB   20                       ; Top line of display
              FCB   NULL                    ;  terminated by NULL

BOT_LINE      RMB   20                       ; Bottom line of display
              FCB   NULL                    ;  terminated by NULL
              
CLEAR_LINE    FCC   ' '
              FCB   NULL                    ;  terminated by NULL
              
TEMP          RMB   1                       ; Temporary location


; code section
              ORG   $4000                   ; Code is here -----------------------------
Entry:                                      ;                                           |
_Startup:     
              CLI                              ;                                           |
              LDS   #$4000                  ; Initialize the stack pointer
                                            ;                                           I

                                            ;                                           T
              JSR   initAD                  ; Initialize ATD converter                  I
                                            ;                                           A
              JSR   initLCD                 ; Initialize the LCD                        L
              JSR   clrLCD                  ; Clear LCD & home cursor                   I
              
              JSR   initTCNT                ; Initialize the TCNT
                                            ;                                           Z
              LDX   #msg1                   ; Display msg1                              A
              JSR   putsLCD                 ; "                                         T    
              LDAA  #$8A                    ; Move LCD cursor to the end of msg1
              JSR   cmd2LCD                        ;                                           I      
              
              LDX   #msg2                   ; Display msg2                              A
              JSR   putsLCD                 ; "                                         T            
              LDAA  #$C0                    ; Move LCD cursor to the 2nd row
              JSR   cmd2LCD
              
              LDX   #msg3                   ; Display msg3                              A
              JSR   putsLCD                 ; "                                         T       
                                                 ;                                           |
              JSR   ENABLE_TOF              ; Jump to TOF initialization ---------------
                                          
MAIN          JSR   UPDT_DISPL              ; M
              LDAA  CRNT_STATE              ; A
              JSR   READ_SENSORS
              JSR   DISPATCHER              ; I
              BRA   MAIN                    ; N
            
; data section

msg1          DC.B  "BV ",0                 ; Battery voltage message
msg2          DC.B  "S ",0                  ; Current state message
msg3          DC.B  "SR ",0                 ; Sensor reading message

tab           DC.B  "START  ",0
              DC.B  "FWD    ",0
              DC.B  "REV    ",0
              DC.B  "ALL_STP",0
              DC.B  "FWD_TRN",0
              DC.B  "REV_TRN",0

; subroutine section

; *****************State Dispatcher

; This routine calls the appropriate state handler based on the current state.

; Input:      Current state in ACCA
; Returns:    None
; Clobbers:   Everything

DISPATCHER    CMPA  START                  ; If it's the START state
              BNE   NOT_START               ;                                           
              JSR   START_ST                ;  then call START_ST routine              
              BRA   DISP_EXIT               ;  and exit                                 
                                            ;                                           
NOT_START     CMPA  #FWD                    ; Else if it's the FORWARD state                                         
              BNE   NOT_FWD                 ;  
              JSR   FWD_ST                  ;  then call the FORWARD state
              JMP   DISP_EXIT               ;  and exit
              
NOT_FWD       CMPA  #REV                ; Else if it�s the REVERSE state
              BNE   NOT_REV
              JSR   REV_ST                  ;  then call the REVERSE routine
              JMP   DISP_EXIT               ;  and exit
              
NOT_REV       CMPA  #ALL_STP                ; Else if it�s the ALL_STOP state
              BNE   NOT_ALL_STP
              JSR   ALL_STP_ST              ;  then call the ALL_STOP routine
              JMP   DISP_EXIT               ;  and exit
              
NOT_ALL_STP   CMPA  #FWD_TRN            ; Else if it�s the FORWARD_TURN state
              BNE   NOT_FWD_TRN
              JSR   FWD_TRN_ST              ;  then call the FORWARD_TURN routine
              JMP   DISP_EXIT               ;  and exit
                                        
                                            ;                                           
NOT_FWD_TRN   CMPA  #REV_TRN                ; Else if it�s the REV_TRN state            
              BNE   NOT_REV_TRN             ;                                           
              JSR   REV_TRN_ST              ;  then call REV_TRN_ST routine             
              BRA   DISP_EXIT               ;  and exit                                 
                                            ;                                           
NOT_REV_TRN   SWI                           ; Else the CRNT_ST is not defined, so stop  

                                            ; Else if it's the right turn state
                                            ;
                                            ;   then call the right turn routine
                                            ;   and exit
                                            
                                            ; Else if it's the left turn state
                                            ;
                                            ;   then call the left turn routine
                                            ;   and exit
                                                                                       
DISP_EXIT     RTS                           ; Exit from the state dispatcher

; *****************START_ST subroutine

;             START STATE HANDLER

; Advances state to the FORWARD state if /FWD-BUMP

; Passed:     Current state in ACCA
; Returns:    New state in ACCA
; Clobbers:   None

START_ST      BRCLR PORTAD0,$04,NO_FWD      ; If /FWD-BUMP
              JSR   INIT_FWD                ; Initialize the FORWARD state
              MOVB  #FWD,CRNT_STATE         ; Go into the FORWARD state
              BRA   START_EXIT
            
NO_FWD        NOP                           ; Else
START_EXIT    RTS                           ;  return to the MAIN routine

; *****************FWD_ST subroutine 
                       
FWD_ST        BRSET PORTAD0,$04,NO_FWD_BUMP     ; If FWD_BUMP then
              JSR   INIT_REV                    ;  initialize the REVERSE routine
              MOVB  #REV,CRNT_STATE             ;  set the state to REVERSE
              JMP   FWD_EXIT                    ;  and return
              
NO_FWD_BUMP   BRSET PORTAD0,$08,NO_REAR_BUMP    ; If REAR_BUMP, then we should stop
              JSR   INIT_ALL_STP                ;  so initialize the ALL_STOP state
              MOVB  #ALL_STP,CRNT_STATE         ;  and change state to ALL_STOP
              JMP   FWD_EXIT                    ;  and return
              
NO_REAR_BUMP  LDAA  TOF_COUNTER                 ; If Tc>Tfwd then
              CMPA  T_FWD                       ;  the robot should make a turn
              BNE   NO_FWD_TRN                  ;  so
              JSR   INIT_FWD_TRN                ;  initialize the FORWARD_TURN state
              MOVB  #FWD_TRN,CRNT_STATE         ;  and go to that state
              JMP   FWD_EXIT
                          
NO_FWD_TRN    NOP                               ; Else
FWD_EXIT      RTS                               ;  return to the MAIN routine   

; *****************REV_ST subroutine

REV_ST        LDAA  TOF_COUNTER             ; If Tc>Trev then
              CMPA  T_REV                   ;  the robot should make a FWD turn
              BNE   NO_REV_TRN              ;  so
              JSR   INIT_REV_TRN            ;  initialize the REV_TRN state
              MOVB  #REV_TRN,CRNT_STATE     ;  set state to REV_TRN
              BRA   REV_EXIT                ;  and return
            
NO_REV_TRN    NOP                           ; Else
REV_EXIT      RTS                           ;  return to the MAIN routine

; *****************ALL_STP_ST subroutine

ALL_STP_ST    BRSET PORTAD0,$04,NO_START    ; If FWD_BUMP
              BCLR  PTT,%00110000           ;  initialize the START state (both motors off)
              MOVB  #START,CRNT_STATE       ;  set the state to START
              BRA   ALL_STP_EXIT            ;  and return
            
NO_START      NOP                           ; Else
ALL_STP_EXIT  RTS                           ;  return to the MAIN routine

; *****************FWD_TRN_ST subroutine

FWD_TRN_ST    LDAA  TOF_COUNTER             ; If Tc>Tfwdturn then
              CMPA  T_FWD_TRN               ;  the robot should go FWD
              BNE   NO_FWD_FT               ;  so
              JSR   INIT_FWD                ;  initialize the FWD state
              MOVB  #FWD,CRNT_STATE         ;  set state to FWD
              BRA   FWD_TRN_EXIT            ;  and return
              
NO_FWD_FT     NOP                           ; Else
FWD_TRN_EXIT  RTS                           ;  return to the MAIN routine

; *****************REV_TRN_ST subroutine
      
REV_TRN_ST    LDAA  TOF_COUNTER             ; If Tc>Trevturn then
              CMPA  T_REV_TRN               ;  the robot should go FWD
              BNE   NO_FWD_RT               ;  so
              JSR   INIT_FWD                ;  initialize the FWD state
              MOVB  #FWD,CRNT_STATE         ;  set state to FWD
              BRA   REV_TRN_EXIT            ;  and return
              
NO_FWD_RT     NOP                           ; Else
REV_TRN_EXIT  RTS                           ;  return to the MAIN routine 

; *****************INIT_FWD subroutine
;       Initialize FORWARD state

; This routine is called whenever the FORWARD routine is entered.
; It turns both the motors ON
; It initializes the alarm used in by the FORWARD state.   

INIT_FWD      BCLR  PORTA,%00000011         ; Set FWD direction for both motors
              BSET  PTT,%00110000           ; Turn on the drive motors
              LDAA  TOF_COUNTER             ; Mark the fwd time Tfwd
              ADDA  #FWD_INT
              STAA  T_FWD
              RTS       
              
; *****************INIT_REV subroutine 

INIT_REV      BSET  PORTA,%00000011         ; Set REV direction for both motors
              BSET  PTT,%00110000           ; Turn on the drive motors
              LDAA  TOF_COUNTER             ; Mark the fwd time Tfwd
              ADDA  #REV_INT
              STAA  T_REV
              RTS
              
; *****************INIT_ALL_STP subroutine

INIT_ALL_STP  BCLR  PTT,%00110000           ; Turn off the drive motors
              RTS  
              
; *****************INIT_FWD_TRN subroutine

INIT_FWD_TRN  BSET  PORTA,%00000010         ; Set REV dir. for STARBOARD (right) motor
              LDAA  TOF_COUNTER             ; Mark the fwd_turn time Tfwdturn
              ADDA  #FWD_TRN_INT
              STAA  T_FWD_TRN
              RTS

; *****************INIT_REV_TRN subroutine

INIT_REV_TRN  BCLR  PORTA,%00000010         ; Set FWD dir. for STARBOARD (right) motor
              LDAA  TOF_COUNTER             ; Mark the fwd time Tfwd
              ADDA  #REV_TRN_INT
              STAA  T_REV_TRN
              RTS  
              
; *****************READ_SENSORS subroutine

; This routine reads the eebot guider sensors and puts the results in RAM registers.
; Guider board mux must be set to the appropriate channel using the SELECT_SENSOR routine.

; The A/D conversion mode used in this routine is to read the A/D channel AN1 four times into
;  HCS12 data registers ATDDR0, 1, 2, 3. The only result used in this routine is the value 
;  from AN1, read from ATDDR0.
; However, other routines may wish to use the results in ATDDR1, 2 and 3.
; Consequently, Scan=0, Mult=0 and Channel=001 for the ATDCTL5 control word.

READ_SENSORS  CLR   SENSOR_NUM              ; Select sensor number 0
              LDX   #SENSOR_LINE            ; Point at the start of the sensor array
              
RS_MAIN_LOOP  LDAA  SENSOR_NUM              ; Select the correct sensor input
              JSR   SELECT_SENSOR           ;  on the hardware
              LDY   #400                    ; 20 ms delay to allow the
              JSR   del_50us                ;  sensor to stabilize
              
              LDAA  #$10000001              ; Start A/D conversion on AN1 
              SRAA  ATDCTL5
              BRCLR ATDSTAT0,$80,*          ; Repeat until A/D signals done
              
              LDAA  ATDDR0L                 ; A/D conversion is complete in ATDDR0L
              STAA  0,X                     ;  so copy it to the sensor register
              CPX   #SENSOR_STBD            ; If this is the last reading
              BEQ   RS_EXIT                 ; Then exit
              
              INC   SENSOR_NUM              ; Else, increment the sensor number
              INX                           ;  and the pointer into the sensor
              BRA   RS_MAIN_LOOP            ;  and do it again

RS_EXIT       RTS

; *****************SELECT_SENSOR subroutine   

; This routine selects the sensor number passed in AccA. The motor direction bits 0, 1,
;  the guider sensor select bit 5 and the unused bits 6, 7 in the same machine register
;  PORTA are not affect.
; Bits PA2, PA3, PA4 are connect to a 74HC4051 analog mux on the guider board, which selects
;  the guider sensor to be connected to AN1.

SELECT_SENSOR PSHA                          ; Save the sensor number for the moment
      
              LDAA  PORTA                   ; Clear the sensor selection bits to zeros
              ANDA  #$11100011      
              STAA  TEMP                    ;  and save it into TEMP
              
              PULA                          ; Get the sensor number    
              ASLA                          ; Shift the selection number left, twicce
              ASLA                          ;
              ANDA  #%00011100              ; Clear irrelevant bit positions
              
              ORAA  TEMP                    ; OR it into the sensor bit positions
              STAA  PORTA                   ; Update the hardware
              
              RTS    
              
; *****************Displar Sensor Readings

; This routine write the sensor values to the LCD

DP_FRONT_SENSOR EQU TOP_LINE+3
DP_PORT_SENSOR  EQU BOT_LINE+0
DP_MID_SENSOR   EQU BOT_LINE+3
DP_STBD_SENSOR  EQU BOT_LINE+6
DP_LINE_SENSOR  EQU BOT_LINE+9

DISPLAY_SENSORS LDAA  SENSOR_BOW    ; Get the FRONT sensor value
                JSR   BIN2ASC       ; Convert to ASCII string in D
                LDX   #DP_FRONT_SENSOR  ; Point to the LCD buffer position
                STD   0,X               ;  and write the 2 ASCII digits then
                
                LDAA  SENSOR_PORT     ; Repeat for the PORT value
                JSR   BIN2ASC       ; Convert to ASCII string in D
                LDX   #DP_PORT_SENSOR  ; Point to the LCD buffer position
                STD   0,X               ;  and write the 2 ASCII digits then
                
                LDAA  SENSOR_MID      ; Repeat for the MID value
                JSR   BIN2ASC       ; Convert to ASCII string in D
                LDX   #DP_MID_SENSOR  ; Point to the LCD buffer position
                STD   0,X               ;  and write the 2 ASCII digits then
                
                LDAA  SENSOR_STBD      ; Repeat for the STARBOARD value
                JSR   BIN2ASC       ; Convert to ASCII string in D
                LDX   #DP_STBD_SENSOR  ; Point to the LCD buffer position
                STD   0,X               ;  and write the 2 ASCII digits then
                
                LDAA  SENSOR_LINE      ; Repeat for the LINE value
                JSR   BIN2ASC       ; Convert to ASCII string in D
                LDX   #DP_LINE_SENSOR  ; Point to the LCD buffer position
                STD   0,X               ;  and write the 2 ASCII digits then
                
                LDAA  #CLEAR_HOME   ; Clear the display and home the cursor
                JSR   cmd2LCD       ;  "
                
                LDY   #40           ; Wait 2 ms until "clear display" command is complete
                JSR   del_50us
                
                LDX   #TOP_LINE     ; Now copy the buffer top line to the LCD
                JSR   putsLCD       ;
                
                LDAA  #LCD_SEC_LINE   ; Position the LCD cursor on the second line
                JSR   LCD_POS_CRSR
                
                LDX   #BOT_LINE     ; Copy the buffer bottom line to the LCD
                JSR   putsLCD
                
                RTS
                
;******************Binary to ASCII
                
; Utility Subroutines                  

;*******************************************************************
;* Initialization of the LCD: 4-bit data width, 2-line display,    *
;* turn on display, cursor and blinking off. Shift cursor right.   *
;*******************************************************************
initLCD       BSET  DDRB,%11111111          ; configure pins PS7,...,PS0 for output
              BSET  DDRJ,%11000000          ; configure pins PE7,PE4 for output
              LDY   #2000                   ; wait for LCD to be ready
              JSR   del_50us                ; -"-
              LDAA  #$28                    ; set 4-bit data, 2-line display
              JSR   cmd2LCD                 ; -"-
              LDAA  #$0C                    ; display on, cursor off, blinking off
              JSR   cmd2LCD                 ; -"-
              LDAA  #$06                    ; move cursor right after entering a character
              JSR   cmd2LCD                 ; -"-
              RTS

;*******************************************************************
;* Clear display and home cursor                                   *
;*******************************************************************            
clrLCD        LDAA  #$01                    ; clear cursor and return to home position
              JSR   cmd2LCD                 ; -"-
              LDY   #40                     ; wait until "clear cursor" command is complete
              JSR   del_50us                ; -"-
              RTS
            
;*******************************************************************
;* ([Y] x 50us)-delay subroutine. E-clk=41, 67ns.                  *
;*******************************************************************
del_50us      PSHX                          ; 2 E-clk
eloop:        LDX   #30                     ; 2 E-clk
iloop:        PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              PSHA                          ; 2 E-clk
              PULA                          ; 3 E-clk
              NOP                           ; 1 E-clk
              NOP                           ; 1 E-clk
              DBNE  X,iloop                 ; 3 E-clk
              DBNE  Y,eloop                 ; 3 E-clk
              PULX                          ; 3 E-clk
              
              RTS                           ; 5 E-clk

;*******************************************************************
;* This function sends a command in accumulator A to the LCD       *
;*******************************************************************            
cmd2LCD       BCLR  LCD_CNTR,LCD_RS         ; select the LCD Instruction Register (IR)
              JSR   dataMov                 ; send data to IR
              RTS

;*******************************************************************
;* This function outputs a NULL-terminated string pointed to by X  *
;*******************************************************************            
putsLCD       LDAA  1,X+                    ; get one character from the string
              BEQ   donePS                  ; reach NULL character?
              JSR   putcLCD
              BRA   putsLCD
              
donePS        RTS

;*******************************************************************
;* This function outputs the character in accumulator A to LCD     *
;*******************************************************************
putcLCD       BSET  LCD_CNTR,LCD_RS         ; select the LCD Data Register (DR)
              JSR   dataMov                 ; sed data to DR
              RTS
            
;*******************************************************************
;* This function sends data to the LCD IR or DR depending on RS    *
;*******************************************************************            
dataMov       BSET  LCD_CNTR,LCD_E          ; pull the LCD E-signal high
              STAA  LCD_DAT                 ; send the upper 4 bits of data to LCD
              BCLR  LCD_CNTR,LCD_E          ; pull the LCD E-signal low to complete the write oper.
            
              LSLA                          ; Match the lower 4 bits with the LCD data pins
              LSLA                          ; -"-
              LSLA                          ; -"-
              LSLA                          ; -"-
           
              BSET  LCD_CNTR,LCD_E          ; pull the LCD E-signal high
              STAA  LCD_DAT                 ; send the lower 8 bits of data to LCD
              BCLR  LCD_CNTR,LCD_E          ; pull the LCD E-signal low to complete the write oper.
              
              LDY   #1                      ; adding this delay will complete the internal
              JSR   del_50us                ;  operation for most instructions
            
              RTS
              
; *****************initAD subroutine

initAD        MOVB  #$C0,ATDCTL2            ;power up AD, select fast flag clear
              JSR   del_50us                ;wait for 50 us
              MOVB  #$00,ATDCTL3            ;8 conversions in a sequence
              MOVB  #$85,ATDCTL4            ;res=8, conv-clks=2, prescal=12
              BSET  ATDDIEN,$0C             ;configure pins AN03,AN02 as digital inputs
              RTS
            
; *****************int2BCD subroutine
;*         Integer to BCD Conversion Routine

;* This routine converts a 16 bit binary number in .D into
;* BCD digits in BCD_BUFFER.
;* Peter Hiscocks

;* Algorithm:
;*  Because the IDIV (Integer Division) instruction is available on
;*   the HCS12, we can determine the decimal digits by repeatedly
;*   dividing the binary number by ten: the remainder each time is
;*   a decimal digit. Conceptually, what we are doing is shifting
;*   the decimal number one place to the right past the decimal
;*   point with each divide operation. The remainder must be
;*   a decimal digit between 0 and 9, because we divided by 10.
;*   The algorithm terminates when the quotient has become zero.
;*   Bug note: XGDX does not set any condition codes, so test for
;*   quotient zero must be done explicitly with CPX.

;* Data structure:
;* BCD_BUFFER  EQU * The following registers are the BCD buffer area
;* TEN_THOUS   RMB 1 10,000 digit, max size for 16 bit binary
;* THOUSANDS   RMB 1 1,000 digit
;* HUNDREDS    RMB 1 100 digit
;* TENS        RMB 1 10 digit
;* UNITS       RMB 1 1 digit
;* BCD_SPARE   RMB 2 Extra space for decimal point and string terminator


int2BCD       XGDX                          ; Save the binary number into .X
              LDAA  #0                      ; Clear the BCD_BUFFER
              STAA  TEN_THOUS
              STAA  THOUSANDS
              STAA  HUNDREDS
              STAA  TENS
              STAA  UNITS
              STAA  BCD_SPARE
              STAA  BCD_SPARE+1
              
              CPX   #0                      ; Check for a zero input
              BEQ   CON_EXIT                ;  and if so, exit
            
              XGDX                          ; Not zero, get the binary number back to .D as dividend
              LDX   #10                     ; Stepup 10 (Decimal!) as the divisor 
              IDIV                          ; Divide: Quotient is now in .X, remainder in .D
              STAB  UNITS                   ; Store remainder
              CPX   #0                      ; If quotient is zero,
              BEQ   CON_EXIT                ;  then exit
            
              XGDX                          ;  else swap first quotient back into .D
              LDX   #10                     ;  and setup for another divide by 10
              IDIV
              STAB  TENS
              CPX   #0
              BEQ   CON_EXIT
            
              XGDX                          ;  else swap first quotient back into .D
              LDX   #10                     ;  and setup for another divide by 10
              IDIV
              STAB  HUNDREDS
              CPX   #0
              BEQ   CON_EXIT
            
              XGDX                          ;  else swap first quotient back into .D
              LDX   #10                     ;  and setup for another divide by 10
              IDIV
              STAB  THOUSANDS
              CPX   #0
              BEQ   CON_EXIT
            
              XGDX                          ;  else swap first quotient back into .D
              LDX   #10                     ;  and setup for another divide by 10
              IDIV
              STAB  TEN_THOUS
            
CON_EXIT      RTS

; *****************BCD2ASC subroutine

; BCD_BUFFER  EQU   *   The following registers are the BCD buffer area
; TEN_THOUS   RMB   1   10,000 digit
; THOUSANDS   RMB   1   1,000 digit
; HUNDREDS    RMB   1   100 digit
; TENS        RMB   1   10 digit
; UNITS       RMB   1   1 digit
; BCD_SPARE   RMB   10  Extra space for decimal point and string terminator
; NO_BLANK    RMB   1   Used in �leading zero� blanking by BCD2ASC
;
; This routine converts the BCD number in the BCD_BUFFER
;  into ascii format, with leading zero suppression.
; Leading zeros are converted into space characters.
; The flag 'NO_BLANK' starts cleared and is set once a non-zero
;  digit has been detected
; The 'units' digit is never blanked, even if it and all the
;  preceding digits are zero.
; Peter Hiscocks

BCD2ASC       LDAA  #0                      ; Initialize the blanking flag
              STAA  NO_BLANK
            
C_TTHOU       LDAA  TEN_THOUS               ; Check the 'ten_thousands' digit
              ORAA  NO_BLANK
              BNE   NOT_BLANK1
            
ISBLANK1      LDAA  #' '                    ; It's blank
              STAA  TEN_THOUS               ;  so store a space
              BRA   C_THOU                  ;  and check the 'thousands' digit
            
NOT_BLANK1    LDAA  TEN_THOUS               ; Get the 'ten_thousands' digit
              ORAA  #$30                    ; Convert to ascii
              STAA  TEN_THOUS
              LDAA  #$1                     ; Signal that we have seen 'non-blank' digit
              STAA  NO_BLANK
            
C_THOU        LDAA  THOUSANDS               ; Check the thousands digit for blankness
              ORAA  NO_BLANK                ; If it's blank and 'no-blank' is still zero
              BNE   NOT_BLANK2
            
ISBLANK2      LDAA  #' '                    ; Thousands digit is blank
              STAA  THOUSANDS               ;  so store a space
              BRA   C_HUNS                  ;  and check the hundreds digit
            
NOT_BLANK2    LDAA  THOUSANDS               ; (similar to 'ten_thousands' case)
              ORAA  #$30
              STAA  THOUSANDS
              LDAA  #$1
              STAA  NO_BLANK
            
C_HUNS        LDAA  HUNDREDS                ; Check the hundreds digit for blankness
              ORAA  NO_BLANK                ; If it's blank and 'no-blank' is still zero
              BNE   NOT_BLANK3
            
ISBLANK3      LDAA  #' '                    ; Hundreds digit is blank
              STAA  HUNDREDS                ;  so store a space
              BRA   C_TENS                  ;  and check the tens digit
            
NOT_BLANK3    LDAA  HUNDREDS                ; (similar to 'ten_thousands' case)
              ORAA  #$30
              STAA  HUNDREDS
              LDAA  #$1
              STAA  NO_BLANK

C_TENS        LDAA  TENS                    ; Check the tens digit for blankness
              ORAA  NO_BLANK                ; If it's 'blank' and 'no-blank' is still zero
              BNE   NOT_BLANK4
            
ISBLANK4      LDAA  #' '                    ; Tens digit is blank
              STAA  TENS                    ;  so store a space
              BRA   C_UNITS                 ;  and check the units digit
            
NOT_BLANK4    LDAA  TENS                    ; (similar to 'ten_thousands' case)
              ORAA  #$30
              STAA  TENS

C_UNITS       LDAA  UNITS                   ; No blank check necessary, convert to ascii.
              ORAA  #$30
              STAA  UNITS                                     
            
              RTS
            
; *****************ENABLE_TOF subroutine

ENABLE_TOF    LDAA  #%10000000
              STAA  TSCR1                   ; Enable TCNT
              STAA  TFLG2                   ; Clear TOF
              LDAA  #%10000100              ; Enable TOI and select prescale factor equal to 16
              STAA  TSCR2
              RTS
            
; *****************TOF_ISR subroutine
            
TOF_ISR       INC   TOF_COUNTER             ; Increment the overflow count
              LDAA  #%10000000              ; Clear
              STAA  TFLG2                   ;  TOF
              RTI
            
;*******************************************************************
;*          Update Display (Battery Voltage + Current State)       *
;*******************************************************************
UPDT_DISPL    MOVB  #$90,ATDCTL5            ; R-just., uns., sing. conv., mult., ch=0, start
              BRCLR ATDSTAT0,$80,*          ; Wait until the conver. seq. is complete
              
              LDAA  ATDDR0L                 ; Load the ch0 result - battery volt - into A
                                            ; Display the battery voltage
              MOVB  #$90,ATDCTL5            ; R-just., unsign., sing.conv., mult., ch0, start conv.
              BRCLR ARDSTAT0,$80,*          ; Wait until the conver. seq. is complete
              
              LDAA  ATDDR0L                 ; load the ch4 result into AccA
              LDAB  #39                     ; AccB = 39
              MUL                           ; AccD = 1st result x 39
              ADDD  #600                    ; AccD = 1st result x 39 + 600
              
              JSR   int2BCD
              JSR   BCD2ASC
              
              LDAA  #$8F                    ; move LCD cursor to the 1st row, end of msg1
              JSR   cmd2LCD                 ;  "
              
              LDAA  TEN_THOUS               ; output the TEN_THOUS ASCII Character
              JSR   putcLCD                 ;  "
              LDAA  THOUSANDS               ; output the THOUSANDS ASCII Character
              JSR   putcLCD                 ;  "
              LDAA  #2E                     ; output the "." ASCII Character
              JSR   putcLCD                 ;  "
              LDAA  HUNDREDS                ; output the HUNDREDS ASCII Character
              JSR   putcLCD                 ;  "
              
;-------------------------
              LDAA  #$C6                    ; Move LCD cursor to the 2nd row, end of msg2
              JSR   cmd2LCD                 ;
              
              LDAB  CRNT_STATE              ; Display current state
              LSLB                          ; "            
              LSLB                          ; "
              LSLB                          ; "
              LDX   #tab                    ; "
              ABX                           ; "
              JSR   putsLCD                 ; "
              
              RTS

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
              ORG   $FFFE
              DC.W  Entry                   ; Reset Vector
              ORG   $FFDE
              DC.W  TOF_ISR                 ; Timer Overflow Interrupt Vector
