window.generateZipFromData = async function(jsonData) {
    try {
        const data = JSON.parse(jsonData);
        const zip = new JSZip();

        // Helper functions
        function stripHtml(html) {
            return html
                .replace(/<br\s*\/?>/gi, '\n')
                .replace(/<\/p>/gi, '\n\n')
                .replace(/<[^>]+>/g, '')
                .replace(/&nbsp;/g, ' ')
                .replace(/&amp;/g, '&')
                .replace(/&lt;/g, '<')
                .replace(/&gt;/g, '>')
                .replace(/&quot;/g, '"')
                .trim();
        }

        function sanitizeFileName(name) {
            return name
                .replace(/[<>:"/\\|?*]/g, '-')
                .replace(/\s+/g, ' ')
                .trim()
                .substring(0, 200);
        }

        function formatDate(dateString) {
            const date = new Date(dateString);
            return date.toLocaleString('es-ES', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        }

        // Add info.txt
        zip.file('info.txt', JSON.stringify(data.metadata, null, 2));

        // Process each story
        for (const historia of data.historias) {
            const folderPrefix = historia.is_published ? 'publicadas/' : 'borradores/';
            const storyTitle = sanitizeFileName(historia.titulo);
            const storyPath = folderPrefix + storyTitle + '/';

            // Create story text
            let storyText = '═'.repeat(80) + '\n';
            storyText += `  ${historia.titulo}\n`;
            storyText += '═'.repeat(80) + '\n\n';

            storyText += `📝 Creada: ${formatDate(historia.fecha_creacion)}\n`;
            storyText += `✏️  Última edición: ${formatDate(historia.fecha_actualizacion)}\n`;
            if (historia.is_published && historia.fecha_publicacion) {
                storyText += `📤 Publicada: ${formatDate(historia.fecha_publicacion)}\n`;
            }
            storyText += `📊 Estado: ${historia.is_published ? 'Publicada' : 'Borrador'}\n`;

            storyText += '\n' + '─'.repeat(80) + '\n\n';

            if (historia.extracto) {
                storyText += 'EXTRACTO:\n' + historia.extracto + '\n\n';
                storyText += '─'.repeat(80) + '\n\n';
            }

            storyText += 'CONTENIDO:\n\n';
            storyText += stripHtml(historia.contenido);

            storyText += '\n\n' + '═'.repeat(80);

            zip.file(storyPath + 'historia.txt', storyText);

            // Download and add photos
            if (historia.fotos && historia.fotos.length > 0) {
                const photosFolder = storyPath + 'imagenes/';
                for (let i = 0; i < historia.fotos.length; i++) {
                    const foto = historia.fotos[i];
                    try {
                        if (!foto.url) {
                            console.warn('Foto sin URL:', foto);
                            continue;
                        }
                        const response = await fetch(foto.url);
                        if (response.ok) {
                            const blob = await response.blob();
                            const extension = foto.url.split('.').pop().split('?')[0] || 'jpg';
                            const photoName = `foto_${i + 1}.${extension}`;
                            zip.file(photosFolder + photoName, blob);

                            if (foto.caption) {
                                const captionName = `foto_${i + 1}_caption.txt`;
                                zip.file(photosFolder + captionName, foto.caption);
                            }
                        }
                    } catch (e) {
                        console.warn('Error downloading photo:', foto.url, e);
                    }
                }
            }

            // Download and add voice recordings
            if (historia.grabaciones && historia.grabaciones.length > 0) {
                const recordingsFolder = storyPath + 'grabaciones/';
                for (let i = 0; i < historia.grabaciones.length; i++) {
                    const grabacion = historia.grabaciones[i];
                    try {
                        if (!grabacion.url) {
                            console.warn('Grabación sin URL:', grabacion);
                            continue;
                        }
                        const response = await fetch(grabacion.url);
                        if (response.ok) {
                            const blob = await response.blob();
                            const extension = grabacion.url.split('.').pop().split('?')[0] || 'mp3';
                            const recordingName = `grabacion_${i + 1}.${extension}`;
                            zip.file(recordingsFolder + recordingName, blob);

                            if (grabacion.transcripcion) {
                                const transcriptName = `grabacion_${i + 1}_transcripcion.txt`;
                                let transcriptText = `Grabación: ${grabacion.titulo || 'Sin título'}\n`;
                                transcriptText += `Fecha: ${formatDate(grabacion.fecha)}\n`;
                                if (grabacion.duracion) {
                                    const minutos = Math.floor(grabacion.duracion / 60);
                                    const segundos = Math.floor(grabacion.duracion % 60);
                                    const seg = segundos < 10 ? '0' + segundos : String(segundos);
                                    transcriptText += `Duración: ${minutos}:${seg}\n`;
                                }
                                transcriptText += `\n${'─'.repeat(40)}\n\n`;
                                transcriptText += grabacion.transcripcion;
                                zip.file(recordingsFolder + transcriptName, transcriptText);
                            }
                        }
                    } catch (e) {
                        console.warn('Error downloading recording:', grabacion.url, e);
                    }
                }
            }

            // Add version history
            if (historia.versiones && historia.versiones.length > 0) {
                const versionsFolder = storyPath + 'versiones/';
                for (let i = 0; i < historia.versiones.length; i++) {
                    const version = historia.versiones[i];
                    let versionText = `Versión ${i + 1}\n`;
                    versionText += '═'.repeat(80) + '\n\n';
                    versionText += `Guardada: ${formatDate(version.fecha)}\n`;
                    if (version.razon) {
                        versionText += `Razón: ${version.razon}\n`;
                    }
                    versionText += '\n' + '─'.repeat(80) + '\n\n';
                    versionText += `TÍTULO: ${version.titulo}\n\n`;
                    versionText += '─'.repeat(80) + '\n\n';
                    versionText += stripHtml(version.contenido);
                    versionText += '\n\n' + '═'.repeat(80);

                    const num = i + 1;
                    const numStr = num < 10 ? '00' + num : (num < 100 ? '0' + num : String(num));
                    const versionName = `version_${numStr}.txt`;
                    zip.file(versionsFolder + versionName, versionText);
                }
            }
        }

        // Generate ZIP
        const blob = await zip.generateAsync({type: 'blob'});

        // Generate filename
        const now = new Date();
        const yy = String(now.getFullYear()).slice(-2);
        const month = now.getMonth() + 1;
        const mm = month < 10 ? '0' + month : String(month);
        const day = now.getDate();
        const dd = day < 10 ? '0' + day : String(day);
        const sanitizedName = sanitizeFileName(data.metadata.nombre);
        const filename = `${yy}${mm}${dd} Narra - ${sanitizedName}.zip`;

        // Download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);

        return 'success';
    } catch (error) {
        console.error('Error generating ZIP:', error);
        return 'error: ' + error.message;
    }
};
