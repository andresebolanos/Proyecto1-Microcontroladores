;==================================================================
; Proyecto:     Secuencia de parpadeos con LED
; Descripcion:  Realiza 5 parpadeos de 1s seguidos de 2 parpadeos
;               de 2s de forma continua e infinita
; Hardware:     LED en RB0
; Oscilador:    Interno 8MHz
; Autor:        Andres Bolanos
;==================================================================
    #include <xc.inc>  
    
    ; Configuracion de bits de confiuracion
    CONFIG FOSC   = INTOSCIO_EC ; Usa el oscilador interno a 8MHz
    CONFIG WDT    = OFF	        ; Desactiva el Watchdog Timer
    CONFIG LVP    = OFF	        ; Deshabilita la programaci?n en bajo voltaje
    CONFIG MCLRE  = OFF		; Contrala si el pin MCLR es: ON: Pin de Reset, OFF: Se convierte en entrada digital
    CONFIG PWRT   = ON	        ; Es el Power-up Timer: ON:Agrega un peque?o retardo cuando el PIC enciende, OFF: Arranca inmediatamente
    CONFIG PBADEN = OFF		; PORTB como digitales (no analogicos)
    
    ;=== Vectores de Inicio ===
    PSECT resetVec, class=CODE, reloc=2 ; Seccion para el vector de reinicio
resetVec:
    ORG 0x00				; Direccion de inicio
    GOTO Inicio				; Sar a la rutina de inicio
    
    ;=== Codigo Principal ===
    PSECT main_code, class=CODE, reloc=2  ; Seccion de codigo principal
    
Inicio:
    ; IRCF=111 (8MHz), SCS=10 (oscilador interno)
    MOVLW 0b01110010
    MOVWF OSCCON, A
    
EsperaOsc:
    BTFSS OSCCON, 2, A      ; Esperar IOFS = 1
    GOTO  EsperaOsc
    
    CLRF  TRISB, A	    ; PORTB como salida
    CLRF  LATB, A	    ; Apagar los pines de PORTB
    
    ;=== Configurar Timer0 === 
    ; 16 bits, preescaler 1:256, reloj interno, Timer0=OFF
    MOVLW 0b00000111
    MOVWF T0CON, A
   
    BCF   INTCON, 2, A ; Limpiar bandera
    MOVLW 5
    MOVWF ContadorCiclo1, A ; 5 parpadeos de 1s
    MOVLW 2 
    MOVWF ContadorCiclo2, A ; 2 parpadeos de 2s
    
Loop1:
    BSF  LATB, 0, A ; LED ON
    CALL Espera1s
    
    BCF  LATB, 0, A ; LED OFF
    CALL Espera1s
    
    DECFSZ ContadorCiclo1, F, A
    GOTO   Loop1
    
Loop2:
    BSF  LATB, 0, A ; LED ON
    CALL Espera2s
    
    BCF  LATB, 0, A ; LED OFF
    Call Espera2s
    
    DECFSZ ContadorCiclo2, F, A
    GOTO   Loop2
    
    ;Recargamos los contadore y repetimos la secuencia
    MOVLW 5
    MOVWF ContadorCiclo1, A
    MOVLW 2 
    MOVWF ContadorCiclo2, A
    GOTO  Loop1 ; Hace que la secuencia sea infinita
    
Espera1s:
    ; Recarga del timer para 1 seg
    ; Con Fosc=8Mhz, tenemos un Tcy=0.5us y usamos un preescaler de 256
    ; 1seg/(0.5us*256)= 7812 ticks -> calculo de precarga 65536-7812=57724=0xE17C
    BCF T0CON, 7, A ; Detener timer
    
    MOVLW 0XE1
    MOVWF TMR0H, A ; Bit Alto 
    MOVLW 0X7C 
    MOVWF TMR0L, A ; Bit Bajo
    
    BCF INTCON, 2, A ; Limpiar bandera
    BSF T0CON,  7, A ; Iniciar timer
    
    GOTO EsperaLoop ; usamos GOTO para compartir el EsperaLoop
    
Espera2s:
    ; Recarga del timer para 2 seg
    ; Con Fosc=8MHz, tenemos un Tcy=0.5us y usamos un preescaler de 256 (por seguridad)
    ; 2seg/(0.5us*256)= 15625 ticks -> calculo de precarga 65536-15625=49911=0xC2F7
    BCF T0CON, 7, A ; Detener timer
    
    MOVLW 0xC2
    MOVWF TMR0H, A ; Bit Alto
    MOVLW 0xF7
    MOVWF TMR0L, A ; Bit Bajo
    
    BCF INTCON, 2, A ; Limpiar bandera
    BSF T0CON,  7, A ; Iniciar timer
    
    GOTO EsperaLoop ; usamos GOTO para compartir el EsperaLoop
    
    ; Esperar desbordamiento
EsperaLoop:
    BTFSS INTCON, 2, A
    GOTO EsperaLoop
    BCF INTCON, 2, A 
    RETURN  ; Regresamos al CALL original
    
    ;=== Variables ===
    PSECT udata_acs, class=COMRAM
ContadorCiclo1: DS 1
ContadorCiclo2: DS 1
    END