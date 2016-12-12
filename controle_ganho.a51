PUBLIC ATUALIZA_POT, CALC_GANHO
EXTRN CODE(D16BY8, MUL16X8)

;***************************************************************************
;EQUATES
;***************************************************************************

;SPI Interface - pot digital
SS_POT	EQU P1.2
MISO	EQU P1.5
MOSI	EQU P1.7
SCK		EQU P1.6 ;slave clock
	
PICO_MAX EQU 30h ;valor maximo de pico do sinal
	
;variável do pot digital
VALOR_POT EQU 60h ;valor de 0 a 125
	
;Para operações de divisão
QUOTIENTL	EQU 70h
QUOTIENTH	EQU 71h
DIVIDENDL	EQU 72h
DIVIDENDH	EQU 73h
DIVISOR		EQU 74h
REMAINDER	EQU 75h

;***************************************************************************
; ROTINA DE CONTROLE DE GANHO
;***************************************************************************

PROG SEGMENT CODE
	RSEG PROG

;***************************************************************************
;NOME: CALC_GANHO
;DESCRICAO: CALCULA O VALOR DO POT
;ENTRADA: PICO_MAX
;SAIDA: VALOR_POT
;DESTROI: 
;****************************************************************************
CALC_GANHO:
	MOV DIVISOR, PICO_MAX
	MOV DIVIDENDL, #0FFh
	MOV DIVIDENDH, #00h
	
	CALL D16BY8
	
	MOV A, QUOTIENTL
	CLR C
	SUBB A, #01h
	
	MOV VALOR_POT, A

	RET
	
;***************************************************************************
;NOME: ATUALIZA_POT
;DESCRICAO: CONTROLA O VALOR DO POT
;ENTRADA: VALOR_POT - novo valor do POT
;SAIDA: 
;DESTROI: 
;****************************************************************************
ATUALIZA_POT:
	CLR SCK ; modo 0,0 do SPI
	
	MOV A, VALOR_POT
	
	CLR SS_POT
	
	MOV B, #08
ENVIA_ZERO:
	CLR MOSI
	CALL PULSE
	DJNZ B, ENVIA_ZERO
	
	MOV B, #08
ENVIA:
	RLC	A
	MOV	MOSI,C
	CALL 	PULSE
	DJNZ	B,ENVIA
	NOP
	NOP
	SETB SS_POT
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