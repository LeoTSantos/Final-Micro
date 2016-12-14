PUBLIC D16BY8, MUL16X8

;***************************************************************************
;EQUATES
;***************************************************************************

FREQ_CARD EQU 33h ;frequência cardiaca

QUOTIENTL	EQU 70h
QUOTIENTH	EQU 71h
DIVIDENDL	EQU 72h
DIVIDENDH	EQU 73h
DIVISOR		EQU 74h
REMAINDER	EQU 75h

;***************************************************************************
;ROTINAS DE MATEMATICA
;***************************************************************************
PROG SEGMENT CODE
	RSEG PROG

;***************************************************************************
;NOME: D16BY8
;DESCRIÇÃO:  QUOTIENT=DIVIDEND/DIVISOR, REMAINDER=DIVIDEND-QUOTIENT*DIVISOR
;P. ENTRADA: DIVIDENDL, DIVIDENDH, DIVISOR
;P. SAIDA: QUOTIENTL, QUOTIENTH, REMAINDER
;Altera: A, B, R4, R5, R6, R7, C, OV
;***************************************************************************
D16BY8:	CLR	A
	CJNE	A,DIVISOR,OK

DIVIDE_BY_ZERO:
	SETB	OV
	RET

OK:	MOV	QUOTIENTL,A
	MOV	R4,#8
	MOV	R5,DIVIDENDL
	MOV	R6,DIVIDENDH
	MOV	R7,A

	MOV	A,R6
	MOV	B,DIVISOR
	DIV	AB
	MOV	QUOTIENTH,A
	MOV	R6,B

TIMES_TWO:
	MOV	A,R5
	RLC	A
	MOV	R5,A
	MOV	A,R6
	RLC	A
	MOV	R6,A
	MOV	A,R7
	RLC	A
	MOV	R7,A

COMPARE:
	CJNE	A,#0,DONE
	MOV	A,R6
	CJNE	A,DIVISOR,DONE
	CJNE	R5,#0,DONE
DONE:	CPL	C

BUILD_QUOTIENT:
	MOV	A,QUOTIENTL
	RLC	A
	MOV	QUOTIENTL,A
	JNB	ACC.0,LOOP

SUBTRACT:
	MOV	A,R6
	SUBB	A,DIVISOR
	MOV	R6,A
	MOV	A,R7
	SUBB	A,#0
	MOV	R7,A

LOOP:	DJNZ	R4,TIMES_TWO

	MOV	A,DIVISOR
	MOV	B,QUOTIENTL
	MUL	AB
	MOV	B,A
	MOV	A,DIVIDENDL
	SUBB	A,B
	MOV	REMAINDER,A
	CLR	OV
	RET

;***************************************************************************
;NOME: MUL16X8
;DESCRIÇÃO:  MULTIPLICAÇÂO
;P. ENTRADA: (R1 R2) x (R4)
;P. SAIDA: R7, R6, R5
;Altera: 
;***************************************************************************
MUL16X8:
	MOV A, R2
	MOV B, R4
	MUL AB
	MOV R5, A
	MOV R6, B
	MOV A, R3
	MOV B, R4
	MUL AB
	ADD A, R6
	MOV R6, A
	MOV A, B
	ADDC A, #00
	MOV R7, A
	RET
	
END