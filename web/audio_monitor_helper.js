// Audio Monitor Helper for Narra
// Expone funciones globales para monitorear niveles de audio desde MediaStream
// Usado por voice_recorder_web.dart

window.audioMonitorSetup = function(stream) {
    try {
        console.log('🔊 [AudioMonitorHelper] Iniciando setup con MediaStream:', stream);

        // 1. Crear AudioContext
        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) {
            console.error('❌ [AudioMonitorHelper] AudioContext no disponible');
            return null;
        }

        const ctx = new AudioContextClass();
        console.log('✓ [AudioMonitorHelper] AudioContext creado');

        // 2. Crear source node desde MediaStream
        const source = ctx.createMediaStreamSource(stream);
        console.log('✓ [AudioMonitorHelper] MediaStreamSource creado');

        // 3. Crear analyser node
        const analyser = ctx.createAnalyser();
        analyser.fftSize = 512;
        analyser.smoothingTimeConstant = 0.22;
        console.log('✓ [AudioMonitorHelper] Analyser configurado (fftSize=512)');

        // 4. Conectar source a analyser
        source.connect(analyser);
        console.log('✓ [AudioMonitorHelper] Source conectado a analyser');

        // 5. Retornar objeto con todas las referencias necesarias
        const result = {
            context: ctx,
            source: source,
            analyser: analyser,
            bufferSize: analyser.frequencyBinCount
        };

        console.log('✅ [AudioMonitorHelper] Setup completado exitosamente. Buffer size:', result.bufferSize);
        return result;

    } catch (error) {
        console.error('❌ [AudioMonitorHelper] Error en setup:', error);
        console.error('Stack:', error.stack);
        return null;
    }
};

// Función auxiliar para obtener datos de audio del analyser
// El buffer (Uint8List de Dart) se pasa por referencia y se modifica in-place
window.audioMonitorGetData = function(analyser, buffer) {
    try {
        if (!analyser || !buffer) {
            return false;
        }
        analyser.getByteTimeDomainData(buffer);
        return true;
    } catch (error) {
        console.error('❌ [AudioMonitorHelper] Error obteniendo datos:', error);
        return false;
    }
};

// Función auxiliar para desconectar y limpiar recursos
window.audioMonitorCleanup = function(setup) {
    try {
        if (!setup) {
            return;
        }

        if (setup.source) {
            setup.source.disconnect();
            console.log('✓ [AudioMonitorHelper] Source desconectado');
        }

        if (setup.context && setup.context.state !== 'closed') {
            setup.context.close().then(function() {
                console.log('✓ [AudioMonitorHelper] AudioContext cerrado');
            }).catch(function(error) {
                console.warn('⚠️ [AudioMonitorHelper] Error cerrando AudioContext:', error);
            });
        }
    } catch (error) {
        console.warn('⚠️ [AudioMonitorHelper] Error en cleanup:', error);
    }
};

console.log('✅ [AudioMonitorHelper] Funciones globales registradas: audioMonitorSetup, audioMonitorGetData, audioMonitorCleanup');
