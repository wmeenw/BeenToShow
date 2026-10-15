-- BeenToShow: дополнительное усиление Supabase (необязательно, приложение работает и без него).
-- Запускать ПОСЛЕ supabase_setup.sql: Supabase -> SQL Editor -> Run. Скрипт идемпотентный.
--
-- Что делает:
--  1. Ограничивает бакет media: файл не больше 50 МБ, только фото и видео.
--  2. Ограничивает размер JSON одного концерта (меньше ~200 КБ), чтобы нельзя было забить базу мусором.
--     NOT VALID: существующие строки не проверяются, новые и изменяемые - проверяются.
--  3. Сбрасывает все права роли authenticated на таблицы и выдаёт только нужные.
--
-- Что ещё сделать руками в панели Supabase (SQL этого не делает):
--  - Authentication -> Sign In / Providers: оставить ВЫКЛЮЧЕННЫМ "Allow anonymous sign-ins".
--  - Authentication -> Attack Protection: включить CAPTCHA (hCaptcha / Turnstile), иначе регистрацию
--    можно автоматизировать. Для этого в приложение потребуется добавить передачу captcha-токена.
--  - Authentication -> Sign In / Providers -> Email: "Confirm email" оставить выключенным (ник - это
--    служебный адрес @beentoshow.app, письма туда не уходят), минимальную длину пароля можно поднять.
--  - Authentication -> Rate Limits: проверить лимиты на регистрацию и вход.

-- 1. Бакет media
update storage.buckets
set file_size_limit = 52428800,  -- 50 МБ
    allowed_mime_types = array[
        'image/jpeg', 'image/png', 'image/heic', 'image/webp',
        'video/quicktime', 'video/mp4'
    ]
where id = 'media';

-- 2. Размер данных концерта
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'concerts_data_size_check' and conrelid = 'public.concerts'::regclass
    ) then
        alter table public.concerts
            add constraint concerts_data_size_check check (pg_column_size(data) < 200000) not valid;
    end if;
end $$;

-- 3. Права: сначала всё отзываем, затем выдаём только select/insert/update/delete.
revoke all on public.concerts from authenticated;
revoke all on public.profiles from authenticated;
revoke all on public.concerts from anon;
revoke all on public.profiles from anon;
grant select, insert, update, delete on public.concerts to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
