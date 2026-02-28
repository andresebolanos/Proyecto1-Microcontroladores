;=========================================================
; Versión con tablas de secuencias y avance de paso
; - Se definen las 4 secuencias (0..3)
; - Se ejecuta continuamente la secuencia 0 (cinta)
; - Retardo simple con decremento (provisional)
;=========================================================
#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS
    CONFIG  WDT  = OFF
    CONFIG  LVP  = OFF
    CONFIG  PBADEN = OFF

;=========================================================
; VARIABLES EN RAM
;=========================================================
    PSECT udata
SeqIdx:         DS 1    ; Secuencia activa (0-3)
StepIdx:        DS 1    ; Paso actual dentro de la secuencia
; (Por ahora no usamos VelIdx ni botones)

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
    BSF     TRISB, 0
    BSF     TRISB, 1

    ; Deshabilitar ADC
    MOVLW   0x0F
    MOVWF   ADCON1

    ; Inicializar variables
    CLRF    SeqIdx          ; Empezar con secuencia 0
    CLRF    StepIdx         ; Paso 0

BuclePrincipal:
    CALL    EjecutarPaso    ; Muestra el patrón actual y avanza al siguiente
    CALL    RetardoSimple   ; Espera un tiempo para que se vea el cambio
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
; RETARDO SIMPLE (provisional, ~200ms aprox con 8MHz)
;=========================================================
RetardoSimple:
    MOVLW   0xFF
    MOVWF   0x20        ; Usamos una dirección temporal
LoopExt:
    MOVLW   0xFF
    MOVWF   0x21
LoopInt:
    DECFSZ  0x21, F
    GOTO    LoopInt
    DECFSZ  0x20, F
    GOTO    LoopExt
    RETURN

    END