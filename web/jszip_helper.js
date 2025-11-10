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

        function getFileExtension(url) {
            try {
                const urlObj = new URL(url);
                const pathname = urlObj.pathname;
                const match = pathname.match(/\.([a-zA-Z0-9]+)$/);
                return match ? match[1] : null;
            } catch {
                return null;
            }
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

            if (historia.fecha_historia) {
                storyText += `📅 Fecha de la historia: ${formatDate(historia.fecha_historia)}\n`;
            }
            storyText += `📝 Creada: ${formatDate(historia.fecha_creacion)}\n`;
            storyText += `✏️  Última edición: ${formatDate(historia.fecha_actualizacion)}\n`;
            if (historia.is_published && historia.fecha_publicacion) {
                storyText += `🌐 Publicada: ${formatDate(historia.fecha_publicacion)}\n`;
            }
            if (historia.numero_palabras) {
                storyText += `📊 Palabras: ${historia.numero_palabras}\n`;
            }

            storyText += '\n' + '─'.repeat(80) + '\n\n';

            if (historia.extracto) {
                storyText += 'EXTRACTO:\n' + historia.extracto + '\n\n';
                storyText += '─'.repeat(80) + '\n\n';
            }

            storyText += 'CONTENIDO:\n\n';
            storyText += stripHtml(historia.contenido);

            if (historia.transcripcion_voz) {
                storyText += '\n\n' + '─'.repeat(80) + '\n';
                storyText += 'TRANSCRIPCIÓN DE VOZ:\n\n';
                storyText += stripHtml(historia.transcripcion_voz);
            }

            storyText += '\n\n' + '═'.repeat(80);

            zip.file(storyPath + 'historia.txt', storyText);

            // Add image references
            if (historia.imagenes && historia.imagenes.length > 0) {
                for (let j = 0; j < historia.imagenes.length; j++) {
                    const img = historia.imagenes[j];
                    const extension = getFileExtension(img.url) || 'jpg';
                    const imageText = `URL de la imagen:\n${img.url}\n\nDescarga este archivo manualmente desde la URL.`;
                    zip.file(storyPath + `imagenes/imagen-${j + 1}-${extension}.txt`, imageText);
                }
            }

            // Add recording references
            if (historia.grabaciones && historia.grabaciones.length > 0) {
                for (let j = 0; j < historia.grabaciones.length; j++) {
                    const rec = historia.grabaciones[j];
                    if (rec.url) {
                        const extension = getFileExtension(rec.url) || 'mp3';
                        const audioText = `URL de la grabación:\n${rec.url}\n\nDescarga este archivo manualmente desde la URL.`;
                        zip.file(storyPath + `grabaciones/grabacion-${j + 1}-${extension}.txt`, audioText);
                    }
                }
            }

            // Add versions
            if (historia.versiones && historia.versiones.length > 0) {
                for (let j = 0; j < historia.versiones.length; j++) {
                    const version = historia.versiones[j];
                    let versionText = `VERSIÓN ${j + 1}\n`;
                    versionText += '─'.repeat(60) + '\n';
                    versionText += `Fecha: ${formatDate(version.fecha)}\n`;
                    if (version.numero) {
                        versionText += `Número de versión: ${version.numero}\n`;
                    }
                    versionText += '\nCONTENIDO:\n\n';
                    versionText += stripHtml(version.contenido);
                    zip.file(storyPath + `versiones/version-${version.numero || (j + 1)}.txt`, versionText);
                }
            }
        }

        // Generate ZIP
        const blob = await zip.generateAsync({type: 'blob'});

        // Generate filename
        const now = new Date();
        const yy = String(now.getFullYear()).slice(-2);
        const mm = String(now.getMonth() + 1).padStart(2, '0');
        const dd = String(now.getDate()).padStart(2, '0');
        const sanitizedName = sanitizeFileName(data.metadata.nombre);
        const filename = `${yy}${mm}${dd} Narra - ${sanitizedName}.zip`;

        // Download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectUrl(url);

        return 'success';
    } catch (error) {
        console.error('Error generating ZIP:', error);
        return 'error: ' + error.message;
    }
};
