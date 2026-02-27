;=========================================================
; Código en Assembler para PIC18F4550
; LED en RB0
; Fase 1: 5 parpadeos de 1s (ON 1s, OFF 1s)
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
    ; Fase 1: 5 parpadeos de 1s
    MOVLW   5
    MOVWF   NumBlinks

Ciclo5Blinks:
    BSF     LATB, 0
    CALL    Retardo_1s
    BCF     LATB, 0
    CALL    Retardo_1s
    DECFSZ  NumBlinks, F
    GOTO    Ciclo5Blinks

    ; Por ahora, al terminar se queda en un bucle infinito (para prueba)
    ; Más adelante agregaremos la segunda fase
    GOTO    $

;=========================================================
; Subrutinas de retardo (igual que antes)
;=========================================================
Retardo_1s:
    MOVLW   4
    MOVWF   ContadorDesbordes
    BRA     IniciarTimer

Retardo_2s:
    MOVLW   8
    MOVWF   ContadorDesbordes

IniciarTimer:
    BCF     T1CON, 0
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
NumBlinks:          DS 1
ContadorDesbordes:  DS 1

    END