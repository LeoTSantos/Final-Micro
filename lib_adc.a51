PUBLIC CONVADC
;***************************************************************************
; EQUATES
;***************************************************************************

;ADC SPI Interface
SS		EQU	P1.1 ;slave select. Ativo em zero
MISO	EQU P1.5
MOSI	EQU P1.7
SCK		EQU P1.6 ;slave clock

;***************************************************************************
;
;***************************************************************************

PROG SEGMENT CODE
	RSEG PROG
		
;***************************************************************************
;NOME: CONVADC
;DESCRICAO: LÊ O VALOR DO CANAL ESPECIFICADO POR A DO ADC
;ENTRADA: A - CANAL DO ADC A SER CONVERTIDO (0 ou 1)
;SAIDA: A - VALOR LIDO DO ADC
;ALTERA: B
;***************************************************************************
CONVADC:
	JZ canal_zero
	MOV A, #0E0h
	JMP continua
	canal_zero:
	MOV A, #0C0h
	continua:
	CLR 	SS
	MOV	B,#03H		;ENVIAR 3 BITS
ENVIA:
	RLC	A
	MOV	MOSI,C
	CALL 	PULSE
	DJNZ	B,ENVIA
	MOV	B,#08H		;RECEBER 8 BITS
RECEBE:
	CALL	PULSE
	MOV	C,MISO
	RLC	A
	DJNZ	B,RECEBE
	SETB	SS
	RET
	
;***************************************************************************
;NOME: PULSE
;DESCRICAO: Dá um pulso de clock para comunicação SPI
;ENTRADA: -
;SAIDA: -
;DESTROI: -
;***************************************************************************
PULSE:
	SETB SCK
	NOP
	CLR SCK
	RET

END