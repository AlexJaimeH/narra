-- ============================================================
-- NARRA - CONFIGURACIÓN COMPLETA DE SUPABASE
-- ============================================================
--
-- Este archivo contiene TODAS las migraciones y configuraciones
-- necesarias para Narra. Ejecutar en SQL Editor de Supabase.
--
-- ============================================================

create extension if not exists "pgcrypto";

-- Story version history (idempotent)
begin;

create table if not exists public.story_versions (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  content text not null default '',
  reason text not null default '',
  tags jsonb not null default '[]'::jsonb,
  start_date timestamptz,
  end_date timestamptz,
  dates_precision text,
  photos jsonb not null default '[]'::jsonb,
  saved_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists story_versions_story_id_saved_at_idx
  on public.story_versions (story_id, saved_at desc);

alter table public.story_versions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_versions'
      and policyname = 'Story versions are viewable by owner'
  ) then
    create policy "Story versions are viewable by owner"
      on public.story_versions
      for select
      using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_versions'
      and policyname = 'Story versions are insertable by owner'
  ) then
    create policy "Story versions are insertable by owner"
      on public.story_versions
      for insert
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_versions'
      and policyname = 'Story versions are updatable by owner'
  ) then
    create policy "Story versions are updatable by owner"
      on public.story_versions
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_versions'
      and policyname = 'Story versions are deletable by owner'
  ) then
    create policy "Story versions are deletable by owner"
      on public.story_versions
      for delete
      using (auth.uid() = user_id);
  end if;
end
$$;

commit;

-- Voice recordings library
begin;

create table if not exists public.voice_recordings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  story_id uuid references public.stories (id) on delete cascade,
  story_title text default '',
  audio_url text not null,
  audio_path text not null,
  storage_bucket text default 'voice-recordings',
  transcript text default '',
  duration_seconds numeric,
  created_at timestamptz not null default timezone('utc', now())
);

-- PRIMERO: Actualizar valores NULL existentes ANTES de forzar NOT NULL
update public.voice_recordings
set story_title = ''
where story_title is null;

update public.voice_recordings
set transcript = ''
where transcript is null;

update public.voice_recordings
set storage_bucket = 'voice-recordings'
where storage_bucket is null;

-- SEGUNDO: Ahora sí aplicar NOT NULL y defaults
alter table public.voice_recordings
  alter column story_title set not null,
  alter column story_title set default '',
  alter column transcript set not null,
  alter column transcript set default '',
  alter column storage_bucket set not null,
  alter column storage_bucket set default 'voice-recordings';

alter table public.voice_recordings
  drop constraint if exists voice_recordings_story_id_fkey,
  add constraint voice_recordings_story_id_fkey
    foreign key (story_id)
    references public.stories (id)
    on delete cascade;

alter table public.voice_recordings
  drop constraint if exists voice_recordings_user_id_fkey,
  add constraint voice_recordings_user_id_fkey
    foreign key (user_id)
    references auth.users (id)
    on delete cascade;

-- Nota: storage_bucket ya fue configurado arriba

create index if not exists voice_recordings_user_idx
  on public.voice_recordings (user_id, created_at desc);

create index if not exists voice_recordings_story_idx
  on public.voice_recordings (story_id, created_at desc)
  where story_id is not null;

insert into storage.buckets (id, name, public)
select 'voice-recordings', 'voice-recordings', false
where not exists (
  select 1 from storage.buckets where id = 'voice-recordings'
);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users manage voice recording files'
  ) then
    create policy "Users manage voice recording files"
      on storage.objects
      for all
      using (
        bucket_id = 'voice-recordings'
        and auth.uid() = owner
      )
      with check (
        bucket_id = 'voice-recordings'
        and auth.uid() = owner
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Service role manages voice recordings bucket'
  ) then
    create policy "Service role manages voice recordings bucket"
      on storage.objects
      for all
      using (
        bucket_id = 'voice-recordings'
        and (
          coalesce(auth.role(), '') = 'service_role'
          or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
        )
      )
      with check (
        bucket_id = 'voice-recordings'
        and (
          coalesce(auth.role(), '') = 'service_role'
          or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
        )
      );
  end if;
end
$$;

alter table public.voice_recordings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'voice_recordings'
      and policyname = 'Owners manage voice recordings'
  ) then
    create policy "Owners manage voice recordings"
      on public.voice_recordings
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'voice_recordings'
      and policyname = 'Service role manages voice recordings'
  ) then
    create policy "Service role manages voice recordings"
      on public.voice_recordings
      for all
      using (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      )
      with check (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      );
  end if;
end
$$;

commit;

-- Public access policies for published stories and related data
begin;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'stories'
      and policyname = 'Published stories are viewable publicly'
  ) then
    create policy "Published stories are viewable publicly"
      on public.stories
      for select using (
        status = 'published'
        or published_at is not null
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'tags'
      and policyname = 'Published tags are viewable publicly'
  ) then
    create policy "Published tags are viewable publicly"
      on public.tags
      for select using (
        exists (
          select 1 from public.story_tags st
          join public.stories s on s.id = st.story_id
          where st.tag_id = tags.id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_tags'
      and policyname = 'Published story tags are viewable publicly'
  ) then
    create policy "Published story tags are viewable publicly"
      on public.story_tags
      for select using (
        exists (
          select 1 from public.stories s
          where s.id = story_tags.story_id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_photos'
      and policyname = 'Published story photos are viewable publicly'
  ) then
    create policy "Published story photos are viewable publicly"
      on public.story_photos
      for select using (
        exists (
          select 1 from public.stories s
          where s.id = story_photos.story_id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'people'
      and policyname = 'Published people are viewable publicly'
  ) then
    create policy "Published people are viewable publicly"
      on public.people
      for select using (
        exists (
          select 1 from public.story_people sp
          join public.stories s on s.id = sp.story_id
          where sp.person_id = people.id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_people'
      and policyname = 'Published story people are viewable publicly'
  ) then
    create policy "Published story people are viewable publicly"
      on public.story_people
      for select using (
        exists (
          select 1 from public.stories s
          where s.id = story_people.story_id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'Published author settings are viewable publicly'
  ) then
    create policy "Published author settings are viewable publicly"
      on public.user_settings
      for select using (
        exists (
          select 1 from public.stories s
          where s.user_id = user_settings.user_id
            and (s.status = 'published' or s.published_at is not null)
        )
      );
  end if;
end
$$;

commit;

-- Ensure metadata columns exist for story versions
begin;

alter table public.story_versions
  add column if not exists tags jsonb not null default '[]'::jsonb,
  add column if not exists start_date timestamptz,
  add column if not exists end_date timestamptz,
  add column if not exists dates_precision text,
  add column if not exists photos jsonb not null default '[]'::jsonb;

update public.story_versions
set tags = '[]'::jsonb
where tags is null;

update public.story_versions
set photos = '[]'::jsonb
where photos is null;

commit;

-- Ensure stories table stores publication timestamps
begin;

alter table public.stories
  add column if not exists published_at timestamptz;

update public.stories
set published_at = coalesce(published_at, updated_at)
where status = 'published' and published_at is null;

commit;

-- Public author profile fields
begin;

alter table public.user_settings
  add column if not exists public_author_name text,
  add column if not exists public_author_tagline text,
  add column if not exists public_author_summary text,
  add column if not exists public_blog_cover_url text;

commit;

-- Subscriber magic links & tracking
begin;

alter table public.subscribers
  add column if not exists access_token text default encode(gen_random_bytes(24), 'hex'),
  add column if not exists access_token_created_at timestamptz default timezone('utc', now()),
  add column if not exists access_token_last_sent_at timestamptz,
  add column if not exists last_access_at timestamptz,
  add column if not exists last_access_ip inet,
  add column if not exists last_access_user_agent text,
  add column if not exists last_access_source text;

update public.subscribers
set
  access_token = coalesce(access_token, encode(gen_random_bytes(24), 'hex')),
  access_token_created_at = coalesce(access_token_created_at, timezone('utc', now()))
where access_token is null or access_token = '';

create unique index if not exists subscribers_access_token_key
  on public.subscribers (access_token)
  where access_token is not null and access_token <> '';

commit;

-- Subscriber access audit
begin;

create table if not exists public.subscriber_access_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  subscriber_id uuid not null references public.subscribers(id) on delete cascade,
  story_id uuid references public.stories(id) on delete cascade,
  access_token text,
  event_type text not null check (event_type in ('link_sent', 'link_opened', 'invite_opened', 'access_granted', 'unsubscribe')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists subscriber_access_events_subscriber_idx
  on public.subscriber_access_events (subscriber_id, created_at desc);

alter table public.subscriber_access_events enable row level security;

alter table public.subscriber_access_events
  drop constraint if exists subscriber_access_events_event_type_check;

alter table public.subscriber_access_events
  add constraint subscriber_access_events_event_type_check
    check (event_type in ('link_sent', 'link_opened', 'invite_opened', 'access_granted', 'unsubscribe'));

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'subscriber_access_events'
      and policyname = 'Owners manage subscriber access events'
  ) then
    create policy "Owners manage subscriber access events"
      on public.subscriber_access_events
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

commit;

-- RPC para validar accesos de suscriptores desde la aplicación pública
begin;

drop function if exists public.register_subscriber_access(
  uuid,
  uuid,
  text,
  uuid,
  text,
  text,
  inet,
  text
);

create or replace function public.register_subscriber_access(
  author_id uuid,
  subscriber_id uuid,
  token text,
  story_id uuid default null,
  source text default null,
  event_type text default 'access_granted',
  request_ip inet default null,
  user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subscriber public.subscribers%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_event_type text := lower(coalesce(nullif(event_type, ''), 'access_granted'));
  v_source text := nullif(trim(coalesce(source, '')), '');
  v_user_agent text := nullif(trim(coalesce(user_agent, '')), '');
begin
  select *
    into v_subscriber
    from public.subscribers
   where id = subscriber_id
     and user_id = author_id;

  if not found then
    return jsonb_build_object(
      'status', 'not_found',
      'message', 'No encontramos este suscriptor.'
    );
  end if;

  if v_subscriber.status = 'unsubscribed' then
    if v_event_type <> 'unsubscribe' then
      return jsonb_build_object(
        'status', 'forbidden',
        'message', 'Este suscriptor canceló su acceso.'
      );
    end if;
  end if;

  if v_subscriber.access_token is null
     or trim(v_subscriber.access_token) = ''
     or trim(v_subscriber.access_token) <> trim(coalesce(token, '')) then
    return jsonb_build_object(
      'status', 'forbidden',
      'message', 'El enlace ya caducó o no es válido.'
    );
  end if;

  if v_event_type = 'unsubscribe' then
    update public.subscribers
       set status = 'unsubscribed',
           last_access_at = v_now,
           last_access_ip = coalesce(request_ip, last_access_ip),
           last_access_user_agent = coalesce(substring(v_user_agent from 1 for 512), last_access_user_agent),
           last_access_source = coalesce(v_source, last_access_source)
     where id = v_subscriber.id;
  else
    update public.subscribers
       set status = case when status <> 'confirmed' then 'confirmed' else status end,
           last_access_at = v_now,
           last_access_ip = coalesce(request_ip, last_access_ip),
           last_access_user_agent = coalesce(substring(v_user_agent from 1 for 512), last_access_user_agent),
           last_access_source = coalesce(v_source, last_access_source)
     where id = v_subscriber.id;
  end if;

  insert into public.subscriber_access_events (
    user_id,
    subscriber_id,
    story_id,
    access_token,
    event_type,
    metadata
  ) values (
    author_id,
    v_subscriber.id,
    story_id,
    v_subscriber.access_token,
    case
      when v_event_type = 'link_sent' then 'link_sent'
      when v_event_type = 'link_opened' then 'link_opened'
      when v_event_type = 'invite_opened' then 'invite_opened'
      else 'access_granted'
    end,
    jsonb_build_object(
      'source', coalesce(v_source, null),
      'ip', case when request_ip is null then null else request_ip::text end,
      'userAgent', v_user_agent
    )
  );

  return jsonb_build_object(
    'status', 'ok',
    'data', jsonb_build_object(
      'grantedAt', v_now,
      'token', v_subscriber.access_token,
      'source', coalesce(v_source, v_subscriber.last_access_source),
      'subscriber', jsonb_build_object(
        'id', v_subscriber.id,
        'name', v_subscriber.name,
        'email', v_subscriber.email,
        'status', case
          when v_event_type = 'unsubscribe' then 'unsubscribed'
          else 'confirmed'
        end
      )
    )
  );
end;
$$;

grant execute on function public.register_subscriber_access(
  uuid,
  uuid,
  text,
  uuid,
  text,
  text,
  inet,
  text
) to anon, authenticated;

commit;

-- Subscriber feedback: story comments
begin;

create table if not exists public.story_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  story_id uuid not null references public.stories(id) on delete cascade,
  subscriber_id uuid references public.subscribers(id) on delete set null,
  parent_id uuid references public.story_comments(id) on delete cascade,
  author_name text not null default '',
  author_email text,
  content text not null,
  source text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'visible' check (status in ('visible', 'hidden', 'flagged')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz
);

create index if not exists story_comments_story_idx
  on public.story_comments (story_id, created_at desc);

create index if not exists story_comments_subscriber_idx
  on public.story_comments (subscriber_id, created_at desc);

alter table public.story_comments enable row level security;

alter table public.story_comments
  add column if not exists parent_id uuid;

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_schema = 'public'
      and constraint_name = 'story_comments_parent_id_fkey'
      and table_name = 'story_comments'
  ) then
    alter table public.story_comments
      add constraint story_comments_parent_id_fkey
        foreign key (parent_id) references public.story_comments(id)
        on delete cascade;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1 from information_schema.table_constraints
    where constraint_schema = 'public'
      and table_name = 'story_comments'
      and constraint_name = 'story_comments_user_id_fkey'
  ) then
    begin
      alter table public.story_comments
        drop constraint story_comments_user_id_fkey;
    exception when undefined_object then
      null;
    end;
  end if;

  alter table public.story_comments
    add constraint story_comments_user_id_fkey
      foreign key (user_id) references public.users(id) on delete cascade;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_comments'
      and policyname = 'Authors manage own story comments'
  ) then
    create policy "Authors manage own story comments"
      on public.story_comments
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

create index if not exists story_comments_parent_idx
  on public.story_comments (parent_id, created_at desc);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_comments'
      and policyname = 'Service role manages story comments'
  ) then
    create policy "Service role manages story comments"
      on public.story_comments
      for all
      using (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      )
      with check (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'update_story_comments_updated_at'
      and tgrelid = 'public.story_comments'::regclass
  ) then
    create trigger update_story_comments_updated_at
      before update on public.story_comments
      for each row execute procedure update_updated_at_column();
  end if;
end
$$;

commit;

-- Subscriber feedback: story reactions
begin;

create table if not exists public.story_reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  story_id uuid not null references public.stories(id) on delete cascade,
  subscriber_id uuid references public.subscribers(id) on delete set null,
  reaction_type text not null default 'heart' check (reaction_type in ('heart')),
  source text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists story_reactions_unique_idx
  on public.story_reactions (story_id, subscriber_id, reaction_type)
  where subscriber_id is not null;

create index if not exists story_reactions_story_idx
  on public.story_reactions (story_id, created_at desc);

create index if not exists story_reactions_subscriber_idx
  on public.story_reactions (subscriber_id, created_at desc);

alter table public.story_reactions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_reactions'
      and policyname = 'Authors manage own story reactions'
  ) then
    create policy "Authors manage own story reactions"
      on public.story_reactions
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if exists (
    select 1 from information_schema.table_constraints
    where constraint_schema = 'public'
      and table_name = 'story_reactions'
      and constraint_name = 'story_reactions_user_id_fkey'
  ) then
    begin
      alter table public.story_reactions
        drop constraint story_reactions_user_id_fkey;
    exception when undefined_object then
      null;
    end;
  end if;

  alter table public.story_reactions
    add constraint story_reactions_user_id_fkey
      foreign key (user_id) references public.users(id) on delete cascade;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'story_reactions'
      and policyname = 'Service role manages story reactions'
  ) then
    create policy "Service role manages story reactions"
      on public.story_reactions
      for all
      using (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      )
      with check (
        coalesce(auth.role(), '') = 'service_role'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      );
  end if;
end
$$;

commit;

-- Subscriber engagement summary view
begin;

create or replace view public.subscriber_engagement_summary as
select
  s.id as subscriber_id,
  s.user_id,
  coalesce(count(distinct sr.id), 0) as total_reactions,
  coalesce(count(distinct sc.id), 0) as total_comments,
  max(sr.created_at) as last_reaction_at,
  max(sc.created_at) as last_comment_at
from public.subscribers s
left join public.story_reactions sr on sr.subscriber_id = s.id
left join public.story_comments sc on sc.subscriber_id = s.id
group by s.id, s.user_id;

commit;

-- Story feedback RPC
begin;

create or replace function public.process_story_feedback(
  p_action text,
  p_author_id uuid,
  p_story_id uuid,
  p_subscriber_id uuid,
  p_token text,
  p_content text default null,
  p_reaction_type text default 'heart',
  p_active boolean default null,
  p_source text default null,
  p_parent_comment_id uuid default null,
  p_request_ip inet default null,
  p_user_agent text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text := lower(coalesce(trim(p_action), ''));
  v_subscriber public.subscribers%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_token text := coalesce(trim(p_token), '');
  v_reaction_type text := lower(coalesce(trim(p_reaction_type), 'heart'));
  v_comment public.story_comments%rowtype;
  v_comments jsonb := '[]'::jsonb;
  v_reaction jsonb;
  v_has_reaction boolean := false;
  v_parent public.story_comments%rowtype;
  v_comment_count integer := 0;
begin
  if v_action not in ('fetch', 'comment', 'reaction') then
    return jsonb_build_object('error', 'unsupported_action');
  end if;

  select *
    into v_subscriber
    from public.subscribers
   where id = p_subscriber_id and user_id = p_author_id;

  if not found then
    return jsonb_build_object('error', 'subscriber_not_found');
  end if;

  if coalesce(trim(v_subscriber.access_token), '') <> v_token then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  if v_subscriber.status = 'unsubscribed' then
    return jsonb_build_object('error', 'subscriber_inactive');
  end if;

  if v_action = 'fetch' then
    select
      coalesce(json_agg(jsonb_build_object(
        'id', c.id,
        'authorName', c.author_name,
        'content', c.content,
        'createdAt', c.created_at,
        'subscriberId', c.subscriber_id,
        'source', c.source,
        'parentId', c.parent_id
      ) order by c.created_at desc), '[]'::jsonb),
      count(*)
      into v_comments, v_comment_count
      from public.story_comments c
     where c.user_id = p_author_id and c.story_id = p_story_id;

    select jsonb_build_object(
        'reactionType', r.reaction_type,
        'active', true
      )
      into v_reaction
      from public.story_reactions r
     where r.user_id = p_author_id
       and r.story_id = p_story_id
       and r.subscriber_id = p_subscriber_id
     limit 1;

    return jsonb_build_object(
      'comments', v_comments,
      'reaction', coalesce(v_reaction, jsonb_build_object('active', false)),
      'commentCount', v_comment_count
    );
  elsif v_action = 'comment' then
    if coalesce(trim(p_content), '') = '' then
      return jsonb_build_object('error', 'content_required');
    end if;

    if p_parent_comment_id is not null then
      select *
        into v_parent
        from public.story_comments
       where id = p_parent_comment_id
         and user_id = p_author_id
         and story_id = p_story_id
       limit 1;

      if not found then
        return jsonb_build_object('error', 'parent_not_found');
      end if;
    end if;

    begin
      insert into public.story_comments (
        user_id,
        story_id,
        subscriber_id,
        parent_id,
        author_name,
        author_email,
        content,
        source,
        metadata
      ) values (
        p_author_id,
        p_story_id,
        p_subscriber_id,
        p_parent_comment_id,
        trim(coalesce(v_subscriber.name, 'Suscriptor')),
        nullif(trim(v_subscriber.email), ''),
        left(trim(p_content), 4000),
        nullif(trim(p_source), ''),
        jsonb_build_object(
          'ip', case when p_request_ip is null then null else p_request_ip::text end,
          'userAgent', p_user_agent,
          'tokenHash', encode(digest(v_token, 'sha256'), 'hex')
        )
      ) returning * into v_comment;
    exception
      when others then
        return jsonb_build_object(
          'error', 'insert_failed',
          'detail', SQLERRM
        );
    end;

    return jsonb_build_object(
      'comment', jsonb_build_object(
        'id', v_comment.id,
        'authorName', v_comment.author_name,
        'content', v_comment.content,
        'createdAt', v_comment.created_at,
        'subscriberId', v_comment.subscriber_id,
        'source', v_comment.source,
        'parentId', v_comment.parent_id
      )
    );
  else
    if v_reaction_type is null or v_reaction_type = '' then
      v_reaction_type := 'heart';
    end if;

    if coalesce(p_active, true) then
      begin
        insert into public.story_reactions (
          user_id,
          story_id,
          subscriber_id,
          reaction_type,
          source,
          metadata
        ) values (
          p_author_id,
          p_story_id,
          p_subscriber_id,
          v_reaction_type,
          nullif(trim(p_source), ''),
          jsonb_build_object(
            'ip', case when p_request_ip is null then null else p_request_ip::text end,
            'userAgent', p_user_agent,
            'tokenHash', encode(digest(v_token, 'sha256'), 'hex')
          )
        )
        on conflict (story_id, subscriber_id, reaction_type)
        do update set
          source = excluded.source,
          metadata = excluded.metadata,
          created_at = timezone('utc', now());
      exception
        when others then
          return jsonb_build_object(
            'error', 'reaction_failed',
            'detail', SQLERRM
          );
      end;
      v_has_reaction := true;
    else
      delete from public.story_reactions
       where user_id = p_author_id
         and story_id = p_story_id
         and subscriber_id = p_subscriber_id
         and reaction_type = v_reaction_type;
      v_has_reaction := false;
    end if;

    return jsonb_build_object(
      'reaction', jsonb_build_object(
        'reactionType', v_reaction_type,
        'active', v_has_reaction
      )
    );
  end if;
end;
$$;

grant execute on function public.process_story_feedback(
  p_action text,
  p_author_id uuid,
  p_story_id uuid,
  p_subscriber_id uuid,
  p_token text,
  p_content text,
  p_reaction_type text,
  p_active boolean,
  p_source text,
  p_parent_comment_id uuid,
  p_request_ip inet,
  p_user_agent text
) to anon, authenticated;

commit;

-- ============================================================
-- AGREGAR COLUMNAS DE FECHA A LA TABLA STORIES
-- ============================================================
--
-- Estas columnas permiten guardar rangos de fechas y precisión
-- para las historias (día exacto, mes, o año)
--
-- ============================================================

begin;

-- Agregar columna start_date si no existe
alter table public.stories
add column if not exists start_date date;

-- Agregar columna end_date si no existe
alter table public.stories
add column if not exists end_date date;

-- PASO 1: Actualizar valores existentes ANTES de cambiar constraint y default
-- Mapeo: 'exact' -> 'day', 'month_year' -> 'month', 'year' -> 'year', 'approximate' -> 'day'
update public.stories
set dates_precision = case
  when dates_precision = 'exact' then 'day'
  when dates_precision = 'month_year' then 'month'
  when dates_precision = 'approximate' then 'day'
  when dates_precision is null then 'day'
  else dates_precision
end
where dates_precision in ('exact', 'month_year', 'approximate') or dates_precision is null;

-- Actualizar date_type también (columna legacy que puede estar en uso)
update public.stories
set date_type = case
  when date_type = 'exact' then 'day'
  when date_type = 'month_year' then 'month'
  when date_type = 'approximate' then 'day'
  when date_type is null then 'day'
  else date_type
end
where date_type in ('exact', 'month_year', 'approximate') or date_type is null;

-- PASO 2: Cambiar el DEFAULT ANTES de cambiar el constraint
alter table public.stories
  alter column dates_precision set default 'day';

alter table public.stories
  alter column date_type set default 'day';

-- PASO 3: Ahora sí eliminar y recrear el constraint
alter table public.stories
drop constraint if exists stories_dates_precision_check;

alter table public.stories
add constraint stories_dates_precision_check
check (dates_precision in ('day', 'month', 'year'));

-- También actualizar constraint de date_type si existe
alter table public.stories
drop constraint if exists stories_date_type_check;

alter table public.stories
add constraint stories_date_type_check
check (date_type in ('day', 'month', 'year'));

-- Copiar story_date a start_date si start_date está vacío
update public.stories
set start_date = story_date::date
where start_date is null and story_date is not null;

commit;

-- ============================================================
-- RESUMEN
-- ============================================================
--
-- ✅ Columnas agregadas:
--    - start_date: Fecha de inicio de la historia (puede ser el único valor)
--    - end_date: Fecha de fin de la historia (opcional, para rangos)
--
-- ✅ Constraint actualizado:
--    - dates_precision ahora acepta: 'day', 'month', 'year'
--    - Valores antiguos migrados automáticamente
--
-- ============================================================

-- ============================================================
-- Magic Links para Autores (Fecha: 2025-10-29)
-- ============================================================
-- Permite que los autores accedan a sus propias historias publicadas
-- mediante un magic link especial sin necesidad de estar en la tabla
-- de suscriptores.
-- ============================================================

begin;

-- Recrear la función para soportar acceso de autores
drop function if exists public.register_subscriber_access(
  uuid,
  uuid,
  text,
  uuid,
  text,
  text,
  inet,
  text
);

create or replace function public.register_subscriber_access(
  author_id uuid,
  subscriber_id uuid,
  token text,
  story_id uuid default null,
  source text default null,
  event_type text default 'access_granted',
  request_ip inet default null,
  user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subscriber public.subscribers%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_event_type text := lower(coalesce(nullif(event_type, ''), 'access_granted'));
  v_source text := nullif(trim(coalesce(source, '')), '');
  v_user_agent text := nullif(trim(coalesce(user_agent, '')), '');
  v_is_author_access boolean := false;
  v_author_name text;
  v_author_email text;
begin
  -- Caso especial: El autor accediendo a su propia historia
  -- Identificamos esto cuando subscriber_id = author_id y source = 'author_preview'
  if subscriber_id = author_id and (v_source = 'author_preview' or v_source like 'author%') then
    v_is_author_access := true;

    -- Validar que el token sea el mismo que el author_id (o cualquier validación que decidamos)
    if trim(coalesce(token, '')) = '' or trim(token) <> trim(author_id::text) then
      return jsonb_build_object(
        'status', 'forbidden',
        'message', 'Token de autor inválido.'
      );
    end if;

    -- Obtener información del autor desde user_settings y auth.users
    select
      coalesce(us.public_author_name, au.raw_user_meta_data->>'full_name', au.email, au.id::text),
      au.email
    into v_author_name, v_author_email
    from auth.users au
    left join public.user_settings us on us.user_id = au.id
    where au.id = author_id;

    if not found then
      return jsonb_build_object(
        'status', 'forbidden',
        'message', 'Autor no encontrado.'
      );
    end if;

    -- Retornar acceso concedido para el autor
    return jsonb_build_object(
      'status', 'ok',
      'data', jsonb_build_object(
        'grantedAt', v_now,
        'token', token,
        'source', v_source,
        'isAuthor', true,
        'subscriber', jsonb_build_object(
          'id', author_id,
          'name', v_author_name,
          'email', v_author_email,
          'status', 'author'
        )
      )
    );
  end if;

  -- Flujo normal para suscriptores
  select *
    into v_subscriber
    from public.subscribers
   where id = subscriber_id
     and user_id = author_id;

  if not found then
    return jsonb_build_object(
      'status', 'not_found',
      'message', 'No encontramos este suscriptor.'
    );
  end if;

  if v_subscriber.status = 'unsubscribed' then
    if v_event_type <> 'unsubscribe' then
      return jsonb_build_object(
        'status', 'forbidden',
        'message', 'Este suscriptor canceló su acceso.'
      );
    end if;
  end if;

  if v_subscriber.access_token is null
     or trim(v_subscriber.access_token) = ''
     or trim(v_subscriber.access_token) <> trim(coalesce(token, '')) then
    return jsonb_build_object(
      'status', 'forbidden',
      'message', 'El enlace ya caducó o no es válido.'
    );
  end if;

  if v_event_type = 'unsubscribe' then
    update public.subscribers
       set status = 'unsubscribed',
           last_access_at = v_now,
           last_access_ip = coalesce(request_ip, last_access_ip),
           last_access_user_agent = coalesce(substring(v_user_agent from 1 for 512), last_access_user_agent),
           last_access_source = coalesce(v_source, last_access_source)
     where id = v_subscriber.id;
  else
    update public.subscribers
       set status = case when status <> 'confirmed' then 'confirmed' else status end,
           last_access_at = v_now,
           last_access_ip = coalesce(request_ip, last_access_ip),
           last_access_user_agent = coalesce(substring(v_user_agent from 1 for 512), last_access_user_agent),
           last_access_source = coalesce(v_source, last_access_source)
     where id = v_subscriber.id;
  end if;

  insert into public.subscriber_access_events (
    user_id,
    subscriber_id,
    story_id,
    access_token,
    event_type,
    metadata
  ) values (
    author_id,
    v_subscriber.id,
    story_id,
    v_subscriber.access_token,
    case
      when v_event_type = 'link_sent' then 'link_sent'
      when v_event_type = 'link_opened' then 'link_opened'
      when v_event_type = 'invite_opened' then 'invite_opened'
      else 'access_granted'
    end,
    jsonb_build_object(
      'source', coalesce(v_source, null),
      'ip', case when request_ip is null then null else request_ip::text end,
      'userAgent', v_user_agent
    )
  );

  return jsonb_build_object(
    'status', 'ok',
    'data', jsonb_build_object(
      'grantedAt', v_now,
      'token', v_subscriber.access_token,
      'source', coalesce(v_source, v_subscriber.last_access_source),
      'subscriber', jsonb_build_object(
        'id', v_subscriber.id,
        'name', v_subscriber.name,
        'email', v_subscriber.email,
        'status', case
          when v_event_type = 'unsubscribe' then 'unsubscribed'
          else 'confirmed'
        end
      )
    )
  );
end;
$$;

grant execute on function public.register_subscriber_access(
  uuid,
  uuid,
  text,
  uuid,
  text,
  text,
  inet,
  text
) to anon, authenticated;

commit;

-- ============================================================
-- Author Magic Links for Passwordless Authentication (Fecha: 2025-10-31)
-- ============================================================
-- Sistema de autenticación sin contraseña para autores usando magic links
-- por correo electrónico. Similar al sistema de suscriptores pero para autores.

begin;

-- Tabla para almacenar magic links temporales de autores
create table if not exists public.author_magic_links (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  token text not null unique,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null default (timezone('utc', now()) + interval '15 minutes'),
  used_at timestamptz,
  ip_address inet,
  user_agent text
);

-- Índices para búsqueda eficiente
create index if not exists author_magic_links_token_idx
  on public.author_magic_links (token)
  where used_at is null and expires_at > timezone('utc', now());

create index if not exists author_magic_links_email_idx
  on public.author_magic_links (email, created_at desc);

-- RLS: Solo funciones del servidor pueden acceder a esta tabla
alter table public.author_magic_links enable row level security;

-- Política para servicio (Cloudflare Functions necesitan acceso)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'author_magic_links'
      and policyname = 'Service role can manage author magic links'
  ) then
    create policy "Service role can manage author magic links"
      on public.author_magic_links
      for all
      using (true)
      with check (true);
  end if;
end
$$;

-- Función para limpiar magic links expirados (ejecutar periódicamente)
create or replace function public.cleanup_expired_author_magic_links()
returns void
language plpgsql
security definer
as $$
begin
  delete from public.author_magic_links
  where expires_at < timezone('utc', now()) - interval '1 day';
end;
$$;

-- Función para validar un magic link y retornar info del usuario
create or replace function public.validate_author_magic_link(
  p_token text,
  p_ip_address inet default null,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_link record;
  v_user record;
  v_now timestamptz;
begin
  v_now := timezone('utc', now());

  -- Buscar el magic link
  select * into v_link
  from public.author_magic_links
  where token = p_token
    and used_at is null
    and expires_at > v_now
  limit 1;

  -- Si no existe o ya fue usado o expiró
  if not found then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Magic link inválido, expirado o ya usado'
    );
  end if;

  -- Marcar como usado
  update public.author_magic_links
  set used_at = v_now,
      ip_address = coalesce(p_ip_address, ip_address),
      user_agent = coalesce(p_user_agent, user_agent)
  where id = v_link.id;

  -- Si ya existe el usuario, retornar su info
  if v_link.user_id is not null then
    select id, email, raw_user_meta_data
    into v_user
    from auth.users
    where id = v_link.user_id;

    if found then
      return jsonb_build_object(
        'status', 'success',
        'action', 'login',
        'user', jsonb_build_object(
          'id', v_user.id,
          'email', v_user.email,
          'name', coalesce(v_user.raw_user_meta_data->>'full_name', v_user.raw_user_meta_data->>'name', split_part(v_user.email, '@', 1))
        )
      );
    end if;
  end if;

  -- Si no existe el usuario, indicar que debe crearse
  return jsonb_build_object(
    'status', 'success',
    'action', 'register',
    'email', v_link.email
  );
end;
$$;

grant execute on function public.cleanup_expired_author_magic_links() to service_role;
grant execute on function public.validate_author_magic_link(text, inet, text) to anon, authenticated, service_role;

commit;
