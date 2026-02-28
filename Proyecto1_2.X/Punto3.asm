;===================================================
; Proyecto: 4 secuencias con LEDs
; Secuencias en RD4-RD7
; Pulsadores: RB0 (cambio de secuencia), RB1 (velocidad)
; Oscilador interno 8MHz
; Autor: Andres Bolaños
;===================================================
    
    #include <xc.inc>

;=== Configuracion ===
    CONFIG FOSC   = INTOSCIO_EC ; Usa el oscilador interno a 8MHz
    CONFIG WDT    = OFF	        ; Desactiva el Watchdog Timer
    CONFIG LVP    = OFF	        ; Deshabilita la programacion en bajo voltaje
    CONFIG MCLRE  = OFF		; Pin MCLR habilitado como entrada digital
    CONFIG PWRT   = ON	        ; Power-up Timer activado (retardo al encender)
    CONFIG PBADEN = OFF		; PORTB como digitales (no analogicos)
    CONFIG DEBUG  = OFF         ; Deshabilita modo depuracion
   
;=== Vector de Reset ===
    PSECT resetVec, class=CODE, reloc=2
resetVec:
    ORG 0x000		    ; Direccion de inicio
    GOTO Inicio		    ; Saltar a la rutina de inicio
    
;=== Vector de Interrupcion ===
    PSECT isrVec, class=CODE, reloc=2
    ORG	 0b00001000         ; 0x08 Vector de interrupcion
    GOTO ISR

;=== Codigo Principal ===
    PSECT main_code, class=CODE, reloc=2

Inicio:
    ; IRCF=111 (8MHz), SCS=10 (oscilador interno)
    MOVLW 0b01110010
    MOVWF OSCCON, A
    
EsperaOsc:
    BTFSS OSCCON, 2, A   ; Esperar I0FS=1
    GOTO  EsperaOsc
    
    ;=== Configurar Puertos ===
    ; RD como salidas
    CLRF TRISD, A
    CLRF LATD, A
    ; RB como entradas 
    SETF TRISB, A
    
    ; Pull-ups internos PORTB desabilitados (RBPU=1)
    BSF INTCON2, 7, A
    ; INT0 por flanco de Bajada (INTEDG0=0) porque boton va a GND (1->0)
    BCF INTCON2, 6, A
    ; INT1 por flanco de Bajada (INTEDG1=0)
    BCF	INTCON2, 5, A
    ; Limpiar bandera INT1IF 
    BCF INTCON3, 0, A
    ; Habilitar INT1IE (Habilita interrupcion INT1)
    BSF INTCON3, 3, A
    
    BCF INTCON, 1, A ; Limpiamos bandera de INT0IF
    BSF	INTCON, 4, A ; Habilita interrupciones
    BSF INTCON, 7, A ; Permite interrupciones
    
    ; Configurar Timer0 
    ; 16 bits, preescaler 1:256, reloj interno, Timer0=OFF
    MOVLW 0b00000111
    MOVWF T0CON, A
    
    MOVLW 0
    MOVWF VelAct, A ; Velocidad inicial = rapida
    MOVLW 1
    MOVWF SecAct, A ; Secuencia inicial = 1
    GOTO Loop 
    
    ;=== INTERRUPCION ===
    ISR:
	CALL Antirebote
	
	; PASO INT0 (secuencia)
	BTFSC INTCON, 1, A
	GOTO ManejoINT0
    
	; PASO INT1 (velocidad)
	BTFSC INTCON3, 0, A
	GOTO ManejoINT1
	
	RETFIE
    
    ; Retardo 20ms(aprox.) por software (para antirebote)
    ; Necesitamos 40000 ciclos para 20ms (20m/0.5u)
    Antirebote: 
	; Buscamos 2 numeros que multiplicados den 20000 iteraciones (40000/2)
	; En este caso tenemos: 255*78 = 19890 = 0xFF*0x4E
	MOVLW 0xFF
	MOVWF RetrasoExt, A
	MOVLW 0x4E
	MOVWF RetrasoInt, A
	CALL BucleRetraso
	
	RETURN
	
    BucleRetraso:
	DECFSZ RetrasoInt, F, A
	GOTO   BucleRetraso
	DECFSZ RetrasoExt, F, A
	GOTO   BucleRetraso
	RETURN
    

    
    ManejoINT0:
	; Cambio de secuencia
	BCF INTCON, 1, A ; Limpiar Bandera
	RETFIE
	
    ManejoINT1:
	; Manejo de velocidad
	BCF INTCON3, 0, A ; Limpiar Bandera
	RETFIE
    
    ;=== RELOJ ===
    Velocidad500ms:
    ; Recarga del timer para 500ms
    ; Con Fosc=8Mhz, tenemos un Tcy=0.5us y usamos un preescaler de 256
    ; 500ms/(0.5us*256)= 3906 ticks -> calculo de precarga 65536-3906=61630=F0BE
    BCF T0CON, 7, A ; Detener timer
    
    MOVLW 0XF0
    MOVWF TMR0H, A ; Bit Alto 
    MOVLW 0XBE 
    MOVWF TMR0L, A ; Bit Bajo
    
    BCF INTCON, 2, A ; Limpiar bandera
    BSF T0CON,  7, A ; Iniciar timer
    
    GOTO EsperaLoop
    
    Velocidad250ms:
    ; Recarga del timer para 259ms
    ; Con Fosc=8Mhz, tenemos un Tcy=0.5us y usamos un preescaler de 256
    ; 250ms/(0.5us*256)= 1953 ticks -> calculo de precarga 65536-1953=63583=F85F
    BCF T0CON, 7, A ; Detener timer
    
    MOVLW 0XF8
    MOVWF TMR0H, A ; Bit Alto 
    MOVLW 0X5F 
    MOVWF TMR0L, A ; Bit Bajo
    
    BCF INTCON, 2, A ; Limpiar bandera
    BSF T0CON,  7, A ; Iniciar timer
    
    GOTO EsperaLoop
    
    
    EsperaLoop:
    BTFSS INTCON, 2, A
    GOTO EsperaLoop
    BCF INTCON, 2, A 
    RETURN

;=== Bucle principal ===
Loop:
    ; 1. Revisar pulsador de secuencia (RB0)
    ;    Si fue presionado = avanzar SecAct

    ; 2. Revisar pulsador de velocidad (RB1)
    ;    Si fue presionado = cambiar VelAct

    ; 3. Ejecutar un paso de la secuencia actual
    ;    Segun SecAct llamar a Seq1, Seq2, Seq3 o Seq4

    GOTO Loop

;=== Secuencia 1: Izquierda a derecha ===
; RD4 ? RD5 ? RD6 ? RD7
Seq1:
    RETURN

;=== Secuencia 2: Derecha a izquierda ===
; RD7 ? RD6 ? RD5 ? RD4
Seq2:
    RETURN

;=== Secuencia 3: Parpadeo simultaneo ===
; TODOS ON ? TODOS OFF
Seq3:
    RETURN

;=== Secuencia 4: Alternado ===
; RD4,RD6 ON / RD5,RD7 OFF ? intercambiar
Seq4:
    RETURN

;=== Antirebote y lectura de pulsador ===
; Detecta flanco, espera 20ms, verifica
ChecarPulsador:
    RETURN

;=== Retardo segun velocidad actual ===
; Si VelAct=0 ? 250ms
; Si VelAct=1 ? 500ms
Retardo:
    RETURN

;=== Variables (Access Bank) ===
    PSECT udata_acs, class=COMRAM
SecAct:          DS 1
VelAct:          DS 1
Contador:        DS 1
RetrasoExt:      DS 1
RetrasoInt:      DS 1

    END
