;=========================================================
; implementacion de cambio de velocidad (3 velocidades)
; - VelIdx: 0=lenta (8 desb), 1=media (4 desb), 2=rápida (2 desb)
; - Botón RB1 con antirrebote
;=========================================================
#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS
    CONFIG  WDT  = OFF
    CONFIG  LVP  = OFF
    CONFIG  PBADEN = OFF

    ; Precarga para Timer1 (8MHz, prescaler 1:8, desborde ~75ms)
    #define TMR1_HIGH_LENTO   0b00001011
    #define TMR1_LOW_LENTO    0b11011100
    #define BTN_SEQ           0       ; Botón de cambio de secuencia en RB0
    #define BTN_VEL           1       ; Botón de cambio de velocidad en RB1

;=========================================================
; VARIABLES EN RAM
;=========================================================
    PSECT udata
SeqIdx:         DS 1    ; Secuencia activa (0-3)
StepIdx:        DS 1    ; Paso actual dentro de la secuencia
VelIdx:         DS 1    ; Velocidad seleccionada (0=lenta, 1=media, 2=rápida)
ContDesbordes:  DS 1    ; Contador de desbordes restantes
TmpDebounce:    DS 1    ; Para loops de antirrebote

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
    MOVLW   0b01110000
    MOVWF   OSCCON
    NOP
    NOP

    ; Configurar puertos
    CLRF    TRISD
    CLRF    LATD
    BSF     TRISB, 0          ; RB0 como entrada (botón secuencia)
    BSF     TRISB, 1          ; RB1 como entrada (botón velocidad)

    ; Deshabilitar ADC
    MOVLW   0x0F
    MOVWF   ADCON1

    ; Configurar Timer1 (prescaler 1:8, 16 bits, interno)
    MOVLW   0b10110000          ; RD16=1, T1CKPS=11, TMR1CS=0
    MOVWF   T1CON
    BCF     T1CON, 0            ; Timer1 apagado inicialmente

    ; Inicializar variables
    CLRF    SeqIdx          ; Empezar con secuencia 0
    CLRF    StepIdx         ; Paso 0
    CLRF    VelIdx          ; Comenzar con velocidad lenta

BuclePrincipal:
    ; Revisar botón de secuencia RB0
    BTFSC   PORTB, BTN_SEQ      ; ¿RB0 = 0 (presionado)?
    GOTO    SkipSeq
    CALL    AntirreboteSeq       ; Procesar pulsación
SkipSeq:
    ; Revisar botón de velocidad RB1
    BTFSC   PORTB, BTN_VEL      ; ¿RB1 = 0 (presionado)?
    GOTO    SkipVel
    CALL    AntirreboteVel       ; Procesar pulsación
SkipVel:
    CALL    EjecutarPaso        ; Muestra el patrón actual y avanza al siguiente
    CALL    RetardoVel           ; Usa Timer1 con velocidad seleccionada
    GOTO    BuclePrincipal

;---------------------------------------------------------
; EJECUTAR PASO DE LA SECUENCIA ACTIVA
;---------------------------------------------------------
EjecutarPaso:
    MOVF    SeqIdx, W
    BZ      DoSeq0
    DECF    WREG, W
    BZ      DoSeq1
    DECF    WREG, W
    BZ      DoSeq2
    CALL    Seq3Paso
    RETURN
DoSeq0:
    CALL    Seq0Paso
    RETURN
DoSeq1:
    CALL    Seq1Paso
    RETURN
DoSeq2:
    CALL    Seq2Paso
    RETURN

;=========================================================
; SECUENCIA 0: Cinta (dos LEDs juntos)
;=========================================================
Seq0Paso:
    MOVF    StepIdx, W
    CALL    TblSeq0
    MOVWF   LATD
    INCF    StepIdx, F
    MOVLW   4
    CPFSEQ  StepIdx
    RETURN
    CLRF    StepIdx
    RETURN

TblSeq0:
    ADDWF   PCL, F
    RETLW   0x03
    RETLW   0x06
    RETLW   0x0C
    RETLW   0x08

;=========================================================
; SECUENCIA 1: Extremos -> centro -> extremos
;=========================================================
Seq1Paso:
    MOVF    StepIdx, W
    CALL    TblSeq1
    MOVWF   LATD
    INCF    StepIdx, F
    MOVLW   8
    CPFSEQ  StepIdx
    RETURN
    CLRF    StepIdx
    RETURN

TblSeq1:
    ADDWF   PCL, F
    RETLW   0x09
    RETLW   0x0F
    RETLW   0x06
    RETLW   0x00
    RETLW   0x06
    RETLW   0x0F
    RETLW   0x09
    RETLW   0x00

;=========================================================
; SECUENCIA 2: Todos ON, se apagan uno a uno
;=========================================================
Seq2Paso:
    MOVF    StepIdx, W
    CALL    TblSeq2
    MOVWF   LATD
    INCF    StepIdx, F
    MOVLW   5
    CPFSEQ  StepIdx
    RETURN
    CLRF    StepIdx
    RETURN

TblSeq2:
    ADDWF   PCL, F
    RETLW   0x0F
    RETLW   0x07
    RETLW   0x03
    RETLW   0x01
    RETLW   0x00

;=========================================================
; SECUENCIA 3: Pulso corto, pausa, doble pulso
;=========================================================
Seq3Paso:
    MOVF    StepIdx, W
    CALL    TblSeq3
    MOVWF   LATD
    INCF    StepIdx, F
    MOVLW   8
    CPFSEQ  StepIdx
    RETURN
    CLRF    StepIdx
    RETURN

TblSeq3:
    ADDWF   PCL, F
    RETLW   0x03
    RETLW   0x00
    RETLW   0x00
    RETLW   0x0F
    RETLW   0x00
    RETLW   0x0F
    RETLW   0x00
    RETLW   0x00

;=========================================================
; ANTIRREBOTE PARA SECUENCIA
;=========================================================
AntirreboteSeq:
    MOVLW   0xFF
    MOVWF   TmpDebounce
DebSeqLoop:
    DECFSZ  TmpDebounce, F
    GOTO    DebSeqLoop

    BTFSC   PORTB, BTN_SEQ       ; Verificar tras retardo
    RETURN                       ; Fue ruido

    INCF    SeqIdx, F
    MOVLW   4
    CPFSEQ  SeqIdx
    GOTO    SeqIdxOk
    CLRF    SeqIdx
SeqIdxOk:
    CLRF    StepIdx              ; Reiniciar paso

SeqWaitRelease:
    BTFSS   PORTB, BTN_SEQ       ; Esperar que suelte
    GOTO    SeqWaitRelease
    RETURN

;=========================================================
; ANTIRREBOTE PARA VELOCIDAD
;=========================================================
AntirreboteVel:
    MOVLW   0xFF
    MOVWF   TmpDebounce
DebVelLoop:
    DECFSZ  TmpDebounce, F
    GOTO    DebVelLoop

    BTFSC   PORTB, BTN_VEL       ; Verificar tras retardo
    RETURN                       ; Fue ruido

    INCF    VelIdx, F
    MOVLW   3
    CPFSEQ  VelIdx
    GOTO    VelIdxOk
    CLRF    VelIdx
VelIdxOk:
    ; No es necesario reiniciar StepIdx al cambiar velocidad

VelWaitRelease:
    BTFSS   PORTB, BTN_VEL       ; Esperar que suelte
    GOTO    VelWaitRelease
    RETURN

;=========================================================
; RETARDO CON TIMER1 SEGÚN VELOCIDAD
;=========================================================
RetardoVel:
    ; Seleccionar número de desbordes según VelIdx
    MOVF    VelIdx, W
    BZ      DoLento
    DECF    WREG, W
    BZ      DoMedio
    ; Velocidad rápida (2 desbordes)
    MOVLW   2
    MOVWF   ContDesbordes
    GOTO    IniciarTimer
DoLento:
    MOVLW   8
    MOVWF   ContDesbordes
    GOTO    IniciarTimer
DoMedio:
    MOVLW   4
    MOVWF   ContDesbordes

IniciarTimer:
    BCF     T1CON, 0            ; Detener Timer
    MOVLW   TMR1_HIGH_LENTO
    MOVWF   TMR1H
    MOVLW   TMR1_LOW_LENTO
    MOVWF   TMR1L
    BCF     PIR1, 0             ; Limpiar bandera TMR1IF
    BSF     T1CON, 0            ; Arrancar Timer

EsperarDesborde:
    BTFSS   PIR1, 0             ; ¿Desbordó?
    GOTO    EsperarDesborde      ; No, seguir esperando
    DECFSZ  ContDesbordes, F     ; Sí, descontar uno
    GOTO    IniciarTimer         ; Faltan más, reiniciar Timer
    BCF     T1CON, 0            ; Terminado, apagar Timer
    RETURN

    END