PUBLIC DETECT_PICO
EXTRN CODE(ATRASO_MS)
EXTRN CODE(ATUALIZA_POT)
EXTRN CODE(D16BY8)

;***************************************************************************
;EQUATES
;***************************************************************************

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
NOVA_FREQ EQU 02h ;requisi��o de c�lculo da frequ�ncia cardiaca
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

OV_CTR EQU 40h ; contador de overflow do timer 2

ADC1 EQU 51h ;valor da curva de SpO2

VALOR_POT EQU 60h ;valor de 0 a 125
	
QUOTIENTL	EQU 70h
QUOTIENTH	EQU 71h
DIVIDENDL	EQU 72h
DIVIDENDH	EQU 73h
DIVISOR		EQU 74h
REMAINDER	EQU 75h
	
;CONSTANTES
FREQ_DIV EQU 10200 ;dividendo do calculo da frequencia

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
;	- se BUF_SINAL_1 > BUF_SINAL_0 => estado = 02h
;	- se BUF_SINAL_1 <= BUF_SINAL_0 => estado = 04h	
;----------------------------------------------------------------------------
DETECT_PICO:
	MOV R7, ESTADO
	
	;leds para debug
	SETB LEDVD
	SETB LEDAM
	SETB LEDVM

;ESTADO 0 
EST_0:
	CJNE R7, #00h, EST_1
	
	; verifica se tem dedo no sensor
	JNB TEM_DEDO, ATALHO_FIM
	MOV ESTADO, #01h ; tem dedo! vai para estado 1
	
	JMP ATALHO_FIM

;ESTADO 1 
EST_1:
	CJNE R7, #01h, EST_2
	
	; verifica se tem dedo no sensor
	JNB TEM_DEDO, ATALHO_TIROU_DEDO
	
	;n�o tirou o dedo - verifica se est�vel
	JB ESTAVEL, ESTABILIZOU
	
	; n�o est�vel - espera tepo de estabiliza��o
	MOV R1, #50		; delay de 50x50ms = 2,5s
DELAY_EST:
	MOV R2, #50
	CALL ATRASO_MS
	DJNZ R1, DELAY_EST
	SETB ESTAVEL

	; est�vel - vai para estado 2
ESTABILIZOU:
	MOV ESTADO, #02h
	
	JMP ATALHO_FIM

;ESTADO 2 
EST_2:
	CJNE R7, #02h, EST_3

	; verifica se tem dedo no sensor
	JNB TEM_DEDO, ATALHO_TIROU_DEDO
	
	CLR LEDAM
	
	; verifica se buffer 1 maior que buffer 0
	MOV B, BUF_SINAL_1
	MOV A, BUF_SINAL_0
	CALL MAIOR_QUE
	
	; verifica se buffer 1 igual a buffer 0
	JNZ N_IGUAL
	SETB C  ; se for igual, queremos que o comportamento seja o mesmo de
			; se estivesse subindo
	
	; n�o � igual
N_IGUAL:
	; se for maior, sai da fun��o - estado inalterado
	JC ATALHO_FIM
	
	; se for menor, pico!
	MOV ESTADO, #03h
	MOV BUF_PICO, BUF_SINAL_0
SOBE:	
	JMP FIM_DETECT_PICO


;atalhos para fim da rotina
ATALHO_FIM:
	JMP FIM_DETECT_PICO
ATALHO_TIROU_DEDO:
	JMP TIROU_DEDO


;ESTADO 3
EST_3:
	CJNE R7, #03h, ATALHO_EST4
	
	; verifica se tem dedo no sensor
	JNB TEM_DEDO, ATALHO_TIROU_DEDO
	
	; verifica se pico maior que o pico maximo
	MOV B, BUF_PICO
	MOV A, PICO_MAX
	CALL MAIOR_QUE
	
	; verifica se pico = max
	JNZ N_IGUAL_1
	CLR C	; se for igual, queremos que o comportamento seja o mesmo de
			; se fosse menor
	
N_IGUAL_1:
	; se for menor, pula atualiza��o de pico maximo
	JNC COMP_REF
	
	; se for maior, atualiza pico maximo
	MOV PICO_MAX, BUF_PICO

COMP_REF:
	; verifica se pico maior que a refer�ncia
	MOV B, BUF_PICO
	MOV A, REF_PICO
	CALL MAIOR_QUE
	
	; verifica se pico = ref
	JNZ N_IGUAL_2
	SETB C	; se for igual, queremos que o comportamento seja o mesmo de
			; se fosse maior
	
N_IGUAL_2:
	MOV ESTADO, #04h
	
	JNC NAO_PICO
	JMP PULA_ATALHO

ATALHO_EST4:
	JMP EST_4

PULA_ATALHO:
	
	; se for maior, � pico
	CLR LEDVD
	
	;verifica se � o primeiro pico, e o ignora
	JNB PRIMEIRO_PICO, PROX_PICOS
	
	CLR TR2
	
	CLR MORTO
	
	MOV OV_CTR, #00h
	MOV TL2, RCAP2L
	MOV TH2, RCAP2H
	
	SETB TR2
	
	CLR PRIMEIRO_PICO
	SETB TR2
	JMP GANHO
	
PROX_PICOS:
	INC CTR_PICOS
	SETB NOVO_PICO
	
	; manipula timer 2
	CLR TR2
	
	CLR MORTO
	MOV DIVISOR, OV_CTR
	
	MOV OV_CTR, #00h
	MOV TL2, RCAP2L
	MOV TH2, RCAP2H
	
	SETB TR2
	
	; calcula frequ�ncia
	MOV DIVIDENDL, #low(FREQ_DIV)
	MOV DIVIDENDH, #high(FREQ_DIV)
	
	CALL D16BY8
	
	MOV FREQ_CARD, QUOTIENTL
	SETB NOVA_FREQ
	SETB CALCULADO

GANHO:
	;----teste---------------------------------------------	
	; atualiza ganho
	MOV B, BUF_PICO
	MOV A, #200
	CALL MAIOR_QUE
	
	; verifica se pico max = desejado
	JNZ N_IGUAL_max
	JMP BUZZER
	
N_IGUAL_max:
	JNC SOBE_GANHO
	DEC VALOR_POT
	JMP AT_POT
SOBE_GANHO:
	INC VALOR_POT
AT_POT:	
	CALL ATUALIZA_POT	
;--------------------------------------------------------		
	
BUZZER:
	MOV R2, #25
	SETB BUZZ
	CALL ATRASO_MS
	CLR BUZZ
	
	; delay para impedir picos duplicados
	MOV R2, #200
	CALL ATRASO_MS
	
	MOV R2, #200
	CALL ATRASO_MS
	
	JMP FIM_DETECT_PICO

NAO_PICO:
	; se for menor, n�o � pico
	CLR LEDVM
	JMP FIM_DETECT_PICO

;ESTADO 4
EST_4:
	CJNE R7, #04h, FIM_DETECT_PICO
	
	CLR LEDAM
	
	; verifica se tem dedo no sensor
	JNB TEM_DEDO, TIROU_DEDO

	; verifica se buffer 0 maior que buffer 1
	MOV B, BUF_SINAL_0
	MOV A, BUF_SINAL_1
	CALL MAIOR_QUE
	
	; verifica se buffer 0 igual a buffer 1
	JNZ N_IGUAL_3
	CLR C  ; se for igual, queremos que o comportamento seja o mesmo de
			; se estivesse descendo
	
	; n�o � igual
N_IGUAL_3:
	; se for maior, sai da fun��o - estado inalterado
	JC FIM_DETECT_PICO
	
	; se for menor, sobe!
	MOV ESTADO, #02h
	
	JMP FIM_DETECT_PICO

;usu�rio tirou o dedo!
TIROU_DEDO:
;RESET DA MAQUINA
	MOV ESTADO, #00h
	
	CLR ESTAVEL
	CLR CALCULADO
	SETB NOVA_FREQ
	SETB PRIMEIRO_PICO
	
	MOV BUF_SINAL_0, #00h
	MOV BUF_SINAL_1, #00h
	MOV PICO_MAX, #8Fh
	MOV CTR_PICOS, #00h
	MOV VALOR_POT, #30h
	MOV FREQ_CARD, #00h
	
	CALL ATUALIZA_POT
	
	CLR TR2
	
	MOV OV_CTR, #00h
	MOV TL2, RCAP2L
	MOV TH2, RCAP2H
		
FIM_DETECT_PICO:	
	RET
	
;****************************************************************************
;NOME: MAIOR_QUE
;DESCRICAO: ROTINA DE COMPARA��O
;ENTRADA: A, B
;SAIDA: C (1, se A<B / 0, se A>B  / se A=B, C n tem signficado), A (00h, se A=B)
;DESTROI: A, B, C
;****************************************************************************
MAIOR_QUE:
	CJNE A, B, NOT_IGUAL
	MOV A, #00h
	RET
NOT_IGUAL:
	MOV A, #01h
	RET
END