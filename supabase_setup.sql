-- BeenToShow: настройка Supabase для входа по нику и синхронизации.
-- Вставить целиком в Supabase -> SQL Editor -> Run. Скрипт идемпотентный: можно запускать повторно.
--
-- Модель доступа: пользователь (authenticated) видит и меняет только свои строки
-- (user_id = auth.uid()) и только файлы в своей папке <uid>/ бакета media.
-- Роль anon не получает ничего.

-- ============================================================
-- 1. Таблица концертов
-- data - JSON приложения (закодированный Concert целиком).
-- updated_at выставляет клиент: по нему при синхронизации выигрывает более новая версия.
-- ============================================================
create table if not exists public.concerts (
    id          uuid primary key,
    user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
    data        jsonb not null,
    updated_at  timestamptz not null default now()
);

create index if not exists concerts_user_id_idx on public.concerts (user_id);

-- ============================================================
-- 2. Профили (отображаемое имя)
-- ============================================================
create table if not exists public.profiles (
    user_id      uuid primary key default auth.uid() references auth.users(id) on delete cascade,
    display_name text
);

-- ============================================================
-- 3. Row Level Security
-- ============================================================
alter table public.concerts enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "concerts_select_own" on public.concerts;
drop policy if exists "concerts_insert_own" on public.concerts;
drop policy if exists "concerts_update_own" on public.concerts;
drop policy if exists "concerts_delete_own" on public.concerts;

create policy "concerts_select_own" on public.concerts
    for select to authenticated using (user_id = (select auth.uid()));
create policy "concerts_insert_own" on public.concerts
    for insert to authenticated with check (user_id = (select auth.uid()));
create policy "concerts_update_own" on public.concerts
    for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
create policy "concerts_delete_own" on public.concerts
    for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_delete_own" on public.profiles;

create policy "profiles_select_own" on public.profiles
    for select to authenticated using (user_id = (select auth.uid()));
create policy "profiles_insert_own" on public.profiles
    for insert to authenticated with check (user_id = (select auth.uid()));
create policy "profiles_update_own" on public.profiles
    for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
create policy "profiles_delete_own" on public.profiles
    for delete to authenticated using (user_id = (select auth.uid()));

-- ============================================================
-- 4. Права Data API: таблицы нужно выдавать явно, только authenticated (anon - нет).
-- ============================================================
revoke all on public.concerts from anon;
revoke all on public.profiles from anon;
grant select, insert, update, delete on public.concerts to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;

-- ============================================================
-- 5. Хранилище медиа: приватный бакет media, файлы лежат как <uid>/<имя файла>.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do update set public = false;

drop policy if exists "media_select_own" on storage.objects;
drop policy if exists "media_insert_own" on storage.objects;
drop policy if exists "media_update_own" on storage.objects;
drop policy if exists "media_delete_own" on storage.objects;

create policy "media_select_own" on storage.objects
    for select to authenticated
    using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "media_insert_own" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "media_update_own" on storage.objects
    for update to authenticated
    using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text)
    with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "media_delete_own" on storage.objects
    for delete to authenticated
    using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
