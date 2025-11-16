// Audio Monitor Helper for Narra - VERSIÓN POLLING
// JavaScript calcula niveles y los expone en window.currentAudioLevel
// Dart lee periódicamente con un Timer

console.log('🚀 [AudioMonitorHelper] Iniciando carga del script...');

(function() {
    'use strict';

    console.log('🚀 [AudioMonitorHelper] IIFE ejecutándose...');

    // Variable global que Dart leerá
    window.currentAudioLevel = 0.0;

    // Estado global del monitor
    let activeMonitor = null;

    // Clase que encapsula TODO el monitor de audio
    class AudioMonitor {
        constructor(stream) {
            console.log('🔊 [AudioMonitor] Inicializando con stream:', stream);

            this.stream = stream;
            this.isActive = false;
            this.intervalId = null;

            this.context = null;
            this.source = null;
            this.analyser = null;
            this.dataArray = null;

            this.lastLevel = 0;
            this.callCount = 0;

            this._init();
        }

        _init() {
            try {
                // 1. Crear AudioContext
                const AudioContextClass = window.AudioContext || window.webkitAudioContext;
                if (!AudioContextClass) {
                    throw new Error('AudioContext no soportado en este navegador');
                }

                this.context = new AudioContextClass();
                console.log('✓ [AudioMonitor] AudioContext creado:', this.context);

                // 2. Crear source desde MediaStream
                this.source = this.context.createMediaStreamSource(this.stream);
                console.log('✓ [AudioMonitor] MediaStreamSource creado');

                // 3. Crear y configurar analyser
                this.analyser = this.context.createAnalyser();
                this.analyser.fftSize = 512;
                this.analyser.smoothingTimeConstant = 0.22;
                console.log('✓ [AudioMonitor] Analyser configurado');

                // 4. Conectar
                this.source.connect(this.analyser);
                console.log('✓ [AudioMonitor] Source conectado a analyser');

                // 5. Preparar buffer para datos
                this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);
                console.log('✓ [AudioMonitor] Buffer creado, tamaño:', this.dataArray.length);

                // 6. Iniciar loop de lectura
                this.start();

                console.log('✅ [AudioMonitor] Inicialización COMPLETA');

            } catch (error) {
                console.error('❌ [AudioMonitor] Error en inicialización:', error);
                console.error(error.stack);
                this.cleanup();
                throw error;
            }
        }

        start() {
            if (this.isActive) {
                console.warn('⚠️ [AudioMonitor] Ya está activo');
                return;
            }

            this.isActive = true;

            // Iniciar loop que lee niveles cada 16ms (~60 FPS)
            this.intervalId = setInterval(() => this._readLevel(), 16);

            console.log('▶️ [AudioMonitor] Loop iniciado (16ms)');
        }

        _readLevel() {
            if (!this.isActive || !this.analyser || !this.dataArray) {
                return;
            }

            this.callCount++;

            try {
                // Leer datos del analyser
                this.analyser.getByteTimeDomainData(this.dataArray);

                // Calcular RMS (Root Mean Square)
                let sum = 0;
                for (let i = 0; i < this.dataArray.length; i++) {
                    const normalized = (this.dataArray[i] - 128) / 128.0;
                    sum += normalized * normalized;
                }

                const rms = Math.sqrt(sum / this.dataArray.length);
                const level = Math.min(1.0, Math.max(0.0, rms * 1.35));

                // Aplicar smoothing (easing)
                const eased = (this.lastLevel * 0.28) + (level * 0.72);
                this.lastLevel = eased;

                // ESCRIBIR en variable global que Dart leerá
                window.currentAudioLevel = eased;

                // Log cada segundo
                if (this.callCount % 60 === 0) {
                    console.log('🎵 [AudioMonitor] Nivel:', (eased * 100).toFixed(1) + '%', 'Llamadas:', this.callCount);
                }

                // Primera llamada
                if (this.callCount === 1) {
                    console.log('✅ [AudioMonitor] Primera lectura exitosa, nivel:', (eased * 100).toFixed(1) + '%');
                    console.log('✅ [AudioMonitor] window.currentAudioLevel está siendo actualizado');
                }

            } catch (error) {
                if (this.callCount === 1) {
                    console.error('❌ [AudioMonitor] Error leyendo nivel:', error);
                }
            }
        }

        stop() {
            if (!this.isActive) {
                return;
            }

            this.isActive = false;

            if (this.intervalId) {
                clearInterval(this.intervalId);
                this.intervalId = null;
            }

            // Resetear nivel
            window.currentAudioLevel = 0.0;

            console.log('⏸️ [AudioMonitor] Loop detenido');
        }
    };

        cleanup() {
            console.log('🧹 [AudioMonitor] Limpiando recursos...');

            this.stop();

            if (this.source) {
                try {
                    this.source.disconnect();
                    console.log('✓ [AudioMonitor] Source desconectado');
                } catch (e) {
                    console.warn('⚠️ [AudioMonitor] Error desconectando source:', e);
                }
                this.source = null;
            }

            this.analyser = null;
            this.dataArray = null;

            if (this.context && this.context.state !== 'closed') {
                this.context.close()
                    .then(() => console.log('✓ [AudioMonitor] AudioContext cerrado'))
                    .catch(e => console.warn('⚠️ [AudioMonitor] Error cerrando context:', e));
                this.context = null;
            }

            console.log('✅ [AudioMonitor] Cleanup completado');
        }
    }

    // API Pública

    /**
     * Inicia el monitor de audio
     * @param {MediaStream} stream - Stream de audio del micrófono
     * @returns {boolean} true si se inició correctamente
     */
    window.startAudioMonitor = function(stream) {
        console.log('🎬 [startAudioMonitor] Llamado con stream:', stream);

        // Detener monitor anterior si existe
        if (activeMonitor) {
            console.log('⚠️ [startAudioMonitor] Monitor anterior existe, limpiando...');
            activeMonitor.cleanup();
            activeMonitor = null;
        }

        if (!stream) {
            console.error('❌ [startAudioMonitor] Stream es null');
            return false;
        }

        try {
            activeMonitor = new AudioMonitor(stream);
            console.log('✅ [startAudioMonitor] Monitor creado y activo');
            console.log('ℹ️ [startAudioMonitor] Dart debe leer window.currentAudioLevel periódicamente');
            return true;
        } catch (error) {
            console.error('❌ [startAudioMonitor] Error creando monitor:', error);
            activeMonitor = null;
            return false;
        }
    };

    /**
     * Detiene el monitor de audio
     */
    window.stopAudioMonitor = function() {
        console.log('🛑 [stopAudioMonitor] Llamado');

        if (activeMonitor) {
            activeMonitor.cleanup();
            activeMonitor = null;
            console.log('✅ [stopAudioMonitor] Monitor detenido');
        } else {
            console.log('ℹ️ [stopAudioMonitor] No hay monitor activo');
        }
    };

    console.log('✅ [AudioMonitorHelper] Funciones globales registradas: startAudioMonitor, stopAudioMonitor');
    console.log('ℹ️ [AudioMonitorHelper] Dart leerá window.currentAudioLevel para obtener niveles');

})();
