;--------------------------------------------------------------------------------------------
; ROTINAS EXTERNAS
;--------------------------------------------------------------------------------------------
EXTRN CODE(INIDISP,ESCINST,GOTOXY,CLR2L,ESCDADO,MSTRING,MSTRINGX,ESC_STR1,ESC_STR2,CUR_ON,CUR_OFF,Atraso,ATRASO_MS)
EXTRN CODE(DETECT_PICO)
EXTRN CODE(CONVADC)
EXTRN CODE(CTRL_GANHO)
;--------------------------------------------------------------------------------------------
; TABELA DE EQUATES - 30h a 4Fh
;--------------------------------------------------------------------------------------------
;;;;;;;IO;;;;;;;
;LCD
RS		EQU	P2.5		;COMANDO RS LCD
E_LCD	EQU	P2.7		;COMANDO E (ENABLE) LCD
RW		EQU	P2.6		;READ/WRITE
BUSYF	EQU	P0.7		;BUSY FLAG
	
;LEDS DA PLACA
LEDVD	EQU	P3.6
LEDAM   EQU	P3.7
LEDVM	EQU	P1.4
	
;SWITCHES DA PLACA
SW1 EQU P3.2
SW2 EQU P3.4
	
;PORTS
TEM_DEDO EQU P3.0 ;tem dedo no sensor?
	
;VARIAVEIS - BITS
ESTAVEL EQU 00h ;bit-endereçável - sistema está estável?

;VARIAVEIS - BYTES
PICO_MAX EQU 30h ;valor maximo de pico do sinal
CTR_PICOS EQU 31h ;numero de picos
BUF_SINAL_0 EQU 32h ;posição 0 do buffer do sinal
BUF_SINAL_1 EQU 33h ;posição 1 do buffer do sinal
BUF_PICO EQU 34h ; buffer para salvar supostos picos
REF_PICO EQU 35h ; valor de referência dos picos (minimo para considerer um pico)

ESTADO EQU 50h ;para maquina de estados da detecção de picos
ADC1 EQU 51h ;valor da curva de SpO2


;--------------------------------------------------------------------------------------------
; PROGRAMA PRINCIPAL
;--------------------------------------------------------------------------------------------
PROG SEGMENT CODE
	RSEG PROG
	CSEG


ORG 0000h
	JMP INICIO
	
ORG 000Bh
	JMP ISR_TIMER0
	
ORG 001Bh
	JMP ISR_TIMER1
	
ORG 0023h
	JMP ISR_SERIAL
	
ORG 0050h
	
INICIO:
	SJMP $
	

ISR_TIMER0:
	;timer 0 - detecção de pico
	;dispara em 20hz
	;alta prioridade
	;salvar registradores!!!!!!
	RETI

ISR_TIMER1:
	RETI
	
ISR_SERIAL:
	RETI

END