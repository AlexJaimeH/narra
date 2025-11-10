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

            storyText += '\n' + '─'.repeat(80) + '\n\n';

            if (historia.extracto) {
                storyText += 'EXTRACTO:\n' + historia.extracto + '\n\n';
                storyText += '─'.repeat(80) + '\n\n';
            }

            storyText += 'CONTENIDO:\n\n';
            storyText += stripHtml(historia.contenido);

            storyText += '\n\n' + '═'.repeat(80);

            zip.file(storyPath + 'historia.txt', storyText);
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
