;=========================================================
; Código en Assembler para PIC18F4550
; LED en RB0
; Secuencia:
; 5 parpadeos de 1s (1s ON + 1s OFF)
; 2 parpadeos de 2s (2s ON + 2s OFF)
;=========================================================

#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS    ; Usa oscilador interno
    CONFIG  WDT = OFF           ; Desactiva Watchdog Timer
    CONFIG  LVP = OFF           ; Desactiva programación en bajo voltaje
    CONFIG  PBADEN = OFF        ; PORTB inicia como digital

    ; Preload para que Timer1 desborde en ~250ms (a 8MHz y prescaler 1:8)
    #define TMR1_HIGH  0b00001011
    #define TMR1_LOW   0b11011100

;=========================================================
; Vector de Reset
;=========================================================
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00               ; Dirección de reset del PIC
    GOTO    Inicio             ; Al encender, salta a Inicio

;=========================================================
; Código principal
;=========================================================
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0b01110000         ; 0111 -> 8MHz en bits IRCF
    MOVWF   OSCCON             ; Configura oscilador interno a 8 MHz
    NOP                        ; Pequeña espera para estabilizar
    NOP

    CLRF    TRISB              ; TRISB=0 -> todo PORTB como salida
    CLRF    LATB               ; Apaga todos los pines de PORTB

    MOVLW   0b10110000         ; Configuración de T1CON:
                               ; RD16=1 -> modo 16 bits
                               ; T1CKPS=11 -> prescaler 1:8
                               ; TMR1CS=0 -> reloj interno (Fosc/4)
                               ; TMR1ON=0 -> Timer apagado
    MOVWF   T1CON              ; Carga configuración al Timer1

;=========================================================
; BUCLE PRINCIPAL
;=========================================================
BuclePrincipal:

;-----------------------------
; FASE 1: 5 parpadeos de 1s
;-----------------------------
    MOVLW   5                  ; Cargar número de parpadeos
    MOVWF   NumBlinks          ; Guardar en variable

Ciclo5Blinks:
    BSF     LATB, 0            ; Pone RB0 en 1 -> LED ON
    CALL    Retardo_1s         ; Espera 1 segundo
    BCF     LATB, 0            ; Pone RB0 en 0 -> LED OFF
    CALL    Retardo_1s         ; Espera 1 segundo
    DECFSZ  NumBlinks, F       ; Decrementa contador
                               ; Si queda en 0 -> salta siguiente instrucción
    GOTO    Ciclo5Blinks       ; Si no es 0 -> repetir

;-----------------------------
; FASE 2: 2 parpadeos de 2s
;-----------------------------
    MOVLW   2                  ; Número de parpadeos
    MOVWF   NumBlinks

Ciclo2Blinks:
    BSF     LATB, 0            ; LED ON
    CALL    Retardo_2s         ; Espera 2 segundos
    BCF     LATB, 0            ; LED OFF
    CALL    Retardo_2s         ; Espera 2 segundos
    DECFSZ  NumBlinks, F       ; Decrementa contador
    GOTO    Ciclo2Blinks       ; Repite hasta terminar

    GOTO    BuclePrincipal     ; Reinicia toda la secuencia

;=========================================================
; SUBRUTINAS DE RETARDO
;=========================================================
Retardo_500ms:
    MOVLW   2                  ; 2 desbordes de 250ms = 500ms
    MOVWF   ContadorDesbordes
    BRA     IniciarTimer       ; Salta a rutina común

Retardo_1s:
    MOVLW   4                  ; 4 × 250ms = 1 segundo
    MOVWF   ContadorDesbordes
    BRA     IniciarTimer

Retardo_2s:
    MOVLW   8                  ; 8 × 250ms = 2 segundos
    MOVWF   ContadorDesbordes

;-----------------------------
; Rutina común de temporización
;-----------------------------
IniciarTimer:
    BCF     T1CON, 0           ; Apaga Timer1 (bit TMR1ON=0)
    MOVLW   TMR1_HIGH
    MOVWF   TMR1H              ; Carga parte alta del preload
    MOVLW   TMR1_LOW
    MOVWF   TMR1L              ; Carga parte baja del preload
    BCF     PIR1, 0            ; Limpia bandera TMR1IF (overflow)
    BSF     T1CON, 0           ; Enciende Timer1 (TMR1ON=1)

EsperarDesborde:
    BTFSS   PIR1, 0            ; ¿Se desbordó el timer?
                               ; Si NO -> sigue esperando
    GOTO    EsperarDesborde
    ; Si llega aquí -> ocurrió el desborde (~250ms)
    DECFSZ  ContadorDesbordes, F  ; Resta 1 al contador
    GOTO    IniciarTimer          ; Si no es 0 -> repetir otro desborde
    BCF     T1CON, 0           ; Apaga el timer al terminar
    RETURN                     ; Regresa a donde fue llamado

;=========================================================
; Variables en RAM
;=========================================================
    PSECT udata
NumBlinks:          DS 1       ; Guarda número de parpadeos
ContadorDesbordes:  DS 1       ; Cuenta cuántos desbordes faltan

    END