;=========================================================
; Código en Assembler para PIC18F4550
; 4 Secuencias de LEDs con cambio de secuencia y velocidad
;
; Hardware:
;   LEDs   -> RD0, RD1, RD2, RD3 (PORTD)
;   RB0    -> Pulsador cambio de secuencia (activo en bajo)
;   RB1    -> Pulsador cambio de velocidad (activo en bajo)
;
; Secuencias:
;   secuencia 1     -> dos LEDs corren juntos de izq a der
;   secuencia 2     -> extremos->centro->extremos
;   secuencia 3     -> todos ON, se apagan uno a uno
;   secuencia 4     -> pulso corto, pausa, pulso doble
;
; Velocidades (RB1 cicla entre 3):
;   0: Lenta  ~600ms por paso
;   1: Media  ~300ms por paso
;   2: Rapida ~100ms por paso
;=========================================================
#include <xc.inc>

    CONFIG  FOSC = INTOSC_HS    ; Oscilador interno,
    CONFIG  WDT  = OFF           ; Watchdog deshabilitado
    CONFIG  LVP  = OFF           ; Programacion de bajo voltaje OFF
    CONFIG  PBADEN = OFF         ; PORTB como digital al encender

    ; Precargas del Timer1 (prescaler 1:8, Fosc=8MHz) 
    #define TMR1_HIGH_LENTO   0b00001011   ; Byte alto precarga lenta
    #define TMR1_LOW_LENTO    0b11011100   ; Byte bajo precarga lenta

    #define TMR1_HIGH_MEDIO   0b00101011   ; Byte alto precarga media
    #define TMR1_LOW_MEDIO    0b11011100   ; Byte bajo precarga media

    #define TMR1_HIGH_RAPIDO  0b01101011   ; Byte alto precarga rapida
    #define TMR1_LOW_RAPIDO   0b11011100   ; Byte bajo precarga rapida

    #define BTN_SEQ   0     ; Bit de RB0 -> boton de secuencia
    #define BTN_VEL   1     ; Bit de RB1 -> boton de velocidad

;=============================================
; VECTOR DE RESET 
; Al encender o resetear el PIC salta aqui y va a Inicio
;=========================================================
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio              ; Saltar al inicio del programa

;=========================================================
; CODIGO PRINCIPAL
;=========================================================
    PSECT  main_code, class=CODE, reloc=2

;---------------------------------------------------------
; INICIO: Configuracion del hardware 
;---------------------------------------------------------
Inicio:
    MOVLW   0b01110000          ; IRCF=111 -> seleccionar 8MHz
    MOVWF   OSCCON              ; Escribir config en registro oscilador
    NOP                         ; Esperar estabilizacion del oscilador
    NOP                         ; Dos ciclos de margen

    CLRF    TRISD               ; TRISD=0 -> todos pines de PORTD como salida
    CLRF    LATD                ; Apagar todos los LEDs al arrancar

    BSF     TRISB, 0            ; TRISB.0=1 -> RB0 como entrada
    BSF     TRISB, 1            ; TRISB.1=1 -> RB1 como entrada

    MOVLW   0x0F                ; Valor para deshabilitar ADC
    MOVWF   ADCON1              ; ADCON1=0x0F -> PORTB pines digitales

    MOVLW   0b10110000          ; RD16=1, T1CKPS=11 (1:8), TMR1CS=0 interno
    MOVWF   T1CON               ; Configurar Timer1
    BCF     T1CON, 0            ; TMR1ON=0 -> Timer1 apagado hasta usarlo

    CLRF    SeqIdx              ; Iniciar en secuencia 0 (Cinta)
    CLRF    StepIdx             ; Iniciar en el paso 0 de la secuencia
    CLRF    VelIdx              ; Iniciar en velocidad lenta

;=========================================================
; BUCLE PRINCIPAL (se repite indefinidamente)
;=========================================================
BuclePrincipal:

    ; -- Revisar boton de secuencia RB0 --
    ; BTFSC: salta si el bit es 0. Como el boton es activo
    ; en bajo (0=presionado), si RB0=1 no hacer nada.
    BTFSC   PORTB, BTN_SEQ     ; RB0=0 (presionado)? si no, saltar
    GOTO    SkipSeq             ; RB0=1 -> boton libre, ignorar
    CALL    AntirreboteSeq      ; RB0=0 -> procesar cambio de secuencia
SkipSeq:

    ; -- Revisar boton de velocidad RB1 --
    BTFSC   PORTB, BTN_VEL     ; RB1=0 (presionado)? si no, saltar
    GOTO    SkipVel             ; RB1=1 -> boton libre, ignorar
    CALL    AntirreboteVel      ; RB1=0 -> procesar cambio de velocidad
SkipVel:

    CALL    EjecutarPaso        ; Mostrar el siguiente paso de la secuencia
    CALL    RetardoVel          ; Esperar segun la velocidad activa
    GOTO    BuclePrincipal      ; Repetir el ciclo

;=========================================================
; ANTIRREBOTE - CAMBIO DE SECUENCIA (RB0)
;
; 1) Espera ~1ms para dejar pasar rebotes mecanicos
; 2) Verifica que RB0 sigue presionado (no fue ruido)
; 3) Incrementa SeqIdx (ciclo 0->1->2->3->0)
; 4) Reinicia StepIdx para empezar la nueva secuencia desde cero
; 5) Espera que suelten el boton para evitar cambios multiples
;=========================================================
AntirreboteSeq:
    MOVLW   0xFF                ; Cargar 255 en W
    MOVWF   TmpDebounce         ; Iniciar contador de retardo
DebSeqLoop:
    DECFSZ  TmpDebounce, F      ; Decrementar, saltar si llega a 0
    GOTO    DebSeqLoop          ; Seguir esperando

    BTFSC   PORTB, BTN_SEQ     ; Verificar RB0 tras el retardo
    RETURN                      ; RB0=1 -> fue ruido, no hacer nada

    INCF    SeqIdx, F           ; Avanzar a la siguiente secuencia
    MOVLW   4                   ; Comparar con 4 (total de secuencias)
    CPFSEQ  SeqIdx              ; Si SeqIdx==4, reiniciar
    GOTO    SeqIdxOk
    CLRF    SeqIdx              ; Volver a secuencia 0
SeqIdxOk:
    CLRF    StepIdx             ; Reiniciar paso al cambiar de secuencia

SeqWaitRelease:
    BTFSS   PORTB, BTN_SEQ     ; RB0=1 (suelto)? si no, esperar
    GOTO    SeqWaitRelease      ; Sigue presionado, seguir esperando
    RETURN                      ; Boton suelto, continuar

;=========================================================
; ANTIRREBOTE - CAMBIO DE VELOCIDAD (RB1)
; Misma logica que AntirreboteSeq pero para VelIdx
; VelIdx ciclo: 0 (lenta) -> 1 (media) -> 2 (rapida) -> 0
;=========================================================
AntirreboteVel:
    MOVLW   0xFF                ; Cargar valor para retardo
    MOVWF   TmpDebounce         ; Iniciar contador
DebVelLoop:
    DECFSZ  TmpDebounce, F      ; Decrementar, saltar al llegar a 0
    GOTO    DebVelLoop          ; Seguir esperando

    BTFSC   PORTB, BTN_VEL     ; Verificar RB1 tras el retardo
    RETURN                      ; RB1=1 -> fue ruido, ignorar

    INCF    VelIdx, F           ; Avanzar a la siguiente velocidad
    MOVLW   3                   ; Comparar con 3 (total de velocidades)
    CPFSEQ  VelIdx              ; Si VelIdx==3, reiniciar
    GOTO    VelIdxOk
    CLRF    VelIdx              ; Volver a velocidad lenta
VelIdxOk:

VelWaitRelease:
    BTFSS   PORTB, BTN_VEL     ; RB1=1 (suelto)? si no, esperar
    GOTO    VelWaitRelease      ; Sigue presionado, seguir esperando
    RETURN

;=========================================================
; EJECUTAR PASO DE LA SECUENCIA ACTIVA
; Lee SeqIdx y llama a la rutina de secuencia correspondiente
; Cada rutina lee StepIdx, escribe en LATD e incrementa StepIdx
;=========================================================
EjecutarPaso:
    MOVF    SeqIdx, W           ; Cargar indice de secuencia en W
    BZ      DoSeq0              ; W=0 -> ir a Secuencia 0 (Cinta)
    DECF    WREG, W             ; W=W-1
    BZ      DoSeq1              ; W=0 -> ir a Secuencia 1 (Espejo)
    DECF    WREG, W             ; W=W-1
    BZ      DoSeq2              ; W=0 -> ir a Secuencia 2 (Escalonado)
    CALL    Seq3Paso            ; Si no, ir a Secuencia 3 (Latido)
    RETURN
DoSeq0:
    CALL    Seq0Paso            ; Llamar rutina secuencia 1
    RETURN
DoSeq1:
    CALL    Seq1Paso            ; Llamar rutina secuencia 2
    RETURN
DoSeq2:
    CALL    Seq2Paso            ; Llamar rutina secuancia 3
    RETURN

;=========================================================
; SECUENCIA 1
; Dos LEDs adyacentes corren de izquierda a derecha y reinician
; Paso: 0011 -> 0110 -> 1100 -> 1000 -> (repite)
;=========================================================
Seq0Paso:
    MOVF    StepIdx, W          ; W = paso actual
    CALL    TblSeq0             ; Buscar patron en tabla
    MOVWF   LATD                ; Escribir patron en LEDs
    INCF    StepIdx, F          ; Avanzar al siguiente paso
    MOVLW   4                   ; Total: 4 pasos
    CPFSEQ  StepIdx             ; Si StepIdx==4, reiniciar
    RETURN
    CLRF    StepIdx             ; Volver al paso 0
    RETURN

TblSeq0:                        ; Tabla de patrones secuencia 1
    ADDWF   PCL, F              ; Saltar W posiciones en memoria
    RETLW   0x03                ; Paso 0: 0011
    RETLW   0x06                ; Paso 1: 0110
    RETLW   0x0C                ; Paso 2: 1100
    RETLW   0x08                ; Paso 3: 1000

;=========================================================
; SECUENCIA 2
; Se enciende desde extremos hacia el centro y regresa
; Paso: 1001->1111->0110->0000->0110->1111->1001->0000
;=========================================================
Seq1Paso:
    MOVF    StepIdx, W          ; W = paso actual
    CALL    TblSeq1             ; Buscar patron en tabla
    MOVWF   LATD                ; Escribir patron en LEDs
    INCF    StepIdx, F          ; Avanzar al siguiente paso
    MOVLW   8                   ; Total: 8 pasos
    CPFSEQ  StepIdx             ; Si StepIdx==8, reiniciar
    RETURN
    CLRF    StepIdx             ; Volver al paso 0
    RETURN

TblSeq1:                        ; Tabla de patrones Espejo
    ADDWF   PCL, F
    RETLW   0x09                ; Paso 0: 1001 extremos encendidos
    RETLW   0x0F                ; Paso 1: 1111 todos encendidos
    RETLW   0x06                ; Paso 2: 0110 solo centro
    RETLW   0x00                ; Paso 3: 0000 apagado
    RETLW   0x06                ; Paso 4: 0110 centro (camino de regreso)
    RETLW   0x0F                ; Paso 5: 1111 todos
    RETLW   0x09                ; Paso 6: 1001 extremos
    RETLW   0x00                ; Paso 7: 0000 apagado

;=========================================================
; SECUENCIA 2
; Todos los LEDs encienden juntos y se apagan uno a uno
; Paso: 1111 -> 0111 -> 0011 -> 0001 -> 0000 -> (repite)
;=========================================================
Seq2Paso:
    MOVF    StepIdx, W          ; W = paso actual
    CALL    TblSeq2             ; Buscar patron en tabla
    MOVWF   LATD                ; Escribir patron en LEDs
    INCF    StepIdx, F          ; Avanzar al siguiente paso
    MOVLW   5                   ; Total: 5 pasos
    CPFSEQ  StepIdx             ; Si StepIdx==5, reiniciar
    RETURN
    CLRF    StepIdx             ; Volver al paso 0
    RETURN

TblSeq2:                        ; Tabla de patrones secuencia 2
    ADDWF   PCL, F
    RETLW   0x0F                ; Paso 0: 1111 todos ON
    RETLW   0x07                ; Paso 1: 0111 apaga RD3
    RETLW   0x03                ; Paso 2: 0011 apaga RD2
    RETLW   0x01                ; Paso 3: 0001 apaga RD1
    RETLW   0x00                ; Paso 4: 0000 apaga RD0, todos OFF

;=========================================================
; SECUENCIA 3
; pulso corto (lub), pausa,
; luego doble pulso fuerte (dub-dub), pausa larga
; Paso: 0011->0000->0000->1111->0000->1111->0000->0000
;=========================================================
Seq3Paso:
    MOVF    StepIdx, W          ; W = paso actual
    CALL    TblSeq3             ; Buscar patron en tabla
    MOVWF   LATD                ; Escribir patron en LEDs
    INCF    StepIdx, F          ; Avanzar al siguiente paso
    MOVLW   8                   ; Total: 8 pasos
    CPFSEQ  StepIdx             ; Si StepIdx==8, reiniciar
    RETURN
    CLRF    StepIdx             ; Volver al paso 0
    RETURN

TblSeq3:                        ; Tabla de patrones secuencia 3
    ADDWF   PCL, F
    RETLW   0x03                ; Paso 0: 0011 pulso corto ON (lub)
    RETLW   0x00                ; Paso 1: 0000 OFF
    RETLW   0x00                ; Paso 2: 0000 pausa breve
    RETLW   0x0F                ; Paso 3: 1111 pulso fuerte ON (dub1)
    RETLW   0x00                ; Paso 4: 0000 OFF
    RETLW   0x0F                ; Paso 5: 1111 segundo golpe (dub2)
    RETLW   0x00                ; Paso 6: 0000 OFF
    RETLW   0x00                ; Paso 7: 0000 pausa larga

;=========================================================
; RETARDO CON TIMER1 + REVISION DE BOTONES
; Segun VelIdx carga cuantos desbordes esperar:
;   0 -> 8 desbordes (~600ms)
;   1 -> 4 desbordes (~300ms)
;   2 -> 2 desbordes (~100ms)
;=========================================================
RetardoVel:
    MOVF    VelIdx, W           ; Cargar indice de velocidad
    BZ      DoLento             ; VelIdx=0 -> ir a lento
    DECF    WREG, W             ; W=W-1
    BZ      DoMedio             ; VelIdx=1 -> ir a medio
    MOVLW   2                   ; VelIdx=2 -> rapido: 2 desbordes
    MOVWF   ContDesbordes
    GOTO    IniciarTimer
DoLento:
    MOVLW   8                   ; Lento: 8 desbordes del Timer1
    MOVWF   ContDesbordes
    GOTO    IniciarTimer
DoMedio:
    MOVLW   4                   ; Medio: 4 desbordes del Timer1
    MOVWF   ContDesbordes

IniciarTimer:
    BCF     T1CON, 0            ; Detener Timer1 para cargar precarga
    MOVLW   TMR1_HIGH_LENTO     ; Cargar byte alto de precarga
    MOVWF   TMR1H
    MOVLW   TMR1_LOW_LENTO      ; Cargar byte bajo de precarga
    MOVWF   TMR1L
    BCF     PIR1, 0             ; Limpiar bandera TMR1IF (bit0 de PIR1)
    BSF     T1CON, 0            ; Arrancar Timer1

EsperarDesborde:
    BTFSS   PIR1, 0             ; TMR1IF=1? (Timer1 desbordado?)
    GOTO    ChkBtnsEnRetardo    ; No -> revisar botones y volver
    GOTO    TimerListo          ; Si -> procesar desborde

ChkBtnsEnRetardo:               ; Revision de botones durante la espera
    BTFSC   PORTB, BTN_SEQ     ; RB0=0 (presionado)?
    GOTO    ChkVelEnRetardo     ; No -> revisar velocidad
    CALL    AntirreboteSeq      ; Si -> cambiar secuencia
ChkVelEnRetardo:
    BTFSC   PORTB, BTN_VEL     ; RB1=0 (presionado)?
    GOTO    EsperarDesborde     ; No -> volver a esperar
    CALL    AntirreboteVel      ; Si -> cambiar velocidad
    GOTO    EsperarDesborde     ; Volver a esperar el desborde

TimerListo:
    DECFSZ  ContDesbordes, F    ; Descontar un desborde
    GOTO    IniciarTimer        ; Faltan desbordes -> reiniciar timer
    BCF     T1CON, 0            ; Retardo completo -> apagar Timer1
    RETURN

;=========================================================
; VARIABLES EN RAM
;=========================================================
    PSECT udata
SeqIdx:         DS 1    ; Secuencia activa (0-3)
StepIdx:        DS 1    ; Paso actual dentro de la secuencia (0 a N-1)
VelIdx:         DS 1    ; Velocidad activa (0=lenta, 1=media, 2=rapida)
ContDesbordes:  DS 1    ; Cuantos desbordes del Timer1 faltan
TmpDebounce:    DS 1    ; Contador temporal para loops de antirrebote

    END