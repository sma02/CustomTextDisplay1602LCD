.include "m328pdef.inc"
.include "UART_Macros.inc"
.include "1602_LCD_Macros.inc"
.include "delay_Macro.inc"


.org 0x0000
	jmp main
.org PCI2addr
	jmp PCINT2_ISR
.dseg
.org 0x0100
data_buffer:	.BYTE   128 ; Buffer to store string
.cseg
main:

	LDI r16, high(RAMEND) ; Set Stack Pointer to end of the RAM
	OUT SPH, r16 ; it is necessary when using interrupt vectors
	LDI r16, low(RAMEND)
	OUT SPL, r16

	SBI DDRB, PB5
	CBI DDRD, PD2 ; PD2 set as INPUT pin (push button1)
	SBI PORTD, PD2 ; Enable internal pull-up resistor

	LDI r16, 0b00000100 ; enabling PCIE2 interrupts
	STS PCICR, r16
	LDI r16, 0b00000100 ;enabling PCINT18 interrupt (PD2 Pin)
	STS PCMSK2, r16
	SEI

	LCD_init
	Serial_Begin
loop:       
	LDI     XL,LOW(data_buffer)       ; Set string pointer to the beginning of buffer
    LDI     XH,HIGH(data_buffer)

rx:         
	LDS     R21, UCSR0A
    SBRS    R21, RXC0    ; USART Receive Complete
    RJMP    rx
	
	LDS     R22, UDR0

    CPI     R22, 0x0D ; Check if carrage return character is received
    BRNE    store_char ; Store the received character in buffer

    LDI     R22, 0x00 ; Store null termination character
    ST      X+, R22

    LDI     XL, LOW(data_buffer) ; Set string pointer to the beginning of buffer
    LDI     XH, HIGH(data_buffer)
	call	print_string
    RJMP	loop  

store_char:     
	ST      X+, R22
    RJMP    rx


;Prints string on LCD , starting index of string in X pointer
print_string:
	; save the states of R16 and R17
	PUSH R16
	PUSH R17
	PUSH R20
	PUSH R21
	LCD_send_a_command 0x01
	LDI R21, 16 + 1

LCD_writeBuffer_LOOP:
		; load the current byte/character pointed to be Z and increment the Z pointer
	LD  R16, X+
	DEC R21
	CPI R21, 0
	BRNE c0
	LCD_send_a_command 0xC0
	c0:
	delay 15
	; check if the remaining size of the string is non-zero and return if it is
	CPI r16, 0
	BREQ LCD_writeBuffer_END
LCD_writeBuffer_CHAR:
	
	; Send the string character to the LCD
	; Clear the pins
	CBI PORTD, PD7         ; Clear PD7
	CBI PORTD, PD6         ; Clear PD6
	CBI PORTD, PD5         ; Clear PD5
	CBI PORTD, PD4         ; Clear PD4
	; Send the upper 4 bits of the Register to LCD
	SBRC R16, 7            ; Check the MSB (7th bit)
	SBI PORTD, PD7         ; Set PD7 according to the data bit
	SBRC R16, 6            ; Check the 6th bit
	SBI PORTD, PD6         ; Set PD6 according to the data bit
	SBRC R16, 5            ; Check the 5th bit
	SBI PORTD, PD5         ; Set PD5 according to the data bit
	SBRC R16, 4            ; Check the 4th bit
	SBI PORTD, PD4         ; Set PD4 according to the data bit

	SBI PORTB, PB0         ; Set RS pin to HIGH (set LCD mode to "Data Mode")
	SBI PORTB, PB1         ; Set E pin to HIGH (set LCD to receive the data)
	delay 10
	CBI PORTB, PB1         ; Set E pin to LOW (set LCD to process the data)

	; Clear the pins
	CBI PORTD, PD7         ; Clear PD7
	CBI PORTD, PD6         ; Clear PD6
	CBI PORTD, PD5         ; Clear PD5
	CBI PORTD, PD4         ; Clear PD4

	; Send the lower 4 bits of the Register to LCD
	SBRC R16, 3            ; Check the 3rd bit
	SBI PORTD, PD7         ; Set PD7 according to the data bit
	SBRC R16, 2            ; Check the 2nd bit
	SBI PORTD, PD6         ; Set PD6 according to the data bit
	SBRC R16, 1            ; Check the 1st bit
	SBI PORTD, PD5         ; Set PD5 according to the data bit
	SBRC R16, 0            ; Check the 0th bit
	SBI PORTD, PD4         ; Set PD4 according to the data bit

	SBI PORTB, PB1         ; Set E pin to HIGH (set LCD to receive the data)
	delay 10
	CBI PORTB, PB1         ; Set E pin to LOW (set LCD to process the data)

	DEC R20
	RJMP LCD_writeBuffer_LOOP
LCD_writeBuffer_END:

	LCD_send_a_command 0x0C ; screen on, Cursor off 
	; restore the states of R16 and R17 and return
	POP R21
	POP	R20
	POP R17
	POP R16
	RET

;This procedure starts count from 9 to 0
start_countdown:
	LDI r16,9+48 ; Setting Initial Countdown value
	LCD_send_a_command 0x01 ; Clearing Screen
	delay 1000
	continue_counter:
	LCD_send_a_character
	LCD_send_a_command 0x80 ; Moving Cursor to the start
	delay 1000
	DEC r16
	CPI r16,48
	BREQ end_counter ; Checks if countdown reaches zero
	RJMP continue_counter
	end_counter:

;Interrupt Service Routine for Interrupt attached on PD2
PCINT2_ISR:
	SBIS PIND, PD2 ; Checking if button is pressed
	RJMP l9
	RETI
	l9:
	CLI	; Disabling Interrupts
	call start_countdown
	LDI     XL, LOW(data_buffer) ; Set string pointer to the beginning of buffer
    LDI     XH, HIGH(data_buffer)
	call	print_string
	LDI     XL, LOW(data_buffer) ; Set string pointer to the beginning of buffer
    LDI     XH, HIGH(data_buffer)
	SEI	; Enabling Interrupts
	RETI