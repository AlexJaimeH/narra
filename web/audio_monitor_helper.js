// Audio Monitor Helper for Narra - VERSIÓN OPTIMIZADA SIN LOGS
// JavaScript calcula niveles y los expone en window.currentAudioLevel
// Dart lee periódicamente con un Timer

(function() {
    'use strict';

    // Variable global que Dart leerá
    window.currentAudioLevel = 0.0;

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

    // Función para limpiar recursos
    function cleanupResources() {
        if (monitorState.intervalId) {
            clearInterval(monitorState.intervalId);
            monitorState.intervalId = null;
        }

        if (monitorState.source) {
            try {
                monitorState.source.disconnect();
            } catch (e) {
                // Silenciar error
            }
            monitorState.source = null;
        }

        monitorState.analyser = null;
        monitorState.dataArray = null;

        if (monitorState.context && monitorState.context.state !== 'closed') {
            monitorState.context.close().catch(function() {});
            monitorState.context = null;
        }

        monitorState.isActive = false;
        monitorState.lastLevel = 0;
        monitorState.callCount = 0;
        window.currentAudioLevel = 0.0;
    }

    // Función para leer nivel de audio
    function readAudioLevel() {
        if (!monitorState.isActive || !monitorState.analyser || !monitorState.dataArray) {
            return;
        }

        monitorState.callCount++;

        try {
            monitorState.analyser.getByteTimeDomainData(monitorState.dataArray);

            let sum = 0;
            for (let i = 0; i < monitorState.dataArray.length; i++) {
                const normalized = (monitorState.dataArray[i] - 128) / 128.0;
                sum += normalized * normalized;
            }

            const rms = Math.sqrt(sum / monitorState.dataArray.length);
            const level = Math.min(1.0, Math.max(0.0, rms * 1.35));

            const eased = (monitorState.lastLevel * 0.28) + (level * 0.72);
            monitorState.lastLevel = eased;

            window.currentAudioLevel = eased;

        } catch (error) {
            // Silenciar error
        }
    }

    // Función para iniciar el monitor
    function initializeMonitor(stream) {
        try {
            const AudioContextClass = window.AudioContext || window.webkitAudioContext;
            if (!AudioContextClass) {
                return false;
            }

            monitorState.context = new AudioContextClass();
            monitorState.source = monitorState.context.createMediaStreamSource(stream);
            monitorState.analyser = monitorState.context.createAnalyser();
            monitorState.analyser.fftSize = 512;
            monitorState.analyser.smoothingTimeConstant = 0.22;
            monitorState.source.connect(monitorState.analyser);
            monitorState.dataArray = new Uint8Array(monitorState.analyser.frequencyBinCount);
            monitorState.isActive = true;
            monitorState.stream = stream;
            monitorState.intervalId = setInterval(readAudioLevel, 16);

            return true;

        } catch (error) {
            cleanupResources();
            return false;
        }
    }

    // Función para extraer MediaStream nativo de DartObject
    function unwrapMediaStream(stream) {
        if (stream && typeof stream === 'object') {
            if (stream.o && stream.o instanceof MediaStream) {
                return stream.o;
            }
            if (stream instanceof MediaStream) {
                return stream;
            }
            if (stream._nativeObject instanceof MediaStream) {
                return stream._nativeObject;
            }
        }
        return stream;
    }

    // API Pública: startAudioMonitor
    window.startAudioMonitor = function(stream) {
        if (monitorState.isActive) {
            cleanupResources();
        }

        if (!stream) {
            return false;
        }

        const nativeStream = unwrapMediaStream(stream);
        return initializeMonitor(nativeStream);
    };

    // API Pública: stopAudioMonitor
    window.stopAudioMonitor = function() {
        if (monitorState.isActive) {
            cleanupResources();
        }
    };

})();
