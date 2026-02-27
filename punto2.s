;=========================================================
; Código en Assembler para PIC18F4550
; LED en RB0
; Parpadeo infinito con retardos de software (aproximados)
;=========================================================

#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS    ; Usa oscilador interno
    CONFIG  WDT = OFF           ; Desactiva Watchdog Timer
    CONFIG  LVP = OFF           ; Desactiva programación en bajo voltaje
    CONFIG  PBADEN = OFF        ; PORTB inicia como digital

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
    MOVLW   0b01110000         ; 8 MHz interno
    MOVWF   OSCCON
    NOP
    NOP

    CLRF    TRISB              ; Puerto B como salida
    CLRF    LATB               ; LED apagado

BuclePrincipal:
    BSF     LATB, 0            ; LED ON
    CALL    Retardo            ; Espera
    BCF     LATB, 0            ; LED OFF
    CALL    Retardo            ; Espera
    GOTO    BuclePrincipal

;=========================================================
; Subrutina de retardo aproximado (software)
;=========================================================
Retardo:
    MOVLW   0xFF
    MOVWF   Contador1
Loop1:
    MOVLW   0xFF
    MOVWF   Contador2
Loop2:
    DECFSZ  Contador2, F
    GOTO    Loop2
    DECFSZ  Contador1, F
    GOTO    Loop1
    RETURN

;=========================================================
; Variables en RAM
;=========================================================
    PSECT udata
Contador1:  DS 1
Contador2:  DS 1

    END