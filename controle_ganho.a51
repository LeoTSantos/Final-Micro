PUBLIC ATUALIZA_POT

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
GANHO_ANT EQU 61h ;ganho da iteração anterior

;***************************************************************************
; ROTINA DE CONTROLE DE GANHO
;***************************************************************************

PROG SEGMENT CODE
	RSEG PROG
	
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
	CLR MOSI
	
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