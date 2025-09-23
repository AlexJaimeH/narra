CREATE OR REPLACE FUNCTION insert_user_to_auth(
    email text,
    password text
) RETURNS UUID AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  user_id := gen_random_uuid();
  encrypted_pw := crypt(password, gen_salt('bf'));
  
  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    (gen_random_uuid(), user_id, 'authenticated', 'authenticated', email, encrypted_pw, '2023-05-03 19:41:43.585805+00', '2023-04-22 13:10:03.275387+00', '2023-04-22 13:10:31.458239+00', '{"provider":"email","providers":["email"]}', '{}', '2023-05-03 19:41:43.580424+00', '2023-05-03 19:41:43.585948+00', '', '', '', '');
  
  INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id, format('{"sub":"%s","email":"%s"}', user_id::text, email)::jsonb, 'email', '2023-05-03 19:41:43.582456+00', '2023-05-03 19:41:43.582497+00', '2023-05-03 19:41:43.582497+00');
  
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;


-- Insert users into auth.users and then into the public.users table
INSERT INTO auth.users (id, email, password)
SELECT insert_user_to_auth('john.doe@example.com', 'password123') AS id, 'john.doe@example.com', 'password123'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'john.doe@example.com');

INSERT INTO auth.users (id, email, password)
SELECT insert_user_to_auth('jane.smith@example.com', 'password123') AS id, 'jane.smith@example.com', 'password123'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'jane.smith@example.com');

INSERT INTO auth.users (id, email, password)
SELECT insert_user_to_auth('peter.jones@example.com', 'password123') AS id, 'peter.jones@example.com', 'password123'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'peter.jones@example.com');

INSERT INTO public.users (id, name, email, birth_date, phone, location, bio, avatar_url, plan_type, plan_expires_at, writing_tone)
SELECT
  (SELECT id FROM auth.users WHERE email = 'john.doe@example.com'),
  'John Doe',
  'john.doe@example.com',
  '1985-05-15',
  '+1-555-123-4567',
  'New York, USA',
  'A passionate storyteller with a love for history and personal anecdotes.',
  'https://example.com/avatars/john_doe.jpg',
  'premium',
  '2024-12-31 23:59:59+00',
  'warm'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'john.doe@example.com');

INSERT INTO public.users (id, name, email, birth_date, phone, location, bio, avatar_url, plan_type, plan_expires_at, writing_tone)
SELECT
  (SELECT id FROM auth.users WHERE email = 'jane.smith@example.com'),
  'Jane Smith',
  'jane.smith@example.com',
  '1990-11-22',
  '+1-555-987-6543',
  'London, UK',
  'Enjoys capturing life''s moments through vivid stories and photos.',
  'https://example.com/avatars/jane_smith.jpg',
  'free',
  NULL,
  'formal'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'jane.smith@example.com');

INSERT INTO public.users (id, name, email, birth_date, phone, location, bio, avatar_url, plan_type, plan_expires_at, writing_tone)
SELECT
  (SELECT id FROM auth.users WHERE email = 'peter.jones@example.com'),
  'Peter Jones',
  'peter.jones@example.com',
  '1978-03-01',
  '+1-555-111-2222',
  'Sydney, Australia',
  'Loves sharing humorous tales from his travels.',
  'https://example.com/avatars/peter_jones.jpg',
  'premium',
  '2025-06-30 23:59:59+00',
  'humorous'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'peter.jones@example.com');

-- Insert user settings
INSERT INTO user_settings (user_id, auto_save, notification_stories, notification_reminders, sharing_enabled, language)
SELECT
  (SELECT id FROM public.users WHERE email = 'john.doe@example.com'),
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  'en'
WHERE NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com'));

INSERT INTO user_settings (user_id, auto_save, notification_stories, notification_reminders, sharing_enabled, language)
SELECT
  (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'),
  TRUE,
  FALSE,
  TRUE,
  FALSE,
  'es'
WHERE NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'));

INSERT INTO user_settings (user_id, auto_save, notification_stories, notification_reminders, sharing_enabled, language)
SELECT
  (SELECT id FROM public.users WHERE email = 'peter.jones@example.com'),
  FALSE,
  TRUE,
  FALSE,
  TRUE,
  'en'
WHERE NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id = (SELECT id FROM public.users WHERE email = 'peter.jones@example.com'));

-- Insert stories
INSERT INTO stories (user_id, title, content, status, date_type, story_date, story_date_text, location, is_voice_generated, ai_suggestions, completeness_score, word_count, reading_time)
SELECT
  (SELECT id FROM public.users WHERE email = 'john.doe@example.com'),
  'My First Trip to the Grand Canyon',
  'The vastness of the Grand Canyon was truly breathtaking. I remember standing at Mather Point, feeling so small yet so connected to something ancient and immense. The colors shifted with the sun, from deep reds to oranges and purples. It was an unforgettable experience that sparked my love for nature and adventure. We hiked down a portion of the Bright Angel Trail, and the scale of the canyon became even more apparent. Every turn offered a new, stunning vista. The air was crisp, and the silence was profound, broken only by the occasional chirp of a bird or the distant rush of the Colorado River. I even saw a condor soaring high above, a majestic sight.',
  'published',
  'exact',
  '2008-07-20',
  NULL,
  'Grand Canyon, Arizona, USA',
  FALSE,
  ARRAY['Add more sensory details', 'Describe the feeling of awe', 'Mention specific wildlife encountered'],
  90,
  150,
  1
WHERE NOT EXISTS (SELECT 1 FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'My First Trip to the Grand Canyon');

INSERT INTO stories (user_id, title, content, status, date_type, story_date, story_date_text, location, is_voice_generated, ai_suggestions, completeness_score, word_count, reading_time)
SELECT
  (SELECT id FROM public.users WHERE email = 'john.doe@example.com'),
  'A Childhood Summer at Grandma''s Farm',
  'Every summer, we''d pack our bags and head to Grandma''s farm. The smell of freshly cut hay, the sound of crickets at dusk, and the taste of warm apple pie are memories I cherish. We''d spend days exploring the woods, building treehouses, and helping with chores like feeding the chickens. Grandma''s stories by the fireplace were the best part of the evenings. She had a way of making even the simplest events sound like grand adventures. The old swing set under the oak tree was my favorite spot, where I''d dream away the afternoons. Those summers taught me the value of hard work and the joy of simple pleasures.',
  'published',
  'month_year',
  '1995-08-01',
  'Summer of 1995',
  'Rural Ohio, USA',
  FALSE,
  ARRAY['Elaborate on Grandma''s stories', 'Describe the farm animals', 'Add a dialogue snippet'],
  85,
  160,
  1
WHERE NOT EXISTS (SELECT 1 FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'A Childhood Summer at Grandma''s Farm');

INSERT INTO stories (user_id, title, content, status, date_type, story_date, story_date_text, location, is_voice_generated, ai_suggestions, completeness_score, word_count, reading_time)
SELECT
  (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'),
  'The Day I Met My Best Friend',
  'It was the first day of high school, and I was incredibly nervous. I bumped into Sarah in the hallway, spilling her books everywhere. We both laughed, and that awkward moment turned into an instant connection. We spent the rest of the day together, discovering we had so much in common. From that day on, we were inseparable, sharing secrets, dreams, and countless adventures. She''s been my rock through thick and thin, and I can''t imagine my life without her. We even ended up going to the same university, which was a huge relief. Our friendship is one of the greatest gifts I''ve ever received.',
  'published',
  'exact',
  '2004-09-05',
  NULL,
  'London, UK',
  FALSE,
  ARRAY['Include a specific shared memory', 'Describe Sarah''s personality', 'Add a quote about friendship'],
  95,
  140,
  1
WHERE NOT EXISTS (SELECT 1 FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND title = 'The Day I Met My Best Friend');

INSERT INTO stories (user_id, title, content, status, date_type, story_date, story_date_text, location, is_voice_generated, ai_suggestions, completeness_score, word_count, reading_time)
SELECT
  (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'),
  'A Quiet Afternoon in the Park',
  'Sometimes, the simplest moments are the most profound. I remember an afternoon spent in Hyde Park, just watching the world go by. The sun was warm, a gentle breeze rustled the leaves, and children''s laughter echoed in the distance. I sat on a bench, reading a book, and felt a sense of peace wash over me. It was a perfect escape from the hustle and bustle of city life, a reminder to slow down and appreciate the present. A squirrel even came up to me, looking for a treat, which made me smile. These small moments of tranquility are truly precious.',
  'draft',
  'approximate',
  NULL,
  'Late Spring 2022',
  'Hyde Park, London, UK',
  FALSE,
  ARRAY['Describe the book you were reading', 'Elaborate on the feeling of peace', 'Add details about the park''s atmosphere'],
  70,
  120,
  1
WHERE NOT EXISTS (SELECT 1 FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND title = 'A Quiet Afternoon in the Park');

INSERT INTO stories (user_id, title, content, status, date_type, story_date, story_date_text, location, is_voice_generated, ai_suggestions, completeness_score, word_count, reading_time)
SELECT
  (SELECT id FROM public.users WHERE email = 'peter.jones@example.com'),
  'That Time I Got Lost in Tokyo',
  'Oh, Tokyo! A city of dazzling lights and bewildering subway maps. I was convinced I had mastered the system, only to find myself on a train heading in the complete opposite direction of my hotel. Panic set in, then amusement. I ended up in a charming little neighborhood, stumbled upon a tiny ramen shop, and had the best meal of my life. Sometimes, getting lost is the best way to discover hidden gems. I eventually found my way back, but not before collecting a story that still makes me chuckle. The language barrier was a challenge, but a friendly local helped me out with gestures and a lot of patience.',
  'published',
  'year',
  '2019-01-01',
  '2019',
  'Tokyo, Japan',
  FALSE,
  ARRAY['Describe the ramen shop in more detail', 'Add a humorous dialogue', 'Mention the kindness of strangers'],
  88,
  150,
  1
WHERE NOT EXISTS (SELECT 1 FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'peter.jones@example.com') AND title = 'That Time I Got Lost in Tokyo');

-- Insert tags
INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'john.doe@example.com'),
  'Travel',
  '#FF5733'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Travel');

INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'john.doe@example.com'),
  'Childhood',
  '#33FF57'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Childhood');

INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'),
  'Friendship',
  '#5733FF'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND name = 'Friendship');

INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'jane.smith@example.com'),
  'Reflection',
  '#FF33F0'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND name = 'Reflection');

INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'peter.jones@example.com'),
  'Adventure',
  '#33F0FF'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'peter.jones@example.com') AND name = 'Adventure');

INSERT INTO tags (user_id, name, color)
SELECT
  (SELECT id FROM public.users WHERE email = 'peter.jones@example.com'),
  'Humor',
  '#F0FF33'
WHERE NOT EXISTS (SELECT 1 FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'peter.jones@example.com') AND name = 'Humor');

-- Insert story_tags
INSERT INTO story_tags (story_id, tag_id)
SELECT
  (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'My First Trip to the Grand Canyon'),
  (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Travel')
WHERE NOT EXISTS (SELECT 1 FROM story_tags WHERE story_id = (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'My First Trip to the Grand Canyon') AND tag_id = (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Travel'));

INSERT INTO story_tags (story_id, tag_id)
SELECT
  (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'A Childhood Summer at Grandma''s Farm'),
  (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Childhood')
WHERE NOT EXISTS (SELECT 1 FROM story_tags WHERE story_id = (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND title = 'A Childhood Summer at Grandma''s Farm') AND tag_id = (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'john.doe@example.com') AND name = 'Childhood'));

INSERT INTO story_tags (story_id, tag_id)
SELECT
  (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND title = 'The Day I Met My Best Friend'),
  (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND name = 'Friendship')
WHERE NOT EXISTS (SELECT 1 FROM story_tags WHERE story_id = (SELECT id FROM stories WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND title = 'The Day I Met My Best Friend') AND tag_id = (SELECT id FROM tags WHERE user_id = (SELECT id FROM public.users WHERE email = 'jane.smith@example.com') AND name = 'Friend