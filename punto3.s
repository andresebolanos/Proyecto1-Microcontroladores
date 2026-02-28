;=========================================================
; Configuración básica del PIC18F4550
; - Oscilador interno 8MHz
; - RD0-3 como salidas (LEDs)
; - RB0, RB1 como entradas (pulsadores)
; - Bucle principal vacío
;=========================================================
#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS    ; Oscilador interno, high speed
    CONFIG  WDT  = OFF           ; Watchdog desactivado
    CONFIG  LVP  = OFF           ; Programación de bajo voltaje OFF
    CONFIG  PBADEN = OFF         ; PORTB digital al inicio

;=========================================================
; VECTOR DE RESET
;=========================================================
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

;=========================================================
; CÓDIGO PRINCIPAL
;=========================================================
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    ; Configurar oscilador a 8 MHz
    MOVLW   0b01110000          ; IRCF = 111 (8 MHz)
    MOVWF   OSCCON
    NOP
    NOP

    ; Configurar puertos
    CLRF    TRISD               ; RD0-3 como salidas
    CLRF    LATD                ; Apagar LEDs inicialmente
    BSF     TRISB, 0            ; RB0 como entrada
    BSF     TRISB, 1            ; RB1 como entrada

    ; Deshabilitar ADC para que RB sea digital
    MOVLW   0x0F
    MOVWF   ADCON1

    ; Bucle infinito (por ahora no hace nada)
BuclePrincipal:
    GOTO    BuclePrincipal

    END