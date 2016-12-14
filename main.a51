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
;REGISTRADORES DE FUNÇÃO ESPECIAL
;timer2
T2CON EQU 0C8h
T2MOD EQU 0C9h
RCAP2L EQU 0CAh
RCAP2H EQU 0CBh
TL2 EQU 0CCh
TH2 EQU 0CDh

IEN0 EQU 0A8h
	
ET2 EQU IEN0.5
TR2 EQU T2CON.2
TF2 EQU T2CON.7
	
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
CALCULADO EQU 04h ;calculo da frequência realizado
	
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
	
OV_CTR EQU 40h ; contador de overflow do timer 2	
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
	
ORG 202Bh
	JMP ISR_TIMER2

		
ORG 2100h
	
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
	MOV REF_PICO, #09Ah
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
	CLR CALCULADO
	
;ganho inicial
	CALL ATUALIZA_POT
	
;iniciliza timer
;	MOV TMOD, #00000001b ;timer 0 - modo 1
;	
;	;timer 0
;	MOV TL0, #low(TIMER_MAX - TMR0_TEMP)
;	MOV TH0, #high(TIMER_MAX - TMR0_TEMP)
;	
;	SETB ET0

	MOV T2CON, #80h
	MOV RCAP2L, #low(32768)
	MOV RCAP2H, #high(32768)
	MOV TL2, #low(32768)
	MOV TH2, #high(32768)
	
	SETB ET2
	
; liga interrupções
	SETB EA

; inicializa LCD
	CALL INIDISP
	
	MOV DPTR, #FREQ_STR
	CALL ESC_STR1
	
LOOP:
	;MOV R0, #00
	;MOV R1, #00
	;CALL GOTOXY

	;MOV A, CTR_PICOS
	;CALL ATUALIZA_DISPLAY
	
	MOV BUF_SINAL_1, BUF_SINAL_0 ; avança posição da amostra no buffer
	
	MOV A, #00h
	CALL CONVADC		; lê amostra do sinal
	MOV BUF_SINAL_0, A
	
	CALL DETECT_PICO	; verifica pico
	
	;atualiza segunda linha do display com o status
	JB TEM_DEDO, STR_1
	
	MOV DPTR, #TEM_DEDO_STR
	CALL ESC_STR2
	JMP STR_FIM

STR_1:
	JB ESTAVEL, STR_2
	
	MOV DPTR, #LOAD_STR
	CALL ESC_STR2
	JMP STR_FIM
	
STR_2:
	JB CALCULADO, STR_3
	
	MOV DPTR, #CALC_STR
	CALL ESC_STR2
	JMP STR_FIM
	
STR_3:
	
	MOV DPTR, #PRONTO_STR
	CALL ESC_STR2
	
STR_FIM:	
	JNB NOVA_FREQ, NAO_CALCULA
	
	;escreve frequencia na tela
	MOV R0, #00
	MOV R1, #06
	CALL GOTOXY
	
	MOV A, FREQ_CARD
	CALL ATUALIZA_DISPLAY
	CLR NOVA_FREQ
	
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
FREQ_STR: 	  DB 'FREQ: --- BPM ',0h
LOAD_STR: 	  DB 'CARREGANDO    ', 0h
TEM_DEDO_STR: DB 'COLOQUE O DEDO', 0h	
CALC_STR:	  DB 'CALCULANDO    ', 0h
PRONTO_STR:	  DB '              ', 0h

	
; ISR TIMER 0
;************************************************************************
ISR_TIMER0:
	; conta 10s para calculo da frequência cardiaca
;	MOV TL0, #low(TIMER_MAX - TMR0_TEMP)
;	MOV TH0, #high(TIMER_MAX - TMR0_TEMP)
;	
;	MOV R3, TMR0_CTR_SEG	
;	DJNZ R3, FIM_ISR_TMR0
;		
;	MOV NUM_PICOS_ANT, CTR_PICOS
;	MOV CTR_PICOS, #00h
;	
;	JNB TR0_INT, NAO_DEU_O_TEMPO
;	
;	SETB NOVA_FREQ
;	
;NAO_DEU_O_TEMPO:
;	CPL TR0_INT
;	MOV R3, #200
;	
;FIM_ISR_TMR0:
;	MOV TMR0_CTR_SEG, R3
	RETI
;************************************************************************

; ISR TIMER 1
;************************************************************************
ISR_TIMER1:
	
	RETI
;************************************************************************

; ISR INTERFACE SERIAL
;************************************************************************
;ISR_SERIAL:
;	
;	NOP
;	
;	RETI
;************************************************************************

ISR_TIMER2:
	CLR TF2
	INC OV_CTR
	RETI
END