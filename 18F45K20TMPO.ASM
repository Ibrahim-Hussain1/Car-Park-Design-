;******************************************************************************
;                                                                             *
;    Filename:         Car_Parking.asm                                                *
;    Date:                                                                    *
;    File Version:                                                            *
;    Author:                                                                  *
;    Company:                                                                 *
;                                                                             *
;******************************************************************************

;------------------------------------------------------------------------------
; PROCESSOR DECLARATION
;------------------------------------------------------------------------------

     LIST      P=PIC18F45K20          ; list directive to define processor
     #INCLUDE <P18F45K20.INC>         ; processor specific variable definitions

;------------------------------------------------------------------------------
;
; CONFIGURATION WORD SETUP
;
; The 'CONFIG' directive is used to embed the configuration word within the 
; .asm file. The lables following the directive are located in the respective 
; .inc file.  See the data sheet for additional information on configuration 
; word settings.
;
;------------------------------------------------------------------------------

     CONFIG FOSC = INTIO67, FCMEN = OFF, IESO = OFF, PWRT = OFF, BOREN = OFF
     CONFIG BORV = 18, WDTEN = OFF, WDTPS = 1, MCLRE = ON, HFOFST = ON
     CONFIG LPT1OSC = OFF, PBADEN = OFF, CCP2MX = PORTC, STVREN = OFF
     CONFIG LVP = OFF,  XINST = OFF, CP0 = OFF, CP1 = OFF, CP2 = OFF
     CONFIG CP3 = OFF, CPB = OFF, CPD = OFF, WRT0 = OFF, WRT1 = OFF
     CONFIG WRT2 = OFF, WRT3 = OFF, WRTB = OFF, WRTC = OFF, WRTD = OFF
     CONFIG EBTR0 = OFF, EBTR1 = OFF, EBTR2 = OFF, EBTR3 = OFF
     CONFIG EBTRB = OFF

;------------------------------------------------------------------------------
;
; VARIABLE DEFINITIONS
;
;------------------------------------------------------------------------------

    CBLOCK 0x60 		  ; Sample GPR variable register allocations
        STEP_COUNT 		  ; user variable at address 0x60
        OPERATOR_COUNTER  ; user variable at address 0x61
        MYVAR3    		  ; user variable at address 0x62
    ENDC

W_TEMP         EQU        0x000  ; w register for context saving (ACCESS)
STATUS_TEMP    EQU        0x001  ; status used for context saving 
BSR_TEMP       EQU        0x002  ; bank select used for ISR context saving

;------------------------------------------------------------------------------
; RESET VECTOR
;------------------------------------------------------------------------------

RES_VECT  ORG     0x0000            ; processor reset vector
          GOTO    MAIN              ; go to beginning of program

;------------------------------------------------------------------------------
; HIGH PRIORITY INTERRUPT VECTOR
;------------------------------------------------------------------------------

ISRH      ORG     0x0008

          ; Run the High Priority Interrupt Service Routine
          GOTO    HIGH_ISR             

;------------------------------------------------------------------------------
; LOW PRIORITY INTERRUPT VECTOR
;------------------------------------------------------------------------------

ISRL      ORG     0x0018
          
          ; Run the High Priority Interrupt Service Routine
          GOTO    LOW_ISR             

;------------------------------------------------------------------------------
; HIGH PRIORITY INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------

HIGH_ISR  

		  BTFSS PORTB,0				; Check external interrupt occured
		  CALL OPERATOR				; If yes go to operator label

		  BCF INTCON,1				; Clear INT0 flag
	
          RETFIE  FAST				; Return from ISR


		OPERATOR
		  BTFSS OPERATOR_COUNTER,0	; Bit test how many times operator push the button
		  GOTO OPEN_GATES			; If no times, open the gates
		  GOTO CLOSE_GATES			; If one time, close the gates


		OPEN_GATES
		  BCF PORTD,1				; Set motors direction to open
		  BCF PORTD,3

		  BTFSS PORTB,1				; check IN gate LDR sensor 
		  CALL IN_STEPPING			; If the gate is already open then ignore

		  BTFSS PORTB,2				; check OUT gate LDR sensor 
		  CALL OUT_STEPPING			; If the gate is already open then ignore

		  INCF OPERATOR_COUNTER,F	; Increment push button counter by one

		  RETURN					; Return from the function


		CLOSE_GATES
		  BSF PORTD,1				; Set motors direction to open
		  BSF PORTD,3

		  BTFSS PORTB,1				; check IN gate LDR sensor 
		  CALL IN_STEPPING			; If the gate is already closed then ignore

		  BTFSS PORTB,2				; check OUT gate LDR sensor 
		  CALL OUT_STEPPING			; If the gate is already closed then ignore

		  CLRF OPERATOR_COUNTER		; clear push button counter

		  RETURN					; Return from the function

;------------------------------------------------------------------------------
; LOW PRIORITY INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------

LOW_ISR
          ; Context Saving for Low ISR
          MOVWF   W_TEMP              ; save W register
          MOVFF   STATUS, STATUS_TEMP ; save status register
          MOVFF   BSR, BSR_TEMP       ; save bankselect register

          ; Insert Low Priority ISR Here
		  ; NOT USED

          ; Context Saving for Low ISR
          MOVFF   BSR_TEMP, BSR       ; restore bankselect register
          MOVF    W_TEMP, W           ; restore W register
          MOVFF   STATUS_TEMP, STATUS ; restore status register
          RETFIE

;------------------------------------------------------------------------------
; MAIN PROGRAM
;------------------------------------------------------------------------------

MAIN

          MOVLW 0x72
		  MOVWF OSCCON	; 16MHz Internal oscillator block
	
		  CLRF 	PORTB	; Clearing output data latches
		  CLRF 	PORTC	; Clearing output data latches
    	  CLRF 	PORTD	; Clearing output data latches

		  MOVLW 0xF8
		  CLRF 	ANSELH  ; Configure I/O for digital inputs (RB<2:0>)

		  MOVLW 0x07 	 
		  MOVWF TRISB 	; Set RB<2:0> as inputs 
		  MOVLW 0xF0
		  MOVWF TRISC	; Set RC<3:0> as outputs 
		  MOVLW 0x00
		  MOVWF TRISD	; Set RD<7:0> as outputs 

		  MOVLW 0x80
		  MOVWF RCON	; Enable priority levels on interrupts

		  MOVLW 0x90
		  MOVWF INTCON	; Enables all high priority interrupts
		  				; Enables the INT0 external interrupt
						; Clear INT0 external Interrupt Flag bit

		  MOVLW 0x00
		  MOVWF INTCON2 ; PORTB pull-ups are enabled
						; INT0 external interrupt on falling edge

		  MOVLW 0x07
		  MOVWF T0CON	; Timer0 is configured as a 16-bit timer/counter
						; Internal instruction cycle clock (CLKOUT) 						; Increment on low-to-high transition on T0CKI pin
						; Timer0 prescaler is assigned. Timer0 clock input comes from prescaler output.
						; 1:256 prescale value

;------------------------------------------------------------------------------
; WHILE LOOP
;------------------------------------------------------------------------------

	WHILE_LOOP
	 
	 IN_GATE
		MAX_PARKING_CHECK				; 9 decimal => 1001 binary
		  BTFSS PORTC,3					; 3rd bit test
		  GOTO PARKING_AVALIABLE		; If 3rd bit not set goto parking avaliable lable
		  BTFSS PORTC,0					; If 3rd bit set check 0th bit
		  GOTO PARKING_AVALIABLE		; If 0th bit not set goto parking avaliable lable
		  GOTO PARKING_NOT_AVALIABLE	; If 0th bit set goto parking not avaliable lable		

		PARKING_AVALIABLE
		  BSF PORTD,5					; Green LED ON
		  BCF PORTD,4					; Red LED OFF
		  BTFSC PORTB,1					; Check IN gate LDR sensor 
		  GOTO IN_STEPPER_OPEN			; If car is arrived goto open the gate lable
		  GOTO OUT_GATE					; If car is not arrived go to OUT gate lable

		PARKING_NOT_AVALIABLE
		  BSF PORTD,4					; Red LED ON
		  BCF PORTD,5					; Green LED OFF
		  GOTO OUT_GATE					; Go to OUT gate lable
		  
	 OUT_GATE
		  BTFSC PORTB,2					; Check OUT gate LDR sensor 
		  GOTO OUT_STEPPER_OPEN			; If car is arrived goto open the gate lable						
		  GOTO WHILE_LOOP				; If car is not arrived ignore and go to the while loop

;------------------------------------------------------------------------------
; IN GATE STEPPER MOTOR CONTROL (OPEN & CLOSE)
;------------------------------------------------------------------------------

		IN_STEPPER_OPEN
		  BCF PORTD,1					; Set the motor direction to open
		  CALL IN_STEPPING				; call stepping function

		CAR_NOT_ENTERED
		  BTFSC PORTB,1					; Check IN gate LDR sensor 
		  GOTO CAR_NOT_ENTERED			; If the car is not entered the parking, wait open gate position

		  INCF PORTC,F					; If the car is entered increment count and display on SSD
		  GOTO IN_STEPPER_CLOSE			; close the IN gate

		IN_STEPPER_CLOSE
		  BSF PORTD,1					; Set the motor direction to close
		  CALL IN_STEPPING				; call stepping function

		  GOTO WHILE_LOOP				; go to the while loop

;------------------------------------------------------------------------------
; OUT GATE STEPPER MOTOR CONTROL (OPEN & CLOSE)
;------------------------------------------------------------------------------

		OUT_STEPPER_OPEN
		  BCF PORTD,3					; Set the motor direction to open
		  CALL OUT_STEPPING				; call stepping function

		CAR_NOT_OUT
		  BTFSC PORTB,2					; Check OUT gate LDR sensor 
		  GOTO CAR_NOT_OUT				; If the car is not out the parking, wait open gate position

		  DECF PORTC,F					; If the car is out decrement count and display on SSD
		  GOTO OUT_STEPPER_CLOSE		; close the out gate

		OUT_STEPPER_CLOSE
		  BSF PORTD,3					; Set the motor direction to close
		  CALL OUT_STEPPING				; call stepping function

		  GOTO WHILE_LOOP				; go to the while loop
	
;------------------------------------------------------------------------------
; IN GATE MOTOR STEPS TO 90 DEGREES
;------------------------------------------------------------------------------

IN_STEPPING
	  	  MOVLW D'24'
		  MOVWF STEP_COUNT				; 90 degree rotation

		  BSF T0CON,7					; Timer0 ON
		
		NEXT_STEP
		  BSF PORTD,0					; Clock high

		  MOVLW 0xFE
		  MOVWF TMR0H
		  MOVLW 0x78
		  MOVWF TMR0L					; 25ms delay

		WAIT
		  BTFSS INTCON,2				; Wait until Timer0 overflow
		  GOTO WAIT

		  BCF INTCON,2					; Clear Timer0 flag
		  BCF PORTD,0					; Clock low


		  MOVLW 0xFE
		  MOVWF TMR0H
		  MOVLW 0x78
		  MOVWF TMR0L					; 25ms delay

		WAIT1
		  BTFSS INTCON,2				; Wait until Timer0 overflow
		  GOTO WAIT1
		
		  BCF INTCON,2					; Clear Timer0 flag

		  DECFSZ STEP_COUNT,F			; Decrement step counter by one
		  GOTO NEXT_STEP				; If step counter is not zero go to the next step

		  BCF T0CON,7					; If step counter is zero off Timer0 and return

		  RETURN

;------------------------------------------------------------------------------
; OUT GATE MOTOR STEPS TO 90 DEGREES
;------------------------------------------------------------------------------

OUT_STEPPING
	  	  MOVLW D'24'
		  MOVWF STEP_COUNT				; 90 degree rotation

		  BSF T0CON,7					; Timer0 ON
		
		NEXT_STEP1
		  BSF PORTD,2					; Clock high

		  MOVLW 0xFE
		  MOVWF TMR0H
		  MOVLW 0x78
		  MOVWF TMR0L					; 25ms delay

		WAIT2
		  BTFSS INTCON,2				; Wait until Timer0 overflow
		  GOTO WAIT2

		  BCF INTCON,2					; Clear Timer0 flag
		  BCF PORTD,2					; Clock low


		  MOVLW 0xFE
		  MOVWF TMR0H
		  MOVLW 0x78
		  MOVWF TMR0L					; 25ms delay

		WAIT3
		  BTFSS INTCON,2				; Wait until Timer0 overflow
		  GOTO WAIT3
		
		  BCF INTCON,2					; Clear Timer0 flag

		  DECFSZ STEP_COUNT,F			; Decrement step counter by one
		  GOTO NEXT_STEP1				; If step counter is not zero go to the next step

		  BCF T0CON,7					; If step counter is zero off Timer0 and return

		  RETURN


          END							; End of the program