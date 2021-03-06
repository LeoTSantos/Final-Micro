;--------------------------------------------------------------------------------------------
; ROTINAS EXTERNAS
;--------------------------------------------------------------------------------------------
EXTRN CODE(INIDISP,ESCINST,GOTOXY,CLR2L,ESCDADO,MSTRING,MSTRINGX,ESC_STR1,ESC_STR2,CUR_ON,CUR_OFF,Atraso,ATRASO_MS,ATUALIZA_DISPLAY)
EXTRN CODE(DETECT_PICO)
EXTRN CODE(CONVADC)
EXTRN CODE(ATUALIZA_POT)
;--------------------------------------------------------------------------------------------
; TABELA DE EQUATES - 30h a 4Fh
;--------------------------------------------------------------------------------------------
;REGISTRADORES DE FUN��O ESPECIAL
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
ESTAVEL EQU 00h ;bit-endere��vel - sistema est� est�vel?
NOVO_PICO EQU 01h ;bit-endere��vel - tem novo pico?
NOVA_FREQ EQU 02h ;requisi��o de c�lculo da frequ�ncia cardiaca
TR0_INT EQU 03h ;interrup��o de timer 0 acontece vez sim, vez n�o
CALCULADO EQU 04h ;calculo da frequ�ncia realizado
MORTO EQU 05h ;verifica se paciente morreu
PRIMEIRO_PICO EQU 06h ;bit para identificar o primeiro pico
	
;VARIAVEIS - BYTES
PICO_MAX EQU 30h ;valor maximo de pico do sinal
CTR_PICOS EQU 31h ;numero de picos
FREQ_CARD EQU 33h ;frequ�ncia cardiaca
BUF_SINAL_0 EQU 34h ;posi��o 0 do buffer do sinal
BUF_SINAL_1 EQU 35h ;posi��o 1 do buffer do sinal
BUF_PICO EQU 36h ; buffer para salvar supostos picos
REF_PICO EQU 37h ; valor de refer�ncia dos picos (minimo para considerar um pico)
ESTADO EQU 38h ;para maquina de estados da detec��o de picos
CTR_RESET_MAX EQU 39h ;contador para reset do pico maximo
	
OV_CTR EQU 40h ; contador de overflow do timer 2	

ADC1 EQU 51h ;valor da curva de SpO2

;vari�vel do pot digital
VALOR_POT EQU 60h ;valor de 0 a 125
GANHO_ANT EQU 61h ;ganho da itera��o anterior

;Para opera��es de divis�o
QUOTIENTL	EQU 70h
QUOTIENTH	EQU 71h
DIVIDENDL	EQU 72h
DIVIDENDH	EQU 73h
DIVISOR		EQU 74h
REMAINDER	EQU 75h
	
;CONSTANTES 
TIMER_MAX EQU 65536
TMR2_TEMP EQU 11764 

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
;inciliza vari�veis
	MOV PICO_MAX, #8Fh 
	MOV CTR_PICOS, #00h
	MOV FREQ_CARD, #00h
	MOV BUF_SINAL_0, #00h
	MOV BUF_SINAL_1, #00h
	MOV BUF_PICO, #00h
	MOV REF_PICO, #0BCh
	MOV VALOR_POT, #38h
	MOV GANHO_ANT, #00h
	MOV ESTADO, #00h
	CLR TR0_INT
	SETB SS
	SETB SS_POT
	SETB PRIMEIRO_PICO
	CLR BUZZ
	CLR ESTAVEL
	CLR NOVA_FREQ
	CLR NOVO_PICO
	CLR CALCULADO
	CLR MORTO
	
;ganho inicial
	CALL ATUALIZA_POT
	
;iniciliza timer

	MOV T2CON, #80h
	MOV RCAP2L, #low(TIMER_MAX - TMR2_TEMP)
	MOV RCAP2H, #high(TIMER_MAX - TMR2_TEMP)
	MOV TL2, #low(TIMER_MAX - TMR2_TEMP)
	MOV TH2, #high(TIMER_MAX - TMR2_TEMP)
	
	SETB ET2
	
; liga interrup��es
	SETB EA

; inicializa LCD
	CALL INIDISP
	
	MOV DPTR, #FREQ_STR
	CALL ESC_STR1
	
LOOP:	
	MOV BUF_SINAL_1, BUF_SINAL_0 ; avan�a posi��o da amostra no buffer
	
	MOV A, #00h
	CALL CONVADC		; l� amostra do sinal
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
	JB MORTO, STR_MORTO
	MOV DPTR, #PRONTO_STR
	CALL ESC_STR2
	JMP STR_FIM

STR_MORTO:
	MOV DPTR, #MORTO_STR
	CALL ESC_STR2
	
	MOV FREQ_CARD, #00h
	
	MOV R0, #00
	MOV R1, #06
	CALL GOTOXY
	
	MOV A, FREQ_CARD
	CALL ATUALIZA_DISPLAY
	
	MOV OV_CTR, #00h
	MOV QUOTIENTL, #00h
	MOV TL2, RCAP2L
	MOV TH2, RCAP2H
	
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
MORTO_STR:	  DB 'BPM INVALIDO! ', 0h

	
; ISR TIMER 0
;************************************************************************
ISR_TIMER0:
	RETI
;************************************************************************

; ISR TIMER 1
;************************************************************************
ISR_TIMER1:
	RETI
;************************************************************************

ISR_TIMER2:
	CLR TF2
	INC OV_CTR
	
	; teste para ver se BPM � v�lido
	INC OV_CTR
	DJNZ OV_CTR, FIM_ISR_TMR2
	
	SETB MORTO
	
FIM_ISR_TMR2:
	RETI
END