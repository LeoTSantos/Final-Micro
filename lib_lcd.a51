PUBLIC INIDISP,ESCINST,GOTOXY,CLR2L,ESCDADO,MSTRING,MSTRINGX,ESC_STR1,ESC_STR2,CUR_ON,CUR_OFF,Atraso,ATRASO_MS

;***************************************************************************
;EQUATES
;***************************************************************************

RS		EQU	P2.5		;COMANDO RS LCD
E_LCD	EQU	P2.7		;COMANDO E (ENABLE) LCD
RW		EQU	P2.6		;READ/WRITE
BUSYF	EQU	P0.7		;BUSY FLAG


;***************************************************************************
;ROTINAS DE TRATAMENTO DO DISPLAY DE CRISTAL LIQUIDO 16X2
;***************************************************************************
PROG SEGMENT CODE
	RSEG PROG
;***************************************************************************
;NOME: INIDISP
;DESCRICAO: ROTINA DE INICIALIZACAO DO DISPLAY LCD 2x16
;		PROGRAMA CARACTER 5x7, LIMPA DISPLAY E POSICIONA (0,0)
;ENTRADA: -
;SAIDA: -
;DESTROI: R0,R2

INIDISP:                       
        MOV     R0,#38H         ;UTILIZACAO: 8 BITS, 2 LINHAS, 5x7
        MOV     R2,#05          ;ESPERA 5ms
        CALL    ESCINST         ;ENVIA A INSTRUCAO
        MOV     R0,#38H         ;UTILIZACAO: 8 BITS, 2 LINHAS, 5x7
        MOV     R2,#01          ;ESPERA 1ms
        CALL    ESCINST         ;ENVIA A INSTRUCAO
        MOV     R0,#06H         ;INSTRUCAO DE MODO DE OPERACAO
        MOV     R2,#01          ;ESPERA 1ms
        CALL    ESCINST         ;ENVIA A INSTRUCAO
        MOV     R0,#0CH         ;INSTRUCAO DE CONTROLE ATIVO/INATIVO
        MOV     R2,#01          ;ESPERA 1ms
        CALL    ESCINST         ;ENVIA A INSTRUCAO
        MOV     R0,#01H         ;INSTRUCAO DE LIMPEZA DO DISPLAY
        MOV     R2,#02          ;ESPERA 2ms
        CALL    ESCINST         ;ENVIA A INSTRUCAO
        RET

;***************************************************************************
;NOME: ESCINST
;DESCRICAO: ROTINA QUE ESCREVE INSTRUCAO PARA O DISPLAY E ESPERA DESOCUPAR
;P.ENTRADA: R0 = INSTRUCAO A SER ESCRITA NO MODULO DISPLAY
;           R2 = TEMPO DE ESPERA EM ms
;P.SAIDA: -
;DESTROI: R0,R2

ESCINST:  
	CLR	RW		;MODO ESCRITA NO LCD
        CLR     RS              ;RS  = 0 (SELECIONA REG. DE INSTRUCOES)
        SETB    E_LCD           ;E = 1 (HABILITA LCD)
        MOV     P0,R0           ;INSTRUCAO A SER ESCRITA
        CLR     E_LCD           ;E = 0 (DESABILITA LCD)
	MOV	P0,#0xFF	;PORTA 0 COMO ENTRADA
	SETB	RW		;MODO LEITURA NO LCD	
	SETB    E_LCD           ;E = 1 (HABILITA LCD)	
ESCI1:	JB	BUSYF,ESCI1	;ESPERA BUSY FLAG = 0
	CLR     E_LCD           ;E = 0 (DESABILITA LCD)
        RET

;***************************************************************************
;NOME: GOTOXY
;DESCRICAO: ROTINA QUE POSICIONA O CURSOR
;P.ENTRADA: R0 = LINHA (0 A 1)
;           R1 = COLUNA (0 A 15)
;P.SAIDA: -
;DESTROI: R0,R2
GOTOXY: PUSH    ACC
        MOV     A,#80H
        CJNE    R0,#01,GT1      ;SALTA SE COLUNA 0
        MOV     A,#0C0H
GT1:    ORL     A,R1            ;CALCULA O ENDERECO DA MEMORIA DD RAM
        MOV     R0,A
        MOV     R2,#01          ;ESPERA 1ms               
        CALL    ESCINST         ;ENVIA PARA O MODULO DISPLAY
        POP     ACC
        RET
            	

;***************************************************************************
;NOME: CLR2L
;DESCRICAO: ROTINA QUE APAGA SEGUNDA LINHA DO DISPLAY LCD E POSICIONA NO INICIO
;ENTRADA: -
;SAIDA: -
;DESTROI: R0,R1
CLR2L:    
        PUSH   ACC
        MOV    R0,#01              ;LINHA
        MOV    R1,#00
        CALL   GOTOXY
        MOV    R1,#16              ;CONTADOR
CLR2L1: MOV    A,#' '              ;ESPACO
        CALL   ESCDADO
        DJNZ   R1,CLR2L1
        MOV    R0,#01              ;LINHA
        MOV    R1,#00
        CALL   GOTOXY
        POP    ACC
        RET
           
;***************************************************************************
;NOME: ESCDADO
;DESCRICAO: ROTINA QUE ESCREVE DADO PARA O DISPLAY
;ENTRADA: A = DADO A SER ESCRITA NO MODULO DISPLAY
;SAIDA: -
;DESTROI: R0           
ESCDADO:  
	CLR	RW		;MODO ESCRITA NO LCD
        SETB	RS              ;RS  = 1 (SELECIONA REG. DE DADOS)
        SETB  	E_LCD           ;LCD = 1 (HABILITA LCD)
        MOV   	P0,A            ;ESCREVE NO BUS DE DADOS
        CLR   	E_LCD           ;LCD = 0 (DESABILITA LCD)
	MOV	P0,#0xFF	;PORTA 0 COMO ENTRADA
	SETB	RW		;MODO LEITURA NO LCD
	CLR	RS		;RS = 0 (SELECIONA INSTRUÇÃO)	
	SETB    E_LCD           ;E = 1 (HABILITA LCD)
ESCD1:	JB	BUSYF,ESCD1	;ESPERA BUSY FLAG = 0
	CLR     E_LCD           ;E = 0 (DESABILITA LCD)
;        MOV     R0,#14          ;40uS
;        CALL    ATRASO
        RET

;*****************************************************************************
;NOME: MSTRING
;ROTINA QUE ESCREVE UMA STRING DA ROM NO DISPLAY A PARTIR DA POSICAO DO CURSOR
;ENTRADA: DPTR = ENDERECO INICIAL DA STRING NA MEMORIA ROM FINALIZADA POR 00H
;SAIDA: -
;DESTROI: A,DPTR,R0
MSTRING:  CLR    A
          MOVC   A,@A+DPTR      ;CARACTER DA MENSAGEM EM A
          JZ     MSTR1
          LCALL  ESCDADO        ;ESCREVE O DADO NO DISPLAY
          INC    DPTR
          SJMP   MSTRING
MSTR1:    RET
           
;*****************************************************************************
;NOME: MSTRINGX
;ROTINA QUE ESCREVE UMA STRING DA RAM NO DISPLAY A PARTIR DA POSICAO DO CURSOR
;ENTRADA: DPTR = ENDERECO INICIAL DA STRING NA MEMORIA RAM FINALIZADA POR 00H
;SAIDA: -
;DESTROI: A,DPTR,R0
MSTRINGX: MOVX   A,@DPTR        ;CARACTER DA MENSAGEM EM A
          JZ     MSTR21
          LCALL  ESCDADO        ;ESCREVE O DADO NO DISPLAY
          INC    DPTR
          SJMP   MSTRINGX
MSTR21:   RET
           
;*****************************************************************************
;NOME: ESC_STR1
;ROTINA QUE ESCREVE UMA STRING NO DISPLAY A PARTIR DO INICIO DA PRIMEIRA LINHA
;ENTRADA: DPTR = ENDERECO INICIAL DA STRING NA MEMORIA ROM FINALIZADA POR 00H
;SAIDA: -
;DESTROI: R0,A,DPTR
ESC_STR1: MOV    R0,#00         ;PRIMEIRA LINHA E PRIMEIRA COLUNA
          MOV    R1,#00
          JMP    ESC_S
          
;*****************************************************************************
;NOME: ESC_STR2
;ROTINA QUE ESCREVE UMA STRING NO DISPLAY A PARTIR DO INICIO DA SEGUNDA LINHA
;ENTRADA: DPTR = ENDERECO INICIAL DA STRING NA MEMORIA ROM FINALIZADA POR 00H
;SAIDA: -
;DESTROI: R0,A,DPTR
ESC_STR2: MOV    R0,#01         ;SEGUNDA LINHA E PRIMEIRA COLUNA
          MOV    R1,#00
ESC_S:    LCALL  GOTOXY         ;POSICIONA O CURSOR
          LCALL  MSTRING
          RET


;******************************************************************************
; NOME: CUR_ON E CUR_OFF
; FUNCAO: ROTINA CUR_ON => LIGA CURSOR DO LCD
;         ROTINA CUR_OFF => DESLIGA CURSOR DO LCD
; CHAMA: ESCINST
; ENTRADA: -
; SAIDA: -
; DESTROI: R0,R2
;******************************************************************************

CUR_ON:   MOV    R0,#0FH              ;INST.CONTROLE ATIVO (CUR ON)
          SJMP   CUR1
CUR_OFF:  MOV    R0,#0CH              ;INST. CONTROLE INATIVO (CUR OFF)
CUR1:     MOV    R2,#01
	  CALL   ESCINST              ;ENVIA A INSTRUCAO
          RET

;***************************************************************************
;NOME: Atraso
;DESCRIÇÃO: Introduz um atraso (delay) de T = (60 x R0 + 48)/fosc
;Para fosc =24MHz => R0=1 => T=4,5us a R0=0 => 0,642ms se R0= 199 => 0,5ms
;P. ENTRADA: R0 = Valor que multiplica por 60 na fórmula (OBS.: R0 = 0 => 256)
;P. SAIDA: -
;Altera: R0
;***************************************************************************
Atraso:
	NOP			;12
	NOP			;12
	NOP			;12
	DJNZ	R0,Atraso	;24
	RET			;24


;***************************************************************************
;NOME: ATRASO_MS
;DESCRICAO: INTRODUZ UM ATRASO DE 1ms A 256ms
;P.ENTRADA: R2 = 1 => 1ms  A R2 = 0 => 256ms
;P.SAIDA: -
;ALTERA: R0,R2
ATRASO_MS:
	MOV	R0,#199		;VALOR PARA ATRASO DE 0,5ms
	CALL	Atraso
	MOV	R0,#199		;VALOR PARA ATRASO DE 0,5ms
	CALL	Atraso
	DJNZ	R2,ATRASO_MS
	RET		

	END	