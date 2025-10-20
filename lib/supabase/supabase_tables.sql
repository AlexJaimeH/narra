-- Tabla de usuarios (perfiles)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  birth_date DATE,
  phone TEXT,
  location TEXT,
  bio TEXT,
  avatar_url TEXT,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  plan_expires_at TIMESTAMPTZ,
  writing_tone TEXT DEFAULT 'warm' CHECK (writing_tone IN ('formal', 'warm', 'nostalgic', 'humorous')),
  stories_written INTEGER DEFAULT 0,
  words_written INTEGER DEFAULT 0,
  ai_queries_used INTEGER DEFAULT 0,
  ai_queries_limit INTEGER DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de historias
CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  date_type TEXT DEFAULT 'approximate' CHECK (date_type IN ('exact', 'month_year', 'year', 'approximate')),
  dates_precision TEXT DEFAULT 'approximate' CHECK (dates_precision IN ('exact', 'month_year', 'year', 'approximate')),
  story_date DATE,
  story_date_text TEXT, -- Para fechas aproximadas como "Verano del 82"
  location TEXT,
  is_voice_generated BOOLEAN DEFAULT FALSE,
  voice_transcript TEXT,
  ai_suggestions TEXT[], -- Array de sugerencias de IA
  completeness_score INTEGER DEFAULT 0 CHECK (completeness_score >= 0 AND completeness_score <= 100),
  word_count INTEGER DEFAULT 0,
  reading_time INTEGER DEFAULT 0, -- en minutos
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  published_at TIMESTAMPTZ
);

-- Tabla de etiquetas
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#3498db',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- Tabla de relación historia-etiquetas
CREATE TABLE IF NOT EXISTS story_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(story_id, tag_id)
);

-- Tabla de fotos
CREATE TABLE IF NOT EXISTS story_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  caption TEXT,
  position INTEGER DEFAULT 0, -- Para ordenar las fotos en la historia
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de historial de versiones de historias
CREATE TABLE IF NOT EXISTS story_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  tags JSONB NOT NULL DEFAULT '[]'::jsonb,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  dates_precision TEXT,
  photos JSONB NOT NULL DEFAULT '[]'::jsonb,
  saved_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS story_versions_story_id_saved_at_idx
  ON story_versions(story_id, saved_at DESC);

-- Tabla de personas mencionadas en historias
CREATE TABLE IF NOT EXISTS people (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  relationship TEXT, -- padre, madre, hermano, amigo, etc.
  birth_date DATE,
  notes TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- Tabla de relación historia-personas
CREATE TABLE IF NOT EXISTS story_people (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(story_id, person_id)
);

-- Tabla de suscriptores (para compartir historias)
CREATE TABLE IF NOT EXISTS subscribers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  relationship TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'unsubscribed')),
  last_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, email)
);

-- Tabla de configuraciones de usuario
CREATE TABLE IF NOT EXISTS user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  auto_save BOOLEAN DEFAULT TRUE,
  notification_stories BOOLEAN DEFAULT TRUE,
  notification_reminders BOOLEAN DEFAULT TRUE,
  sharing_enabled BOOLEAN DEFAULT FALSE,
  language TEXT DEFAULT 'es',
  font_family TEXT DEFAULT 'Montserrat',
  text_scale NUMERIC DEFAULT 1.0,
  high_contrast BOOLEAN DEFAULT FALSE,
  reduce_motion BOOLEAN DEFAULT FALSE,
  ai_extra_instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Tabla para tracking de actividad
CREATE TABLE IF NOT EXISTS user_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('story_created', 'story_updated', 'story_published', 'photo_added', 'person_added', 'voice_recorded')),
  entity_id UUID, -- ID de la historia, foto, persona, etc.
  metadata JSONB, -- Datos adicionales sobre la actividad
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_status ON stories(status);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_story_photos_story_id ON story_photos(story_id);
CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id);
CREATE INDEX IF NOT EXISTS idx_people_user_id ON people(user_id);
CREATE INDEX IF NOT EXISTS idx_subscribers_user_id ON subscribers(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_created_at ON user_activity(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier);

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers only if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_users_updated_at') THEN
        CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_stories_updated_at') THEN
        CREATE TRIGGER update_stories_updated_at BEFORE UPDATE ON stories FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_settings_updated_at') THEN
        CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    END IF;
END $$;