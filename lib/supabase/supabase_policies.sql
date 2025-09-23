-- Habilitar RLS en todas las tablas
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE people ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_people ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;

-- Políticas para la tabla users
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own profile' AND tablename = 'users') THEN
        CREATE POLICY "Users can view own profile" ON users
          FOR SELECT USING (auth.uid() = id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own profile' AND tablename = 'users') THEN
        CREATE POLICY "Users can insert own profile" ON users
          FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own profile' AND tablename = 'users') THEN
        CREATE POLICY "Users can update own profile" ON users
          FOR UPDATE USING (auth.uid() = id) WITH CHECK (true);
    END IF;
END $$;

-- Políticas para la tabla stories
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own stories' AND tablename = 'stories') THEN
        CREATE POLICY "Users can view own stories" ON stories
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own stories' AND tablename = 'stories') THEN
        CREATE POLICY "Users can insert own stories" ON stories
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own stories' AND tablename = 'stories') THEN
        CREATE POLICY "Users can update own stories" ON stories
          FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own stories' AND tablename = 'stories') THEN
        CREATE POLICY "Users can delete own stories" ON stories
          FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Políticas para la tabla tags
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own tags' AND tablename = 'tags') THEN
        CREATE POLICY "Users can view own tags" ON tags
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own tags' AND tablename = 'tags') THEN
        CREATE POLICY "Users can insert own tags" ON tags
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own tags' AND tablename = 'tags') THEN
        CREATE POLICY "Users can update own tags" ON tags
          FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own tags' AND tablename = 'tags') THEN
        CREATE POLICY "Users can delete own tags" ON tags
          FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Políticas para la tabla story_tags
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own story tags' AND tablename = 'story_tags') THEN
        CREATE POLICY "Users can view own story tags" ON story_tags
          FOR SELECT USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own story tags' AND tablename = 'story_tags') THEN
        CREATE POLICY "Users can insert own story tags" ON story_tags
          FOR INSERT WITH CHECK (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own story tags' AND tablename = 'story_tags') THEN
        CREATE POLICY "Users can delete own story tags" ON story_tags
          FOR DELETE USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
END $$;

-- Políticas para la tabla story_photos
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own story photos' AND tablename = 'story_photos') THEN
        CREATE POLICY "Users can view own story photos" ON story_photos
          FOR SELECT USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own story photos' AND tablename = 'story_photos') THEN
        CREATE POLICY "Users can insert own story photos" ON story_photos
          FOR INSERT WITH CHECK (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own story photos' AND tablename = 'story_photos') THEN
        CREATE POLICY "Users can update own story photos" ON story_photos
          FOR UPDATE USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own story photos' AND tablename = 'story_photos') THEN
        CREATE POLICY "Users can delete own story photos" ON story_photos
          FOR DELETE USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
END $$;

-- Políticas para la tabla people
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own people' AND tablename = 'people') THEN
        CREATE POLICY "Users can view own people" ON people
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own people' AND tablename = 'people') THEN
        CREATE POLICY "Users can insert own people" ON people
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own people' AND tablename = 'people') THEN
        CREATE POLICY "Users can update own people" ON people
          FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own people' AND tablename = 'people') THEN
        CREATE POLICY "Users can delete own people" ON people
          FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Políticas para la tabla story_people
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own story people' AND tablename = 'story_people') THEN
        CREATE POLICY "Users can view own story people" ON story_people
          FOR SELECT USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own story people' AND tablename = 'story_people') THEN
        CREATE POLICY "Users can insert own story people" ON story_people
          FOR INSERT WITH CHECK (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own story people' AND tablename = 'story_people') THEN
        CREATE POLICY "Users can delete own story people" ON story_people
          FOR DELETE USING (
            auth.uid() IN (
              SELECT user_id FROM stories WHERE id = story_id
            )
          );
    END IF;
END $$;

-- Políticas para la tabla subscribers
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own subscribers' AND tablename = 'subscribers') THEN
        CREATE POLICY "Users can view own subscribers" ON subscribers
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own subscribers' AND tablename = 'subscribers') THEN
        CREATE POLICY "Users can insert own subscribers" ON subscribers
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own subscribers' AND tablename = 'subscribers') THEN
        CREATE POLICY "Users can update own subscribers" ON subscribers
          FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own subscribers' AND tablename = 'subscribers') THEN
        CREATE POLICY "Users can delete own subscribers" ON subscribers
          FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Políticas para la tabla user_settings
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own settings' AND tablename = 'user_settings') THEN
        CREATE POLICY "Users can view own settings" ON user_settings
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own settings' AND tablename = 'user_settings') THEN
        CREATE POLICY "Users can insert own settings" ON user_settings
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own settings' AND tablename = 'user_settings') THEN
        CREATE POLICY "Users can update own settings" ON user_settings
          FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Políticas para la tabla user_activity
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own activity' AND tablename = 'user_activity') THEN
        CREATE POLICY "Users can view own activity" ON user_activity
          FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own activity' AND tablename = 'user_activity') THEN
        CREATE POLICY "Users can insert own activity" ON user_activity
          FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;