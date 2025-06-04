-- Создать новую таблицу user_data для хранения профиля пользователя, связанного с auth.users

create table public.user_data (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  phone text,
  city text,
  street text,
  house_number text,
  postal_code text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Индекс для быстрого поиска по id
create index user_data_id_idx on public.user_data (id);

-- Включить RLS и разрешить пользователю видеть и менять только свои данные
-- (настройте политику в Supabase UI или выполните вручную)
-- Пример:
-- alter table public.user_data enable row level security;
-- create policy "Users can view and edit their data"
--   on public.user_data
--   for select using (auth.uid() = id)
--   with check (auth.uid() = id);
