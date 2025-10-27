-- ============================================================
-- CONFIGURACIÓN COMPLETA PARA GRABACIONES DE VOZ
-- ============================================================
--
-- INSTRUCCIONES:
--
-- PARTE 1: Crear el bucket (interfaz web)
-- ==========================================
-- 1. Ve a Supabase Dashboard
-- 2. Ve a la sección "Storage"
-- 3. Haz clic en "Create a new bucket"
-- 4. Configura así:
--    - Name: voice-recordings
--    - Public bucket: ✅ ACTIVADO (para que los audios sean accesibles públicamente)
-- 5. Haz clic en "Create bucket"
--
-- PARTE 2: Ejecutar este SQL (SQL Editor)
-- ==========================================
-- 6. Ve a la sección "SQL Editor"
-- 7. Copia y pega TODO el SQL de abajo
-- 8. Haz clic en "Run"
--
-- ============================================================

-- ============================================================
-- 1. CREAR TABLA voice_recordings
-- ============================================================

CREATE TABLE IF NOT EXISTS voice_recordings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  story_title TEXT,
  audio_url TEXT NOT NULL,
  audio_path TEXT NOT NULL,
  storage_bucket TEXT DEFAULT 'voice-recordings',
  transcript TEXT NOT NULL DEFAULT '',
  duration_seconds NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Crear índices para mejor performance
CREATE INDEX IF NOT EXISTS idx_voice_recordings_user_id ON voice_recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_recordings_story_id ON voice_recordings(story_id);
CREATE INDEX IF NOT EXISTS idx_voice_recordings_created_at ON voice_recordings(created_at DESC);

-- ============================================================
-- 2. HABILITAR ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE voice_recordings ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. POLÍTICAS RLS PARA LA TABLA voice_recordings
-- ============================================================

-- Política 1: Los usuarios pueden ver sus propias grabaciones
CREATE POLICY "Users can view their own voice recordings"
ON voice_recordings
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Política 2: Los usuarios pueden insertar sus propias grabaciones
CREATE POLICY "Users can insert their own voice recordings"
ON voice_recordings
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Política 3: Los usuarios pueden actualizar sus propias grabaciones
CREATE POLICY "Users can update their own voice recordings"
ON voice_recordings
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Política 4: Los usuarios pueden eliminar sus propias grabaciones
CREATE POLICY "Users can delete their own voice recordings"
ON voice_recordings
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================================
-- 4. POLÍTICAS DE STORAGE PARA EL BUCKET voice-recordings
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
CREATE POLICY "Users can delete their own voice recording files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'voice-recordings'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Política 3: Permitir lectura pública de todos los archivos (ya que el bucket es público)
CREATE POLICY "Public access to voice recording files"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'voice-recordings');

-- Política 4: Permitir que usuarios autenticados actualicen sus propios archivos
CREATE POLICY "Users can update their own voice recording files"
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
-- 5. FUNCIÓN PARA ACTUALIZAR updated_at AUTOMÁTICAMENTE
-- ============================================================

CREATE OR REPLACE FUNCTION update_voice_recordings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualizar updated_at
DROP TRIGGER IF EXISTS trigger_update_voice_recordings_updated_at ON voice_recordings;
CREATE TRIGGER trigger_update_voice_recordings_updated_at
  BEFORE UPDATE ON voice_recordings
  FOR EACH ROW
  EXECUTE FUNCTION update_voice_recordings_updated_at();

-- ============================================================
-- RESUMEN DE PERMISOS
-- ============================================================
--
-- TABLA voice_recordings:
-- ✅ Usuarios autenticados pueden:
--    - Ver sus propias grabaciones
--    - Crear nuevas grabaciones
--    - Actualizar sus grabaciones
--    - Eliminar sus grabaciones
--
-- ❌ Usuarios NO pueden:
--    - Ver, editar o eliminar grabaciones de otros usuarios
--
-- STORAGE bucket voice-recordings:
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
