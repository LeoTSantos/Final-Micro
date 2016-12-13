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
ESTAVEL EQU 00h ;bit-endereçável - sistema está estável?
NOVO_PICO EQU 01h ;bit-endereçável - tem novo pico?

;VARIAVEIS - BYTES
PICO_MAX EQU 30h ;valor maximo de pico do sinal
CTR_PICOS EQU 31h ;numero de picos
BUF_SINAL_0 EQU 34h ;posição 0 do buffer do sinal
BUF_SINAL_1 EQU 35h ;posição 1 do buffer do sinal
BUF_PICO EQU 36h ; buffer para salvar supostos picos
REF_PICO EQU 37h ; valor de referência dos picos (minimo para considerar um pico)
ESTADO EQU 38h ;para maquina de estados da detecção de picos

ADC1 EQU 51h ;valor da curva de SpO2

VALOR_POT EQU 60h ;valor de 0 a 125

;***************************************************************************
;ROTINA DE DETECÇÃO DE PICO
;***************************************************************************

PROG SEGMENT CODE
	RSEG PROG
		
;***************************************************************************
;NOME: DETECT_PICO
;DESCRICAO: ROTINA DE DETECÇÃO DE PICO
;ENTRADA: TEM_DEDO, ESTAVEL, BUF_SINAL_0, BUF_SINAL_1, REF_PICO
;SAIDA: PICO_MAX, CTR_PICOS
;DESTROI: A, C, R7
;****************************************************************************

;****************************************************************************
; MAQUINA DE ESTADOS
;----------------------------------------------------------------------------
; ESTADO = 00h - IDLE
;	- não tem dedo no sensor => TEM_DEDO == 0
;	- se  TEM_DEDO == 0 => estado = 00h
;	- se TEM_DEDO == 1 => estado = 01h
; ESTADO = 01h - NÃO ESTÁVEL
;	- o sinal ainda não estabilizou => ESTAVEL == 0
;	- se TEM_DEDO == 0 => estado = 00h
;   - se TEM_DEDO == 1 e ESTAVEL == 0 => estado == 01h
;	- se TEM_DEDO == 1 e ESTAVEL == 1 => estado == 02h
; ESTADO = 02h - subindo => BUF_SINAL_1 >= BUF_SINAL_0
;	- se TEM_DEDO == 0 => estado = 00h
;	- se BUF_SINAL_1 >= BUF_SINAL_0 => estado = 02h
;	- se BUF_SINAL_1 < BUF_SINAL_0 => estado = 03h, BUF_PICO = BUF_SINAL_0
; ESTADO = 03h - verifica pico => BUF_SINAL_1 < BUF_SINAL_0
;	- se TEM_DEDO == 0 => estado = 00h
;	- se BUF_PICO >= REF_PICO => estado = 04h, atualiza PICO_MAX, CTR_PICOS++
;	- se BUF_PICO < REF_PICO => estado = 04h, atualiza PICO_MAX (para controle de ganho)
; ESTADO = 04h - descendo => BUF_SINAL_1 >= BUF_SINAL_0
;	- se TEM_DEDO == 0 => estado = 00h
;	- se BUF_SINAL_1 >= BUF_SINAL_0 => estado = 02h
;	- se BUF_SINAL_1 < BUF_SINAL_0 => estado = 04h
;****************************************************************************
DETECT_PICO:
	MOV R7, ESTADO
EST_0:
	CJNE R7, #00h, EST_1
	SETB LEDVD
	SETB LEDAM
	SETB LEDVM
	JNB TEM_DEDO, ATALHO_TIROU_DEDO
	INC ESTADO
	
	JMP FIM_DETECT_PICO


EST_1:
	CJNE R7, #01h, EST_2
	CLR LEDVD
	SETB LEDAM
	SETB LEDVM
	JNB TEM_DEDO, ATALHO_TIROU_DEDO
	JB ESTAVEL, ESTABILIZOU
	
	MOV R1, #4
DELAY_EST:
	MOV R2, #50
	CALL ATRASO_MS
	DJNZ R1, DELAY_EST
	SETB ESTAVEL

ESTABILIZOU:
	INC ESTADO
	
	SJMP ATALHO_FIM

EST_2:
	CJNE R7, #02h, EST_3
	SETB LEDVD
	CLR LEDAM
	SETB LEDVM
	JNB TEM_DEDO, TIROU_DEDO
	
	CLR C
	MOV A, BUF_SINAL_0
	
	CJNE A, BUF_SINAL_1, CONTINUA
	CLR C
CONTINUA:
	JNC FIM_DETECT_PICO
	INC ESTADO
	MOV BUF_PICO, BUF_SINAL_0
	
	SJMP FIM_DETECT_PICO
	
ATALHO_TIROU_DEDO:
	SJMP TIROU_DEDO
	
ATALHO_FIM:
	SJMP FIM_DETECT_PICO
	
EST_3:
	CJNE R7, #03h, EST_4
	CLR LEDVM
	SETB LEDAM
	SETB LEDVD
	JNB TEM_DEDO, TIROU_DEDO
	
	MOV A, BUF_PICO
	
	CJNE A, REF_PICO, CONTINUA_1
	CLR C
CONTINUA_1:
	JC NAO_E_PICO
	INC CTR_PICOS
	SETB NOVO_PICO
	
	MOV R2, #25
	SETB BUZZ
	CALL ATRASO_MS
	CLR BUZZ
	
NAO_E_PICO:
	MOV ESTADO, #04h
	
	MOV A, PICO_MAX
	
	CJNE A, BUF_PICO, CONTINUA_2
	CLR C
CONTINUA_2:
	JNC FIM_DETECT_PICO
	MOV PICO_MAX, BUF_PICO
	
	CLR C
	MOV A, PICO_MAX
	SUBB A, #20
	MOV REF_PICO, A
	
	SJMP FIM_DETECT_PICO

EST_4:
	CJNE R7, #04h, FIM_DETECT_PICO
	CLR LEDVM
	SETB LEDVD
	CLR LEDAM
	JNB TEM_DEDO, TIROU_DEDO
	
	MOV A, BUF_SINAL_0
	
	CJNE A, BUF_SINAL_1, CONTINUA_3
	SETB C
CONTINUA_3:
	JC FIM_DETECT_PICO
	MOV ESTADO, #02h
	
	SJMP FIM_DETECT_PICO

TIROU_DEDO:
	MOV ESTADO, #00h
	
	CLR ESTAVEL
	MOV BUF_SINAL_0, #00h
	MOV BUF_SINAL_1, #00h
	MOV PICO_MAX, #38h
	MOV CTR_PICOS, #00h
	MOV VALOR_POT, #0Fh

FIM_DETECT_PICO:
	RET
	
END