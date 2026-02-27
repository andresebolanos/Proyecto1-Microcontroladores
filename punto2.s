;=========================================================
; Código en Assembler para PIC18F4550
; LED en RB0
; Añadidos retardos de 1s y 2s mediante contador de desbordes
;=========================================================

#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS
    CONFIG  WDT = OFF
    CONFIG  LVP = OFF
    CONFIG  PBADEN = OFF

    #define TMR1_HIGH  0b00001011
    #define TMR1_LOW   0b11011100

;=========================================================
; Vector de Reset
;=========================================================
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

;=========================================================
; Código principal
;=========================================================
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0b01110000
    MOVWF   OSCCON
    NOP
    NOP

    CLRF    TRISB
    CLRF    LATB

    MOVLW   0b10110000
    MOVWF   T1CON
    BCF     T1CON, 0

BuclePrincipal:
    BSF     LATB, 0
    CALL    Retardo_1s          ; Ahora 1 segundo
    BCF     LATB, 0
    CALL    Retardo_1s
    GOTO    BuclePrincipal

;=========================================================
; Subrutinas de retardo
;=========================================================
Retardo_1s:
    MOVLW   4                   ; 4 desbordes de 250ms = 1s
    MOVWF   ContadorDesbordes
    BRA     IniciarTimer

Retardo_2s:
    MOVLW   8                   ; 8 desbordes = 2s
    MOVWF   ContadorDesbordes

IniciarTimer:
    BCF     T1CON, 0            ; Apagar timer
    MOVLW   TMR1_HIGH
    MOVWF   TMR1H
    MOVLW   TMR1_LOW
    MOVWF   TMR1L
    BCF     PIR1, 0
    BSF     T1CON, 0

EsperarDesborde:
    BTFSS   PIR1, 0
    GOTO    EsperarDesborde

    DECFSZ  ContadorDesbordes, F
    GOTO    IniciarTimer

    BCF     T1CON, 0
    RETURN

;=========================================================
; Variables en RAM
;=========================================================
    PSECT udata
ContadorDesbordes:  DS 1

    END