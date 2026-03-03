;==================================================================
; Parpadeo de LED con Timer0
; PORTB(0): 1 segundos encendido, 2 segundos apagado 
; Frecuencia: 8MHz
;==================================================================
    
    #include <xc.inc>  
    
;=== Configuracion ===
    config FOSC   = INTOSCIO_EC ; Usa el oscilador interno a 8MHz
    config WDT    = OFF	        ; Desactiva el Watchdog Timer
    config LVP    = OFF	        ; Programacion en bajo voltaje desactivada
    config MCLRE  = ON		; Pin MCLR habilitado como reset
    CONFIG PWRT   = ON	        ; Power-up Timer activado (retardo al encender)
    CONFIG PBADEN = OFF		; PORTB como digitales (no analogicos)
    CONFIG DEBUG  = OFF		; Debug desactivado
    
;=== Vectores de Inicio ===
    PSECT resetVec, class=CODE, reloc=2 ; Seccion para el vector de reinicio
resetVec:
    ORG 0x00				; Direccion de inicio
    GOTO Inicio				; Saltar a la rutina de inicio
    
;=== Codigo Principal ===
    PSECT main_code, class=CODE, reloc=2 
    
Inicio:
    ; Configurar oscilador interno a 8MHz
    MOVLW 0b01110010
    MOVWF OSCCON, A
    
EsperaOsc:
    ; Esperar hasta que el oscilador interno este estable
    BTFSS OSCCON, 2, A
    GOTO  EsperaOsc
    
    ; Configurar PORTB como salida y apagado
    CLRF  TRISB, A
    CLRF  LATB, A	   
    
    ; Configurar Timer0:
    ; Modo 16 bits
    ; Reloj interno
    ; Preescaler 1:256
    ; Timer encendido (inicio)
    MOVLW   0x87
    MOVWF   T0CON, A
   
    BCF     INTCON, 2, A ; Limpiar bandera antes de empezar

;=== Bucle principal ===
Loop:
    BSF LATB, 0, A     ; Encender LED (RB0)
    CALL Espera	       ; Retardo 1 segundo
    
    BCF LATB, 0, A     ; Apagar LED (RB0)
    MOVLW 2
    MOVWF Contador, A  ; Contador para 2 segundos

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
    BSF   T0CON,  7, A ; Iniciar Timer0
    
    ; Esperar hasta que TMR0IF = 1 (overflow del Timer0)
EsperaLoop:
    BTFSS INTCON, 2, A
    GOTO EsperaLoop
    BCF INTCON, 2, A ; Limpiar bandera TMR0IF
    Return
    
    ;=== Variables ===
    PSECT udata_acs, class=COMRAM
Contador: DS 1
    END
