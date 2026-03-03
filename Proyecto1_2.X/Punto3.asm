;===================================================
; Proyecto: 4 secuencias con LEDs
; Descripcion: 4 efectos en RD4-RD7, cambio de secuencia
;              con RB0, cambio de velocidad con RB1.
;	       Antirebote por software de ~65ms.
; Oscilador interno 8MHz
; Autor: Andres Bolaños
;===================================================
    
    #include <xc.inc>

;=== Configuracion ===
    CONFIG FOSC   = INTOSCIO_EC ; Usa el oscilador interno a 8MHz
    CONFIG WDT    = OFF         ; Desactiva el Watchdog Timer
    CONFIG LVP    = OFF         ; Deshabilita la programacion en bajo voltaje
    CONFIG MCLRE  = OFF         ; Pin MCLR como entrada digital
    CONFIG PWRT   = ON          ; Power-up Timer activado
    CONFIG PBADEN = OFF         ; PORTB como digitales
    CONFIG DEBUG  = OFF         ; Deshabilita modo depuracion
   
;=== Vector de Reset ===
    PSECT resetVec, class=CODE, reloc=2
resetVec:
    ORG 0x000
    GOTO Inicio
    
;=== Vector de Interrupcion ===
    PSECT isrVec, class=CODE, reloc=2
    ORG  0b00001000             ; 0x08 Vector de interrupcion
    GOTO ISR

;=== Codigo Principal ===
    PSECT main_code, class=CODE, reloc=2

Inicio:
    ; IRCF=111 (8MHz), SCS=10 (oscilador interno)
    MOVLW 0b01110010
    MOVWF OSCCON, A
    
EsperaOsc:
    BTFSS OSCCON, 2, A          ; Esperar IOFS=1 (oscilador estable)
    GOTO  EsperaOsc
    
    ;=== Configurar Puertos ===
    CLRF TRISD, A               ; RD como salidas
    CLRF LATD, A                ; Apagar PORTD
    SETF TRISB, A               ; RB como entradas
    BSF  INTCON2, 7, A          ; Pull-ups PORTB deshabilitados
    BCF  INTCON2, 6, A          ; INT0 flanco de bajada
    BCF  INTCON2, 5, A          ; INT1 flanco de bajada
    BCF  INTCON3, 0, A          ; Limpiar bandera INT1IF
    BSF  INTCON3, 3, A          ; Habilitar INT1IE
    BCF  INTCON, 1, A           ; Limpiar bandera INT0IF
    BSF  INTCON, 4, A           ; Habilitar INT0IE
    BSF  INTCON, 7, A           ; GIE = 1 (interrupciones globales)
    
    ;=== Configurar Timer0 ===
    ; 16 bits, preescaler 1:256, reloj interno, Timer0=OFF
    MOVLW 0b00000111
    MOVWF T0CON, A
    MOVLW 0
    MOVWF VelAct, A             ; Velocidad inicial = rapida (250ms)
    MOVLW 1
    MOVWF SecAct, A             ; Secuencia inicial = 1
    GOTO  Loop 
    
;=== Rutina de Interrupcion ===
ISR:
    BTFSC INTCON, 1, A          ; Si INT0IF=1 fue INT0
    GOTO  ManejoINT0
    BTFSC INTCON3, 0, A         ; Si INT1IF=1 fue INT1
    GOTO  ManejoINT1
    RETFIE

;=== Antirebote por software (~65ms) ===
; Ciclos = 65ms / 0.5us = 130000
; Iteraciones = 130000 / 2 = 65000
; 255 * 255 = 65025 = 0xFF * 0xFF
Antirebote:
    MOVLW 0xFF
    MOVWF RetrasoExt, A
    MOVLW 0xFF
    MOVWF RetrasoInt, A
    CALL  BucleRetraso
    RETURN
	
;=== Bucle de retardo anidado ===
    ; RetrasoInt: contador interno (255->0)
    ; RetrasoExt: contador externo (255->0)
    ; Total iteraciones: 255*255=65025 (~60ms)
BucleRetraso:
    DECFSZ RetrasoInt, F, A
    GOTO   BucleRetraso
    DECFSZ RetrasoExt, F, A
    GOTO   BucleRetraso
    RETURN

;=== Manejo INT0: Cambio de secuencia (RB0) ===
ManejoINT0:
    BCF    INTCON, 1, A          ; Limpiar bandera primero
    CALL   Antirebote            ; Esperar ~65ms
    BTFSC  PORTB, 0, A           ; Si RB0=1 fue rebote, ignorar
    RETFIE
    INCF   SecAct, F, A          ; Pulsacion real: SecAct + 1
    MOVLW  5
    CPFSEQ SecAct, A             ; Si SecAct = 5, reiniciar (salta siguiente linea)
    RETFIE			 ; SecAct no es 5, ya quedo bien
    MOVLW 1
    MOVWF SecAct, A              ; Reiniciar a 1
    RETFIE

;=== Manejo INT1: Cambio de velocidad (RB1) ===
ManejoINT1:
    BCF   INTCON3, 0, A         ; Limpiar bandera primero
    CALL  Antirebote            ; Esperar ~65ms
    BTFSC PORTB, 1, A           ; Si RB1=1 fue rebote, ignorar
    RETFIE
    BTG   VelAct, 0, A          ; Alternar velocidad: 0->1 o 1->0
    RETFIE

;=== Velocidad 500ms ===
; Ticks = 500ms/(0.5us*256) = 3906
; Precarga = 65536-3906 = 61630 = 0xF0BE
Velocidad500ms:
    BCF   T0CON, 7, A           ; Detener Timer0
    MOVLW 0xF0
    MOVWF TMR0H, A              ; Byte alto
    MOVLW 0xBE
    MOVWF TMR0L, A              ; Byte bajo
    BCF   INTCON, 2, A          ; Limpiar TMR0IF
    BSF   T0CON, 7, A           ; Iniciar Timer0
    GOTO  EsperaLoop

;=== Velocidad 250ms ===
; Ticks = 250ms/(0.5us*256) = 1953
; Precarga = 65536-1953 = 63583 = 0xF85F
Velocidad250ms:
    BCF   T0CON, 7, A           ; Detener Timer0
    MOVLW 0xF8
    MOVWF TMR0H, A              ; Byte alto
    MOVLW 0x5F
    MOVWF TMR0L, A              ; Byte bajo
    BCF   INTCON, 2, A          ; Limpiar TMR0IF
    BSF   T0CON, 7, A           ; Iniciar Timer0
    GOTO  EsperaLoop

;=== Esperar desbordamiento Timer0 ===
EsperaLoop:
    BTFSS INTCON, 2, A          ; Esperar TMR0IF=1
    GOTO  EsperaLoop
    BCF   INTCON, 2, A          ; Limpiar TMR0IF
    RETURN

;=== Bucle principal ===
Loop:
    MOVLW  1
    CPFSEQ SecAct, A            ; Si SecAct=1 ejecutar Seq1
    GOTO   Revisa2
    CALL   Seq1
    GOTO   Loop

Revisa2:
    MOVLW  2
    CPFSEQ SecAct, A            ; Si SecAct=2 ejecutar Seq2
    GOTO   Revisa3
    CALL   Seq2
    GOTO   Revisa2

Revisa3:
    MOVLW  3
    CPFSEQ SecAct, A            ; Si SecAct=3 ejecutar Seq3
    GOTO   Revisa4
    CALL   Seq3
    GOTO   Revisa3

Revisa4:
    MOVLW  4
    CPFSEQ SecAct, A            ; Si SecAct=4 ejecutar Seq4
    GOTO   Loop
    CALL   Seq4
    GOTO   Revisa4

;=== Secuencia 1: Barrida con acumulacion RD7->RD4 ===
Seq1:
    ; Pasada 1: RD7 viaja hasta RD4
    MOVLW 0b10000000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01000000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00100000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00010000
    MOVWF LATD, A
    CALL  Retardo
    ; Pasada 2: RD7 viaja hasta RD5
    MOVLW 0b10010000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01010000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00110000
    MOVWF LATD, A
    CALL  Retardo
    ; Pasada 3: RD7 viaja hasta RD6
    MOVLW 0b10110000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01110000
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01110000
    MOVWF LATD, A
    CALL  Retardo
    ; Pasada 4: Todos ON
    MOVLW 0b11110000
    MOVWF LATD, A
    CALL  Retardo
    CLRF  LATD, A               ; Todos OFF, reinicia
    RETURN

;=== Secuencia 2: Rebote RD7-RD4-RD7 ===
Seq2:
    MOVLW 0b10000000            ; RD7
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01000000            ; RD6
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00100000            ; RD5
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00010000            ; RD4
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b00100000            ; RD5
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b01000000            ; RD6
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b10000000            ; RD7
    MOVWF LATD, A
    CALL  Retardo
    RETURN

;=== Secuencia 3: Parpadeo simultaneo ===
Seq3:
    MOVLW 0b11110000            ; Todos ON
    MOVWF LATD, A
    CALL  Retardo
    CLRF  LATD, A               ; Todos OFF
    CALL  Retardo
    RETURN

;=== Secuencia 4: Alternado ===
Seq4:
    MOVLW 0b01010000            ; RD6+RD4 ON
    MOVWF LATD, A
    CALL  Retardo
    MOVLW 0b10100000            ; RD7+RD5 ON
    MOVWF LATD, A
    CALL  Retardo
    RETURN

;=== Retardo segun velocidad actual ===
; VelAct=0 => 250ms | VelAct=1 => 500ms
Retardo:
    TSTFSZ VelAct, A            ; Si VelAct=0 salta
    GOTO   Velocidad500ms
    GOTO   Velocidad250ms

;=== Variables (Access Bank) ===
    PSECT udata_acs, class=COMRAM
SecAct:     DS 1                ; Secuencia actual (1-4)
VelAct:     DS 1                ; Velocidad actual (0=250ms, 1=500ms)
RetrasoExt: DS 1
RetrasoInt: DS 1

    END