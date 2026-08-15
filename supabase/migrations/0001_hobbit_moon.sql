-- Hobbit Moon multiplayer foundation
-- Apply this migration in a Supabase project before enabling hosted accounts.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 32),
  created_at timestamptz not null default now()
);

create table if not exists public.villages (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 40),
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{6}$'),
  created_at timestamptz not null default now()
);

create table if not exists public.village_members (
  village_id uuid not null references public.villages(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'guest' check (role in ('owner', 'guest')),
  joined_at timestamptz not null default now(),
  primary key (village_id, profile_id)
);

create table if not exists public.village_invites (
  id uuid primary key default gen_random_uuid(),
  village_id uuid not null references public.villages(id) on delete cascade,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  invite_code text not null,
  expires_at timestamptz not null default (now() + interval '7 days'),
  redeemed_at timestamptz
);

alter table public.profiles enable row level security;
alter table public.villages enable row level security;
alter table public.village_members enable row level security;
alter table public.village_invites enable row level security;

create policy "profiles are readable by village members"
  on public.profiles for select using (
    id = auth.uid() or exists (
      select 1 from public.village_members mine
      join public.village_members theirs on theirs.village_id = mine.village_id
      where mine.profile_id = auth.uid() and theirs.profile_id = profiles.id
    )
  );

create policy "users manage their own profile"
  on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());

create policy "members can read their villages"
  on public.villages for select using (exists (
    select 1 from public.village_members where village_id = villages.id and profile_id = auth.uid()
  ));

create policy "owners manage villages"
  on public.villages for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "members can read membership"
  on public.village_members for select using (exists (
    select 1 from public.village_members mine where mine.village_id = village_members.village_id and mine.profile_id = auth.uid()
  ));

create policy "owners manage membership"
  on public.village_members for all using (exists (
    select 1 from public.villages where id = village_members.village_id and owner_id = auth.uid()
  ));

create policy "members can read invites"
  on public.village_invites for select using (exists (
    select 1 from public.village_members where village_id = village_invites.village_id and profile_id = auth.uid()
  ));

create policy "owners manage invites"
  on public.village_invites for all using (exists (
    select 1 from public.villages where id = village_invites.village_id and owner_id = auth.uid()
  ));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'New Hobbit'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
