;=========================================================
; Código en Assembler para PIC18F4550
; LED en RB0
; Parpadeo con retardo preciso de 250ms usando Timer1
;=========================================================

#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS
    CONFIG  WDT = OFF
    CONFIG  LVP = OFF
    CONFIG  PBADEN = OFF

    ; Preload para Timer1: desborde en 250ms (8MHz, prescaler 1:8)
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

    ; Configurar Timer1: 16 bits, prescaler 1:8, reloj interno
    MOVLW   0b10110000
    MOVWF   T1CON
    BCF     T1CON, 0           ; Timer apagado por ahora

BuclePrincipal:
    BSF     LATB, 0
    CALL    Retardo_250ms
    BCF     LATB, 0
    CALL    Retardo_250ms
    GOTO    BuclePrincipal

;=========================================================
; Subrutina de retardo de 250ms usando Timer1
;=========================================================
Retardo_250ms:
    ; Cargar preload
    MOVLW   TMR1_HIGH
    MOVWF   TMR1H
    MOVLW   TMR1_LOW
    MOVWF   TMR1L

    BCF     PIR1, 0            ; Limpiar bandera de overflow
    BSF     T1CON, 0           ; Encender timer

Espera:
    BTFSS   PIR1, 0            ; ¿Desbordó?
    GOTO    Espera

    BCF     T1CON, 0           ; Apagar timer
    RETURN

;=========================================================
; Variables en RAM
;=========================================================
    PSECT udata
; (No se necesitan variables adicionales aún)

    END