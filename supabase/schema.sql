-- Run this first in Supabase > SQL Editor
create extension if not exists pgcrypto;

create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,            -- matches the quiz key used on the course page (e.g. pre, post4, ode_q1)
  title text not null,
  meta jsonb not null default '{"limit":"10 mins","secs":600,"method":"Highest grade","pass":"Not specified","grade":10}',
  published boolean not null default false,
  created_at timestamptz default now()
);

create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  position int not null,
  type text not null check (type in ('radio','multi','text','drop','match')),
  text text not null,
  options jsonb,
  answer jsonb not null,
  weight int not null default 1,
  extra jsonb not null default '{}'     -- anything else (fig, lab, frames...)
);
create index if not exists questions_quiz_idx on questions(quiz_id, position);

create table if not exists attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_slug text not null,
  student_name text,
  score numeric,
  total numeric,
  secs int,
  answers jsonb,
  created_at timestamptz default now()
);

create table if not exists admins (user_id uuid primary key references auth.users(id) on delete cascade);

create or replace function is_admin() returns boolean
language sql security definer set search_path = public stable
as $$ select exists(select 1 from admins where user_id = auth.uid()) $$;

alter table quizzes   enable row level security;
alter table questions enable row level security;
alter table attempts  enable row level security;
alter table admins    enable row level security;   -- no policies: only is_admin() reads it

create policy "read published quizzes" on quizzes for select using (published or is_admin());
create policy "admin write quizzes"    on quizzes for all using (is_admin()) with check (is_admin());

create policy "read published questions" on questions for select
  using (is_admin() or exists(select 1 from quizzes z where z.id = quiz_id and z.published));
create policy "admin write questions" on questions for all using (is_admin()) with check (is_admin());

create policy "anyone submits attempt" on attempts for insert with check (true);
create policy "admin reads attempts"   on attempts for select using (is_admin());

-- After creating your admin user in Authentication > Users, run:
-- insert into admins(user_id) select id from auth.users where email = 'YOU@EXAMPLE.COM';
