-- Добавьте недостающие поля
alter table public.user_profiles
  add column if not exists first_name text,
  add column if not exists phone text,
  add column if not exists city text,
  add column if not exists street text,
  add column if not exists house_number text,
  add column if not exists postal_code text;

-- Удалите неиспользуемые поля, если они не нужны (ОСТОРОЖНО!)
alter table public.user_profiles
  drop column if exists last_name,
  drop column if exists meta_phone,
  drop column if exists address,
  drop column if exists user_group,
  drop column if exists promo_code;

-- created_at можно оставить, остальные поля — по необходимости.
