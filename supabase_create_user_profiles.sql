-- Создание таблицы user_profiles для хранения профиля пользователя с адресом (jsonb)

create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  address jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Индекс для быстрого поиска по id
create index user_profiles_id_idx on public.user_profiles (id);

-- Разрешить пользователю читать и обновлять только свой профиль
-- (пример политики безопасности, настройте под свои нужды)
-- В Supabase UI настройте Row Level Security (RLS) и добавьте политику:
-- Пример:
-- enable row level security;
-- create policy "Users can view and edit their profile"
--   on public.user_profiles
--   for select using (auth.uid() = id)
--   with check (auth.uid() = id);
