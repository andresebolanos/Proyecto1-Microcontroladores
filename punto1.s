;=========================================================
; Código en Assembler para PIC18F4550
; Parpadeo de LED en RB0: 1 segundo encendido, 2 segundos apagado
; Usa retardos por software (sin interrupciones ni temporizadores)
; Frecuencia: 8 MHz (Oscilador Interno )
; Ensamblador: MPLAB XC8 (pic-as)
;=========================================================

    #include <xc.inc>   ; Incluir definiciones del ensamblador para PIC18F4550

    ; Configuración de bits de configuración (Fuses)
    CONFIG  FOSC = INTOSCIO_EC   ; Oscilador interno, función de reloj en RA6
    CONFIG  WDT = OFF            ; Deshabilitar Watchdog Timer
    CONFIG  LVP = OFF            ; Deshabilitar programación en bajo voltaje (libera RB5)
    CONFIG  PBADEN = OFF         ; Configurar pines de PORTB como digitales

    ;============================================-.
    ; Vectores de Inicio
    ;============================================-.

    PSECT  resetVec, class=CODE, reloc=2  ; Sección para el vector de reinicio
    ORG     0x00                          ; Dirección de inicio del vector
    GOTO    Inicio                         ; Saltar al código principal

    ;===============================================
    ; Código Principal
    ;=============================================
    
    PSECT  main_code, class=CODE, reloc=2  ; Sección de código principal

Inicio:
    ; Configurar oscilador interno a 8 MHz
    ; Para obtener 8 MHz, configuramos IRCF = 111 (bits 6-4) y SCS = 00 (bit 0) en OSCCON.
    BANKSEL(OSCCON)     ; Seleccionar banco de OSCCON
    MOVLW   0b01110000  ; IRCF = 111 (bits 6-4) y SCS = 00 (bit 0)
    MOVWF   OSCCON      ; Actualizar frecuencia

    ; Pequeña pausa 
    NOP
    NOP
    NOP

    ; Configurar puertos
    CLRF    TRISB       ; Puerto B completo como salidas (0 = salida)
    CLRF    LATB        ; Apagar todos los LEDs del Puerto B

LoopPrincipal:
    ; Encender LED (RB0 = 1)
    BSF     LATB, 0     ; Poner en alto el bit 0 de LATB

    ; Esperar 1 segundo
    CALL    Retardo_1s

    ; Apagar LED (RB0 = 0)
    BCF     LATB, 0     ; Poner en bajo el bit 0 de LATB

    ; Esperar 2 segundos (llamar dos veces al retardo de 1 segundo)
    CALL    Retardo_1s
    CALL    Retardo_1s

    ; Repetir el ciclo
    GOTO    LoopPrincipal

    ;===============================================
    ; Subrutina de Retardo de 1 Segundo 
    ; Utiliza tres contadores anidados.
    ; Los valores actuales (cntA = 11, cntB = 181, cntC = 255)
    ; están calculados para 8 MHz. Si el tiempo no es exacto,
    ; modificar el valor de cntB (definido como VALOR_B) experimentalmente.
    ; - Aumentar cntB incrementa el retardo.
    ; - Disminuir cntB reduce el retardo.
    ;===============================================

    ; Valor ajustable para cntB 
    ; Valor recomendado: 181 para 1 segundo exacto (con cntA=11, cntC=255)
    #define VALOR_B 181

Retardo_1s:
    ; Cargar contador externo (nivel A)
    MOVLW   11
    MOVWF   cntA        ; Guardar en cntA

bucleA:
    ; Cargar contador medio (nivel B) con el valor calibrado
    MOVLW   VALOR_B
    MOVWF   cntB

bucleB:
    ; Cargar contador interno (nivel C)
    MOVLW   255
    MOVWF   cntC  ;Guardar en CntC

bucleC:
    ; Decrementar cntC hasta cero
    DECFSZ  cntC, F     ; Decrementa cntC, si es cero salta la siguiente instrucción
    BRA     bucleC      ; Si no es cero, repetir bucleC

    ; Al salir de bucleC, decrementar cntB
    DECFSZ  cntB, F     ; Decrementa cntB
    BRA     bucleB      ; Si no es cero, repetir bucleB

    ; Al salir de bucleB, decrementar cntA
    DECFSZ  cntA, F     ; Decrementa cntA
    BRA     bucleA      ; Si no es cero, repetir bucleA

    ; Retorno de la subrutina
    RETURN

    ;===========================================..,
    ; Definición de Variables en Access RAM
    ;==========================================.,,

    PSECT  udata_acs    ; Sección de datos en access RAM (sin inicializar)
cntA:   DS 1            ; Contador nivel A
cntB:   DS 1            ; Contador nivel B
cntC:   DS 1            ; Contador nivel C

    END                 ; Fin del programa