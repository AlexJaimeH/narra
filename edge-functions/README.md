# Edge Functions para Narra

Esta carpeta contiene Edge Functions de Supabase que deben ser copiadas manualmente al dashboard de Supabase.

## send-story-reminders

Esta funcion envia emails motivacionales a usuarios que no han tenido actividad en las ultimas 2 semanas.

### Caracteristicas

- **10 templates motivadores diferentes** seleccionados aleatoriamente
- **Personalizado segun el estado del usuario**:
  - `first_story`: Usuario nunca ha publicado ni creado borradores
  - `has_drafts`: Usuario tiene borradores sin terminar
  - `no_activity`: Usuario ha publicado pero no tiene actividad reciente
- **Sigue el diseno de emails de Narra** (gradiente turquesa, logo horizontal, etc.)
- **Tracking completo** de recordatorios enviados

### Instalacion

#### 1. Ejecutar el SQL en Supabase

Primero, ejecuta el SQL del archivo `sqlToPasteSupabase.sql` en tu Supabase SQL Editor.
Busca la seccion que comienza con:
```
-- Sistema de Email Reminders para Motivar Creacion de Historias (Fecha: 2025-11-26)
```

Esto creara:
- Columnas en `user_settings`: `email_reminders_enabled`, `last_reminder_sent_at`, `reminder_frequency_days`
- Tabla `email_reminders` para tracking
- Funcion `get_users_needing_reminder()` para obtener usuarios que necesitan recordatorio

#### 2. Crear la Edge Function

1. Ve al Dashboard de Supabase > Edge Functions
2. Click en "New Function"
3. Nombre: `send-story-reminders`
4. Copia y pega el contenido de `send-story-reminders/index.ts`
5. Guarda la funcion

#### 3. Configurar las variables de entorno

En el dashboard de Supabase > Edge Functions > send-story-reminders > Settings, asegurate de tener:

```
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ... (tu service role key)
RESEND_API_KEY=re_... (tu API key de Resend)
RESEND_FROM_EMAIL=Narra <hola@narra.mx>
APP_URL=https://narra.mx
```

#### 4. Configurar el Cron Job

Para ejecutar la funcion todos los dias a las 8:08 PM de Mexico (02:08 UTC):

1. Ve a Database > Extensions
2. Habilita `pg_cron` y `pg_net` si no estan habilitados
3. Ve a SQL Editor y ejecuta:

```sql
-- Crear el cron job
select cron.schedule(
  'send-story-reminders-daily',
  '8 2 * * *',  -- 02:08 UTC = 20:08 Mexico (UTC-6)
  $$
  select net.http_post(
    url := 'https://TU_PROJECT_REF.supabase.co/functions/v1/send-story-reminders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer TU_SERVICE_ROLE_KEY',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

**IMPORTANTE**: Reemplaza:
- `TU_PROJECT_REF` con tu project reference de Supabase (ej: `ptlzlaacaiftusslzwhc`)
- `TU_SERVICE_ROLE_KEY` con tu Service Role Key

#### 5. Verificar el cron job

```sql
-- Ver todos los cron jobs programados
select * from cron.job;

-- Ver historial de ejecuciones
select * from cron.job_run_details order by start_time desc limit 10;
```

### Prueba manual

Puedes probar la funcion manualmente con curl:

```bash
curl -X POST 'https://TU_PROJECT_REF.supabase.co/functions/v1/send-story-reminders' \
  -H 'Authorization: Bearer TU_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json'
```

### Desactivar recordatorios para un usuario

Los usuarios pueden desactivar los recordatorios desde la app (Ajustes), o puedes hacerlo manualmente:

```sql
update public.user_settings
set email_reminders_enabled = false
where user_id = 'UUID_DEL_USUARIO';
```

### Ver historial de recordatorios

```sql
-- Ultimos 20 recordatorios enviados
select
  er.*,
  u.email as user_email
from public.email_reminders er
join auth.users u on u.id = er.user_id
order by er.sent_at desc
limit 20;

-- Recordatorios por tipo
select
  reminder_type,
  count(*) as total,
  count(*) filter (where opened_at is not null) as opened,
  count(*) filter (where clicked_at is not null) as clicked
from public.email_reminders
group by reminder_type;
```

### Templates disponibles

Los 10 templates tienen diferentes enfoques motivacionales:

1. **Tus recuerdos te esperan** - Enfasis en el valor de los recuerdos
2. **Un momento para ti** - Invita a tomarse un tiempo
3. **Te extranamos** - Apela a los suscriptores que esperan
4. **Inspiracion del dia** - Pregunta que recuerdo te hace sonreir
5. **Un legado de amor** - Enfasis en dejar un legado
6. **Pequenos momentos** - Valora las historias simples
7. **Tu voz unica** - Destaca la perspectiva personal
8. **Conecta generaciones** - Puente entre pasado y futuro
9. **Momento de reflexion** - Invita a pensar que historia contar
10. **Nunca es tarde** - Motivacion para retomar la escritura

Cada template tiene mensajes diferentes segun si el usuario:
- Nunca ha publicado (`first_story`)
- Tiene borradores sin terminar (`has_drafts`)
- No tiene actividad reciente (`no_activity`)
