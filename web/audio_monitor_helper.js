// Audio Monitor Helper for Narra - VERSIÓN POLLING REESCRITA
// JavaScript calcula niveles y los expone en window.currentAudioLevel
// Dart lee periódicamente con un Timer

console.log('🚀 [AudioMonitorHelper] === INICIANDO CARGA DEL SCRIPT ===');

(function() {
    'use strict';

    console.log('🚀 [AudioMonitorHelper] IIFE ejecutándose correctamente');

    // Variable global que Dart leerá
    window.currentAudioLevel = 0.0;
    console.log('✓ [AudioMonitorHelper] window.currentAudioLevel inicializado en 0.0');

    // Estado del monitor actual
    let monitorState = {
        stream: null,
        context: null,
        source: null,
        analyser: null,
        dataArray: null,
        intervalId: null,
        isActive: false,
        lastLevel: 0,
        callCount: 0
    };

    console.log('✓ [AudioMonitorHelper] Estado del monitor inicializado');

    // Función para limpiar recursos
    function cleanupResources() {
        console.log('🧹 [AudioMonitorHelper] Limpiando recursos...');

        // Detener interval
        if (monitorState.intervalId) {
            clearInterval(monitorState.intervalId);
            monitorState.intervalId = null;
            console.log('  ✓ Interval detenido');
        }

        // Desconectar source
        if (monitorState.source) {
            try {
                monitorState.source.disconnect();
                console.log('  ✓ Source desconectado');
            } catch (e) {
                console.warn('  ⚠️ Error desconectando source:', e);
            }
            monitorState.source = null;
        }

        // Limpiar analyser
        monitorState.analyser = null;
        monitorState.dataArray = null;

        // Cerrar AudioContext
        if (monitorState.context && monitorState.context.state !== 'closed') {
            monitorState.context.close()
                .then(function() {
                    console.log('  ✓ AudioContext cerrado');
                })
                .catch(function(e) {
                    console.warn('  ⚠️ Error cerrando AudioContext:', e);
                });
            monitorState.context = null;
        }

        // Resetear estado
        monitorState.isActive = false;
        monitorState.lastLevel = 0;
        monitorState.callCount = 0;
        window.currentAudioLevel = 0.0;

        console.log('✅ [AudioMonitorHelper] Recursos limpiados completamente');
    }

    // Función para leer nivel de audio
    function readAudioLevel() {
        if (!monitorState.isActive || !monitorState.analyser || !monitorState.dataArray) {
            return;
        }

        monitorState.callCount++;

        try {
            // Leer datos del analyser
            monitorState.analyser.getByteTimeDomainData(monitorState.dataArray);

            // Calcular RMS (Root Mean Square)
            let sum = 0;
            for (let i = 0; i < monitorState.dataArray.length; i++) {
                const normalized = (monitorState.dataArray[i] - 128) / 128.0;
                sum += normalized * normalized;
            }

            const rms = Math.sqrt(sum / monitorState.dataArray.length);
            const level = Math.min(1.0, Math.max(0.0, rms * 1.35));

            // Aplicar smoothing
            const eased = (monitorState.lastLevel * 0.28) + (level * 0.72);
            monitorState.lastLevel = eased;

            // ESCRIBIR en variable global que Dart leerá
            window.currentAudioLevel = eased;

            // Log periódico
            if (monitorState.callCount % 60 === 0) {
                console.log('🎵 [AudioMonitorHelper] Nivel:', (eased * 100).toFixed(1) + '%', 'Llamadas:', monitorState.callCount);
            }

            // Primera lectura
            if (monitorState.callCount === 1) {
                console.log('✅ [AudioMonitorHelper] Primera lectura exitosa, nivel:', (eased * 100).toFixed(1) + '%');
                console.log('✅ [AudioMonitorHelper] window.currentAudioLevel siendo actualizado correctamente');
            }

        } catch (error) {
            if (monitorState.callCount <= 3) {
                console.error('❌ [AudioMonitorHelper] Error leyendo nivel (llamada ' + monitorState.callCount + '):', error);
            }
        }
    }

    // Función para iniciar el monitor
    function initializeMonitor(stream) {
        console.log('🎬 [AudioMonitorHelper] Inicializando monitor con stream:', stream);

        try {
            // 1. Crear AudioContext
            const AudioContextClass = window.AudioContext || window.webkitAudioContext;
            if (!AudioContextClass) {
                throw new Error('AudioContext no soportado en este navegador');
            }

            monitorState.context = new AudioContextClass();
            console.log('  ✓ AudioContext creado:', monitorState.context.state);

            // 2. Crear MediaStreamSource
            monitorState.source = monitorState.context.createMediaStreamSource(stream);
            console.log('  ✓ MediaStreamSource creado');

            // 3. Crear y configurar AnalyserNode
            monitorState.analyser = monitorState.context.createAnalyser();
            monitorState.analyser.fftSize = 512;
            monitorState.analyser.smoothingTimeConstant = 0.22;
            console.log('  ✓ AnalyserNode configurado (fftSize: 512)');

            // 4. Conectar source a analyser
            monitorState.source.connect(monitorState.analyser);
            console.log('  ✓ Source conectado a analyser');

            // 5. Crear buffer para datos
            monitorState.dataArray = new Uint8Array(monitorState.analyser.frequencyBinCount);
            console.log('  ✓ Buffer creado, tamaño:', monitorState.dataArray.length);

            // 6. Marcar como activo
            monitorState.isActive = true;
            monitorState.stream = stream;

            // 7. Iniciar loop de lectura cada 16ms (~60 FPS)
            monitorState.intervalId = setInterval(readAudioLevel, 16);
            console.log('  ✓ Interval iniciado (16ms)');

            console.log('✅ [AudioMonitorHelper] Monitor inicializado y activo');
            return true;

        } catch (error) {
            console.error('❌ [AudioMonitorHelper] Error en inicialización:', error);
            console.error('   Stack:', error.stack);
            cleanupResources();
            return false;
        }
    }

    // Función para extraer MediaStream nativo de DartObject
    function unwrapMediaStream(stream) {
        console.log('🔍 [unwrapMediaStream] Inspeccionando stream...');
        console.log('   Tipo:', typeof stream);
        console.log('   Constructor:', stream?.constructor?.name);

        // Si es un DartObject de Flutter Web, extraer el stream nativo
        if (stream && typeof stream === 'object') {
            // DartObject tiene una propiedad 'o' que contiene el objeto nativo
            if (stream.o && stream.o instanceof MediaStream) {
                console.log('   ✓ Detectado DartObject, extrayendo stream.o');
                console.log('   ✓ stream.o es MediaStream:', stream.o instanceof MediaStream);
                return stream.o;
            }

            // Si ya es un MediaStream nativo, devolverlo directamente
            if (stream instanceof MediaStream) {
                console.log('   ✓ Ya es MediaStream nativo');
                return stream;
            }

            // Intentar extraer de otras propiedades posibles
            if (stream._nativeObject instanceof MediaStream) {
                console.log('   ✓ Extrayendo de _nativeObject');
                return stream._nativeObject;
            }
        }

        console.warn('   ⚠️ No se pudo extraer MediaStream nativo, devolviendo original');
        return stream;
    }

    // API Pública: startAudioMonitor
    window.startAudioMonitor = function(stream) {
        console.log('📞 [startAudioMonitor] === FUNCIÓN LLAMADA ===');
        console.log('   Stream recibido:', stream);
        console.log('   Tipo de stream:', typeof stream);

        // Limpiar monitor anterior si existe
        if (monitorState.isActive) {
            console.log('⚠️ [startAudioMonitor] Monitor anterior activo, limpiando...');
            cleanupResources();
        }

        // Validar stream
        if (!stream) {
            console.error('❌ [startAudioMonitor] Stream es null o undefined');
            return false;
        }

        // CRÍTICO: Extraer MediaStream nativo del DartObject
        const nativeStream = unwrapMediaStream(stream);
        console.log('   Stream después de unwrap:', nativeStream);
        console.log('   ¿Es MediaStream?', nativeStream instanceof MediaStream);

        // Inicializar monitor con el stream nativo
        const success = initializeMonitor(nativeStream);

        if (success) {
            console.log('✅ [startAudioMonitor] Monitor iniciado exitosamente');
            console.log('ℹ️ [startAudioMonitor] Dart debe leer window.currentAudioLevel periódicamente');
        } else {
            console.error('❌ [startAudioMonitor] Fallo al iniciar monitor');
        }

        return success;
    };

    // API Pública: stopAudioMonitor
    window.stopAudioMonitor = function() {
        console.log('🛑 [stopAudioMonitor] === FUNCIÓN LLAMADA ===');

        if (monitorState.isActive) {
            cleanupResources();
            console.log('✅ [stopAudioMonitor] Monitor detenido');
        } else {
            console.log('ℹ️ [stopAudioMonitor] No hay monitor activo');
        }
    };

    console.log('✅ [AudioMonitorHelper] === FUNCIONES GLOBALES REGISTRADAS ===');
    console.log('   - window.startAudioMonitor: disponible');
    console.log('   - window.stopAudioMonitor: disponible');
    console.log('   - window.currentAudioLevel: ' + window.currentAudioLevel);
    console.log('🚀 [AudioMonitorHelper] === SCRIPT CARGADO COMPLETAMENTE ===');

})();

console.log('🏁 [AudioMonitorHelper] Script ejecutado hasta el final');
