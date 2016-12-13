;--------------------------------------------------------------------------------------------
; ROTINAS EXTERNAS
;--------------------------------------------------------------------------------------------
EXTRN CODE(INIDISP,ESCINST,GOTOXY,CLR2L,ESCDADO,MSTRING,MSTRINGX,ESC_STR1,ESC_STR2,CUR_ON,CUR_OFF,Atraso,ATRASO_MS,ATUALIZA_DISPLAY)
EXTRN CODE(DETECT_PICO)
EXTRN CODE(CONVADC)
EXTRN CODE(ATUALIZA_POT, CALC_GANHO, CALC_FREQ)
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
	
;ADC SPI Interface
SS		EQU	P1.1 ;slave select. Ativo em zero
MISO	EQU P1.5
MOSI	EQU P1.7
SCK		EQU P1.6 ;slave clock
	
;SPI Interface - pot digital
SS_POT	EQU P1.2
	
;Buzzer
BUZZ EQU P1.3
	
;PORTS
TEM_DEDO EQU P1.0 ;tem dedo no sensor?

;VARIAVEIS - BITS
ESTAVEL EQU 00h ;bit-endereçável - sistema está estável?
NOVO_PICO EQU 01h ;bit-endereçável - tem novo pico?
NOVA_FREQ EQU 02h ;requisição de cálculo da frequência cardiaca
TR0_INT EQU 03h ;interrupção de timer 0 acontece vez sim, vez não

;VARIAVEIS - BYTES
PICO_MAX EQU 30h ;valor maximo de pico do sinal
CTR_PICOS EQU 31h ;numero de picos
NUM_PICOS_ANT EQU 32h ;numero de picos no ultimo segundo
FREQ_CARD EQU 33h ;frequência cardiaca
BUF_SINAL_0 EQU 34h ;posição 0 do buffer do sinal
BUF_SINAL_1 EQU 35h ;posição 1 do buffer do sinal
BUF_PICO EQU 36h ; buffer para salvar supostos picos
REF_PICO EQU 37h ; valor de referência dos picos (minimo para considerar um pico)
ESTADO EQU 38h ;para maquina de estados da detecção de picos
CTR_RESET_MAX EQU 39h ;contador para reset do pico maximo
	
TMR0_CTR_SEG EQU 41h ; contador para timer 0 - conta 1s

ADC1 EQU 51h ;valor da curva de SpO2

;variável do pot digital
VALOR_POT EQU 60h ;valor de 0 a 125
GANHO_ANT EQU 61h ;ganho da iteração anterior

;Para operações de divisão
QUOTIENTL	EQU 70h
QUOTIENTH	EQU 71h
DIVIDENDL	EQU 72h
DIVIDENDH	EQU 73h
DIVISOR		EQU 74h
REMAINDER	EQU 75h
	
;CONSTANTES 
TIMER_MAX EQU 65535
TMR0_TEMP EQU 50000 ; corresponde a 25ms

;--------------------------------------------------------------------------------------------
; PROGRAMA PRINCIPAL
;--------------------------------------------------------------------------------------------
PROG SEGMENT CODE
	RSEG PROG
	CSEG


ORG 2000h
	JMP INICIO
	
ORG 200Bh
	JMP ISR_TIMER0
	
ORG 201Bh
	JMP ISR_TIMER1
	
ORG 2023h
	JMP ISR_SERIAL
	
ORG 2050h
	
;************************************************************************
; ROTINA PRINCIPAL
;************************************************************************
INICIO:
;inciliza variáveis
	MOV PICO_MAX, #8Fh 
	MOV CTR_PICOS, #00h
	MOV NUM_PICOS_ANT, #00h
	MOV FREQ_CARD, #00h
	MOV BUF_SINAL_0, #00h
	MOV BUF_SINAL_1, #00h
	MOV BUF_PICO, #00h
	MOV REF_PICO, #0B5h
	MOV VALOR_POT, #30h
	MOV GANHO_ANT, #00h
	MOV ESTADO, #00h
	MOV TMR0_CTR_SEG, #200
	MOV CTR_RESET_MAX, #10
	CLR TR0_INT
	SETB SS
	SETB SS_POT
	CLR BUZZ
	CLR ESTAVEL
	CLR NOVA_FREQ
	CLR NOVO_PICO
	
;ganho inicial
	CALL ATUALIZA_POT
	
;iniciliza timer
	MOV TMOD, #00000001b ;timer 0 - modo 1
	
	;timer 0
	MOV TL0, #low(TIMER_MAX - TMR0_TEMP)
	MOV TH0, #high(TIMER_MAX - TMR0_TEMP)
	
	SETB ET0

; inicializa interface serial
	; Habilita recepção
	MOV SCON,#50H	; Porta Serial - 8 bits UART
	
	MOV PCON, #80h	; Baudrate = 9600 em 24MHz
	
	MOV TH1,#243
	MOV TL1,#243
	
	SETB TR1	; Inicia Timer
	
	CLR RI		; Limpa estados da interrupção serial
	CLR TI

	SETB ES ; habilita a int da serial

; liga interrupções
	SETB EA

; inicializa LCD
	;CALL INIDISP
	
LOOP:
	;MOV R0, #00
	;MOV R1, #00
	;CALL GOTOXY

	;MOV A, CTR_PICOS
	;CALL ATUALIZA_DISPLAY
	
	MOV BUF_SINAL_1, BUF_SINAL_0 ; avança posição da amostra no buffer
	
	CPL P3.0
	MOV A, #00h
	CALL CONVADC		; lê amostra do sinal
	MOV BUF_SINAL_0, A
	CPL P3.0
	
	CALL DETECT_PICO	; verifica pico
	
	JNB NOVA_FREQ, NAO_CALCULA
	
	;TODO: calcula frequência
	;TODO: transmite nova frequencia
	
NAO_CALCULA:
	JNB NOVO_PICO, LOOP	; se não teve pico, retorna ao loop
	
	MOV GANHO_ANT, VALOR_POT
	
	;CALL CALC_GANHO		; calcula novo ganho
	;CALL ATUALIZA_POT	; atualiza ganho
	CLR NOVO_PICO
	
	MOV PICO_MAX, #38h
	
	SJMP LOOP
;************************************************************************
;--------------------------------------------------------------------------------------------
; TABELAS
;--------------------------------------------------------------------------------------------
TAB_ASCII:
	DB '0',00H,'1',00H,'2',00H,'3',00H,'4',00H,'5',00H,'6',00H,'7',00H,'8',00H,'9',00H

	
; ISR TIMER 0
;************************************************************************
ISR_TIMER0:
	; conta 10s para calculo da frequência cardiaca
	MOV TL0, #low(TIMER_MAX - TMR0_TEMP)
	MOV TH0, #high(TIMER_MAX - TMR0_TEMP)
	
	MOV R3, TMR0_CTR_SEG	
	DJNZ R3, FIM_ISR_TMR0
		
	MOV NUM_PICOS_ANT, CTR_PICOS
	MOV CTR_PICOS, #00h
	
	JNB TR0_INT, NAO_DEU_O_TEMPO
	
	SETB NOVA_FREQ
	
NAO_DEU_O_TEMPO:
	CPL TR0_INT
	MOV R3, #200
	
FIM_ISR_TMR0:
	MOV TMR0_CTR_SEG, R3
	RETI
;************************************************************************

; ISR TIMER 1
;************************************************************************
ISR_TIMER1:
	
	RETI
;************************************************************************

; ISR INTERFACE SERIAL
;************************************************************************
ISR_SERIAL:
	RETI
;************************************************************************
END