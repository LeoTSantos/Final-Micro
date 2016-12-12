PUBLIC DETECT_PICO
EXTRN CODE(CONVADC)
EXTRN CODE(ATRASO_MS)

;***************************************************************************
;EQUATES
;***************************************************************************
;PORTS
TEM_DEDO EQU P1.0 ;tem dedo no sensor?
	
;Buzzer
BUZZ EQU P1.3
	
;LEDS DA PLACA
LEDVD	EQU	P3.6
LEDAM   EQU	P3.7
LEDVM	EQU	P1.4
	
;VARIAVEIS - BITS
ESTAVEL EQU 00h ;bit-endere��vel - sistema est� est�vel?
NOVO_PICO EQU 01h ;bit-endere��vel - tem novo pico?

;VARIAVEIS - BYTES
PICO_MAX EQU 30h ;valor maximo de pico do sinal
CTR_PICOS EQU 31h ;numero de picos
BUF_SINAL_0 EQU 34h ;posi��o 0 do buffer do sinal
BUF_SINAL_1 EQU 35h ;posi��o 1 do buffer do sinal
BUF_PICO EQU 36h ; buffer para salvar supostos picos
REF_PICO EQU 37h ; valor de refer�ncia dos picos (minimo para considerar um pico)
ESTADO EQU 38h ;para maquina de estados da detec��o de picos

ADC1 EQU 51h ;valor da curva de SpO2


;***************************************************************************
;ROTINA DE DETEC��O DE PICO
;***************************************************************************

PROG SEGMENT CODE
	RSEG PROG
		
;***************************************************************************
;NOME: DETECT_PICO
;DESCRICAO: ROTINA DE DETEC��O DE PICO
;ENTRADA: TEM_DEDO, ESTAVEL, BUF_SINAL_0, BUF_SINAL_1, REF_PICO
;SAIDA: PICO_MAX, CTR_PICOS
;DESTROI: A, C, R7
;****************************************************************************

;****************************************************************************
; MAQUINA DE ESTADOS
;----------------------------------------------------------------------------
; ESTADO = 00h - IDLE
;	- n�o tem dedo no sensor => TEM_DEDO == 0
;	- se  TEM_DEDO == 0 => estado = 00h
;	- se TEM_DEDO == 1 => estado = 01h
; ESTADO = 01h - N�O EST�VEL
;	- o sinal ainda n�o estabilizou => ESTAVEL == 0
;	- se TEM_DEDO == 0 => estado = 00h
;   - se TEM_DEDO == 1 e ESTAVEL == 0 => estado == 01h
;	- se TEM_DEDO == 1 e ESTAVEL == 1 => estado == 02h
; ESTADO = 02h - n�o chegou ao pico => BUF_SINAL_1 >= BUF_SINAL_0
;	- se TEM_DEDO == 0 => estado = 00h
;	- se BUF_SINAL_1 >= BUF_SINAL_0 => estado = 02h
;	- se BUF_SINAL_1 < BUF_SINAL_0 => estado = 03h, BUF_PICO = BUF_SINAL_0
; ESTADO = 03h - verifica pico => BUF_SINAL_1 < BUF_SINAL_0
;	- se TEM_DEDO == 0 => estado = 00h
;	- se BUF_PICO >= REF_PICO => estado = 02h, atualiza PICO_MAX, CTR_PICOS++
;	- se BUF_PICO < REF_PICO => estado = 02h, atualiza PICO_MAX (para controle de ganho)
;
;****************************************************************************
DETECT_PICO:
	MOV R7, ESTADO
EST_0:
	CJNE R7, #00h, EST_1
	CLR LEDVD
	SETB LEDAM
	SETB LEDVM
	JNB TEM_DEDO, TIROU_DEDO
	INC ESTADO
	
	JMP FIM_DETECT_PICO


EST_1:
	CJNE R7, #01h, EST_2
	SETB LEDVD
	CLR LEDAM
	SETB LEDVM
	JNB TEM_DEDO, TIROU_DEDO
	JB ESTAVEL, ESTABILIZOU
	
	MOV R1, #3
DELAY_EST:
	MOV R2, #50
	CALL ATRASO_MS
	DJNZ R1, DELAY_EST
	SETB ESTAVEL

ESTABILIZOU:
	INC ESTADO
	
	SJMP FIM_DETECT_PICO

EST_2:
	CJNE R7, #02h, EST_3
	SETB LEDVD
	CLR LEDVM
	SETB LEDAM
	JNB TEM_DEDO, TIROU_DEDO
	
	CLR C
	MOV A, BUF_SINAL_0
	SUBB A, BUF_SINAL_1
	
	CJNE A, #00, CONTINUA
	SETB C
CONTINUA:
	JC FIM_DETECT_PICO
	INC ESTADO
	MOV BUF_PICO, BUF_SINAL_0
	
	SJMP FIM_DETECT_PICO

EST_3:
	CJNE R7, #03h, FIM_DETECT_PICO
	SETB LEDVM
	CLR LEDAM
	CLR LEDVD
	JNB TEM_DEDO, TIROU_DEDO
	
	CLR C
	MOV A, REF_PICO
	SUBB A, BUF_PICO
	
	CJNE A, #00, CONTINUA_1
	SETB C
CONTINUA_1:
	JNC NAO_E_PICO
	INC CTR_PICOS
	
	MOV R2, #50
	SETB BUZZ
	CALL ATRASO_MS
	CLR BUZZ
	
NAO_E_PICO:
	MOV ESTADO, #02h
	
	CLR C
	MOV A, PICO_MAX
	SUBB A, BUF_PICO
	
	CJNE A, #00, CONTINUA_2
	CLR C
CONTINUA_2:
	JNC FIM_DETECT_PICO
	MOV PICO_MAX, BUF_PICO
	SETB NOVO_PICO
	
	SJMP FIM_DETECT_PICO

TIROU_DEDO:
	MOV ESTADO, #00h
	
	CLR ESTAVEL
	MOV BUF_SINAL_0, #00h
	MOV BUF_SINAL_1, #00h
	MOV PICO_MAX, #00h
	MOV CTR_PICOS, #00h

FIM_DETECT_PICO:
	RET
	
END