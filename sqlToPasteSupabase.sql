-- ============================================================
-- Crear bucket para grabaciones de voz
-- ============================================================
--
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard
-- 2. Ve a la sección "Storage"
-- 3. Haz clic en "Create a new bucket"
-- 4. Configura así:
--    - Name: voice-recordings
--    - Public bucket: ✅ ACTIVADO (para que los audios sean accesibles públicamente)
-- 5. Haz clic en "Create bucket"
--
-- 6. Luego, ve a la sección "SQL Editor" y pega el siguiente SQL
--    para crear las políticas de seguridad:
--
-- ============================================================

-- Política 1: Permitir que usuarios autenticados suban archivos a su propia carpeta
CREATE POLICY "Users can upload their own voice recordings"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'voice-recordings'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Política 2: Permitir que usuarios autenticados eliminen sus propios archivos
CREATE POLICY "Users can delete their own voice recordings"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'voice-recordings'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Política 3: Permitir lectura pública de todos los archivos (ya que el bucket es público)
-- Esta política puede no ser necesaria si el bucket es público,
-- pero la incluimos por si acaso
CREATE POLICY "Public access to voice recordings"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'voice-recordings');

-- Política 4: Permitir que usuarios autenticados actualicen sus propios archivos
CREATE POLICY "Users can update their own voice recordings"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'voice-recordings'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'voice-recordings'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- RESUMEN DE PERMISOS:
-- ============================================================
-- ✅ Usuarios autenticados pueden:
--    - Subir archivos a su propia carpeta (user_id/...)
--    - Eliminar sus propios archivos
--    - Actualizar sus propios archivos
--
-- ✅ Usuarios públicos pueden:
--    - Leer/descargar cualquier archivo (para reproducir audios)
--
-- ❌ Usuarios NO pueden:
--    - Subir archivos a carpetas de otros usuarios
--    - Eliminar archivos de otros usuarios
-- ============================================================
