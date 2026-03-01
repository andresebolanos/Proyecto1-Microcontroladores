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
	INCF   SecAct, F, A ; INCF f, d, a Increment f
	MOVLW  5
	CPFSEQ SecAct, A    ; CPFSEQ f, a Compare f with WREG, skip =
	GOTO   FinINT0
	MOVLW  1
	MOVWF  SecAct, A    ; Reiniciamos contador 5->1
	
    FinINT0: 
	BCF    INTCON, 1, A ; Limpiar Bandera
	
	RETFIE
	
    ManejoINT1:
	; Manejo de velocidad
	BTG VelAct, 0, A  ; Invierte bit 0: 0=>1 o 1=>0
	BCF INTCON3, 0, A ; Limpiar Bandera
	RETFIE
    
    ;=== Manejo de Velocidades ===
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
    ; Recarga del timer para 250ms
    ; Con Fosc=8Mhz, tenemos un Tcy=0.5us y usamos un preescaler de 256
    ; 250ms/(0.5us*256)= 1953 ticks -> calculo de precarga 65536-1953= 63583 = F85F
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
    MOVLW  1
    CPFSEQ SecAct, A   ; Si SecAct = 1, salta linea
    GOTO   Revisa2
    CALL   Seq1
    GOTO   Loop		; Mantiene en ciclo Seq1

Revisa2: 
    MOVLW  2
    CPFSEQ SecAct, A    ; Si SecAct = 2, salta linea
    GOTO   Revisa3
    CALL   Seq2
    GOTO   Revisa2	; Mantiene en ciclo Seq2

Revisa3:
    MOVLW  3
    CPFSEQ SecAct, A     ; Si SecAct = 3, salta linea
    GOTO   Revisa4       
    CALL   Seq3
    GOTO   Revisa3	 ; Mantiene en ciclo Seq3
 
Revisa4:
    MOVLW  4
    CPFSEQ SecAct, A      ; Si SecAct = 4, salta linea
    GOTO   Loop
    CALL   Seq4
    GOTO   Revisa4         ; Mantiene en ciclo Seq4

;=== Secuencia 1: Barrida con acumulacion derecha ===
; RD7 viaja acumulando hasta quedar todos ON
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
    
    ; Pasada 3: RD7 viaja hasta RD4
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
    
    CLRF  LATD, A ; todos OFF, reinicia
    
    RETURN

;=== Secuencia 2: Rebote RD7-RD4-RD7 ===
Seq2:
    
    MOVLW 0b10000000  ;RD7
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b01000000  ;RD6
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b00100000  ;RD5
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b00010000  ;RD4
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b00100000  ;RD5
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b01000000  ;RD6
    MOVWF LATD, A
    CALL  Retardo
    
    MOVLW 0b10000000  ;RD7
    MOVWF LATD, A
    CALL  Retardo
    
    RETURN

;=== Secuencia 3: Parpadeo simultaneo ===
; TODOS ON => TODOS OFF
Seq3:
    MOVLW 0b11110000	; RD4-RD7
    MOVWF LATD, A	; Todos ON
    CALL  Retardo
    
    CLRF LATD, A	; Todos OFF
    CALL  Retardo
    
    RETURN

;=== Secuencia 4: Alternado ===
; RD4,RD6 ON / RD5,RD7 OFF => intercambiar
Seq4:
    MOVLW 0b01010000	; RD4+RD6 
    MOVWF LATD, A   
    CALL  Retardo
    
    MOVLW 0b10100000    ; RD5+RD7
    MOVWF LATD, A
    CALL  Retardo
    
    RETURN

;=== Antirebote y lectura de pulsador ===
; Detecta flanco, espera 20ms, verifica
ChecarPulsador:
    RETURN

;=== Retardo segun velocidad actual ===
; VelAct=0 => 250ms | VelAct=1 => 500ms
Retardo:
    TSTFSZ VelAct, A ;Test f, skip if 0
    GOTO Velocidad500ms
    GOTO Velocidad250ms

;=== Variables (Access Bank) ===
    PSECT udata_acs, class=COMRAM
SecAct:          DS 1
VelAct:          DS 1
Contador:        DS 1
RetrasoExt:      DS 1
RetrasoInt:      DS 1

    END
