;==================================================================
;Codigo en Assembler para PIC18F4550
;Usa retardos con Timer0
;Frecuencia: 8MHz
;==================================================================
    #include <xc.inc>  
    
    ; Configuracion de bits de confiuracion
    config FOSC   = INTOSCIO_EC ; Usa el oscilador interno a 8MHz
    config WDT    = OFF	        ; Desactiva el Watchdog Timer
    config LVP    = OFF	        ; Deshabilita la programaci?n en bajo voltaje
    config MCLRE  = OFF		; Contrala si el pin MCLR es: ON: Pin de Reset, OFF: Se convierte en entrada digital
    CONFIG PWRT   = ON	        ; Es el Power-up Timer: ON:Agrega un pequeño retardo cuando el PIC enciende, OFF: Arranca inmediatamente
    CONFIG PBADEN = OFF
    CONFIG DEBUG  = OFF
    
    ;=== Vectores de Inicio ===
    PSECT resetVec, class=CODE, reloc=2 ; Seccion para el vector de reinicio
resetVec:
    ORG 0x00				; Direccion de inicio
    GOTO Inicio				; Saltar a la rutina de inicio
    
    ;=== Codigo Principal ===
    PSECT main_code, class=CODE, reloc=2  ; Seccion de codigo principal
    
Inicio:
    MOVLW 0b01110010
    MOVWF OSCCON, A
    BCF   TRISD, 0, A	    ; PORTD(0) como salida
    BSF   LATD, 0, A	    ; Apagar pin 0 de PORTD
    
    ; Configurar Timer0:
    ; Modo 16 bits
    ; Reloj interno
    ; Preescaler 1:256
    ; Timer encendido (inicio)
    MOVLW   0x87
    MOVWF   T0CON, A
   
    BCF     INTCON, 2, A ; Limpiar bandera
    BSF     T0CON,  7, A ; Timer0 = ON
    
Loop:
    ; === Encender 1 segundo ===
    BSF LATD, 0, A
    CALL Espera
    
    ; === Apagar 2 segundos ===
    BCF LATD, 0, A
    MOVLW 2
    MOVWF Contador, A

Apagado:
    CALL Espera
    DECFSZ Contador, F, A
    GOTO Apagado
    
    GOTO Loop

Espera:
    ; Recarga del timer para 1 seg
    ; Con Fosc=8Mhz, tenemos un Tcy=0.5us y usamos un preescaler de 256
    ; 1seg/(0.5us*256)= 7812 ticks -> calculo de precarga 65536-7812=57724=0xE17C
    BCF   T0CON, 7, A  ; Detener timer
    
    MOVLW 0XE1
    MOVWF TMR0H, A
    MOVLW 0X7C 
    MOVWF TMR0L, A
    
    BCF   INTCON, 2, A ; Limpiar bandera
    BSF   T0CON,  7, A ; Iniciar timer
    
    ; Esperar hasta que TMR0IF = 1 (overflow del Timer0)
EsperaLoop:
    BTFSS INTCON, 2, A
    GOTO EsperaLoop
    BCF INTCON, 2, A 
    Return
    
    ;=== Variables ===
    PSECT udata 
Contador: DS 1
    END
