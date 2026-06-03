-- ════════════════════════════════════════════════════════════════════
--  PrefOS · Supabase Setup
--  Mehrmandanten-Plattform für Spielerentwicklung (TIPS/U)
--
--  Hierarchie:
--    Super-Admin  →  Verein (club)  →  Team  →  Spieler + Bewertungen
--
--  Rollen:
--    super_admin   = Plattform-Besitzer (du). Legt Vereine, Logins, Methodik an.
--    club_admin    = Vereins-Admin. Sieht & verwaltet ALLE Teams seines Vereins.
--    coach         = Trainer. Sieht nur die Teams, denen er zugewiesen ist.
--                    Pro Team-Zuweisung zusätzlich: head_coach | assistant.
--
--  Zugriff hängt an der Mitgliedschaft (club_members / super_admins),
--  NICHT nur am Eingeloggt-Sein  →  durchgesetzt per Row Level Security.
--
--  AUSFÜHRUNG: Supabase Dashboard → SQL Editor → komplett einfügen → RUN.
-- ════════════════════════════════════════════════════════════════════

-- Sauberer Neustart (nur ausführen, wenn du wirklich alles neu willst):
-- drop schema if exists prefos cascade;

-- ──────────────────────────────────────────────────────────────────
-- 1) TABELLEN
-- ──────────────────────────────────────────────────────────────────

-- Plattform-Besitzer (du). Eintrag per E-Mail; user_id wird beim 1. Login verknüpft.
create table if not exists super_admins (
  email      text primary key,
  user_id    uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Vereine. Die Methodik (Dimensionen/Zyklen/Skala/Detailbogen) liegt als JSON
-- direkt am Verein → so kann jeder Verein vom Standard abweichen.
create table if not exists clubs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  short       text default '',
  methodology jsonb not null default '{}'::jsonb,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Die 2–5 Logins pro Verein. role: 'club_admin' oder 'coach'.
-- email wird vom Super-Admin autorisiert; user_id beim 1. Login verknüpft.
create table if not exists club_members (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs(id) on delete cascade,
  email      text not null,
  user_id    uuid references auth.users(id) on delete set null,
  role       text not null default 'coach' check (role in ('club_admin','coach')),
  display    text default '',
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  unique (club_id, email)
);

-- Teams eines Vereins.
create table if not exists teams (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs(id) on delete cascade,
  name       text not null,
  season     text default '',
  created_at timestamptz not null default now()
);

-- Trainer-Zuweisung pro Team. role: 'head_coach' (Cheftrainer) | 'assistant'.
create table if not exists team_assignments (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  member_id  uuid not null references club_members(id) on delete cascade,
  role       text not null default 'assistant' check (role in ('head_coach','assistant')),
  created_at timestamptz not null default now(),
  unique (team_id, member_id)
);

-- ── Daten-Tabellen (jetzt pro TEAM getrennt) ──────────────────────

create table if not exists players (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  nr         text default '',
  name       text not null,
  geb        text default '',
  fuss       text default 'R',
  nat        text default '',
  verein     text default '',
  tw         boolean default false,
  rae        boolean default false,
  deleted    boolean default false,
  created_at timestamptz not null default now()
);

create table if not exists ratings (
  id        uuid primary key default gen_random_uuid(),
  team_id   uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  cycle     text not null,
  dim       text not null,
  ist       numeric,
  soll      numeric,
  massnahme text default '',
  unique (player_id, cycle, dim)
);

create table if not exists notes (
  id        uuid primary key default gen_random_uuid(),
  team_id   uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  cycle     text not null,
  content   text default '',
  unique (player_id, cycle)
);

create table if not exists player_meta (
  player_id uuid primary key references players(id) on delete cascade,
  team_id   uuid not null references teams(id) on delete cascade,
  position  text default '',
  defizit   text default '',
  staerke   text default ''
);

create table if not exists si_data (
  player_id   uuid primary key references players(id) on delete cascade,
  team_id     uuid not null references teams(id) on delete cascade,
  wahrnehmen  integer default 0,
  loesungen   integer default 0,
  entscheidung integer default 0,
  gegen_ball  integer default 0
);

create table if not exists tips_detail (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  player_id  uuid not null references players(id) on delete cascade,
  cycle      text not null,
  scores     jsonb default '{}'::jsonb,
  beobachter text default '',
  entwicklung text default '',
  unique (player_id, cycle)
);

create table if not exists activity_log (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references teams(id) on delete cascade,
  user_email  text,
  log_date    date not null default current_date,
  area        text,
  player_id   uuid,
  player_name text,
  action_type text,
  cycle       text,
  details     text,
  created_at  timestamptz not null default now(),
  unique (team_id, user_email, log_date, area)
);

-- Spiele / Matches (pro Team)
create table if not exists matches (
  id           uuid primary key default gen_random_uuid(),
  team_id      uuid not null references teams(id) on delete cascade,
  typ          text default 'testspiel',
  gegner       text default '',
  datum        date,
  ort          text default '',
  tore_eigen   integer,
  tore_gegner  integer,
  hz_eigen     integer,
  hz_gegner    integer,
  torschuetzen text default '',
  bericht      text default '',
  created_at   timestamptz not null default now()
);

create table if not exists match_players (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  match_id   uuid not null references matches(id) on delete cascade,
  player_id  uuid not null references players(id) on delete cascade,
  dabei      boolean default false,
  note       numeric,
  kommentar  text default '',
  unique (match_id, player_id)
);

-- Indizes
create index if not exists idx_players_team   on players(team_id);
create index if not exists idx_ratings_team    on ratings(team_id);
create index if not exists idx_notes_team      on notes(team_id);
create index if not exists idx_meta_team        on player_meta(team_id);
create index if not exists idx_si_team          on si_data(team_id);
create index if not exists idx_tips_team        on tips_detail(team_id);
create index if not exists idx_log_team         on activity_log(team_id);
create index if not exists idx_matches_team     on matches(team_id);
create index if not exists idx_mplayers_team    on match_players(team_id);
create index if not exists idx_mplayers_match   on match_players(match_id);
create index if not exists idx_members_club     on club_members(club_id);
create index if not exists idx_assign_team      on team_assignments(team_id);

-- ──────────────────────────────────────────────────────────────────
-- 2) HILFSFUNKTIONEN (für RLS) — SECURITY DEFINER, stabil
-- ──────────────────────────────────────────────────────────────────

-- Ist der aktuelle User Plattform-Besitzer?
create or replace function is_super_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from super_admins where user_id = auth.uid());
$$;

-- Vereine, in denen der aktuelle User Mitglied ist
create or replace function my_member_club_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select club_id from club_members where user_id = auth.uid() and active;
$$;

-- Ist der User Vereins-Admin im angegebenen Verein?
create or replace function is_club_admin(p_club uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from club_members
    where user_id = auth.uid() and active and role = 'club_admin' and club_id = p_club
  );
$$;

-- Alle Team-IDs, auf die der aktuelle User Zugriff hat:
--  super_admin → alle Teams
--  club_admin  → alle Teams seiner Vereine
--  coach       → nur zugewiesene Teams
create or replace function my_team_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  -- super admin: alles
  select t.id from teams t where is_super_admin()
  union
  -- club_admin: alle Teams seiner Vereine
  select t.id from teams t
    join club_members m on m.club_id = t.club_id
   where m.user_id = auth.uid() and m.active and m.role = 'club_admin'
  union
  -- coach: zugewiesene Teams
  select ta.team_id from team_assignments ta
    join club_members m on m.id = ta.member_id
   where m.user_id = auth.uid() and m.active;
$$;

-- Rolle des Users in einem konkreten Team ('head_coach' | 'assistant' | null)
create or replace function my_team_role(p_team uuid)
returns text language sql stable security definer set search_path = public as $$
  select ta.role from team_assignments ta
    join club_members m on m.id = ta.member_id
   where m.user_id = auth.uid() and m.active and ta.team_id = p_team
   limit 1;
$$;

-- Darf der User in diesem Team LÖSCHEN (Spieler etc.)?
--  super_admin, club_admin (des Vereins) und head_coach dürfen. assistant nicht.
create or replace function can_delete_in_team(p_team uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    is_super_admin()
    or exists (
      select 1 from teams t
       where t.id = p_team and is_club_admin(t.club_id)
    )
    or my_team_role(p_team) = 'head_coach';
$$;

-- ──────────────────────────────────────────────────────────────────
-- 3) ONBOARDING: Zugriff beim 1. Login verknüpfen
--    Der Super-Admin / Verein-Admin autorisiert eine E-Mail.
--    Beim ersten Login ruft die App claim_access() auf → user_id wird gesetzt.
-- ──────────────────────────────────────────────────────────────────
create or replace function claim_access()
returns void language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  mail text := lower(coalesce((auth.jwt() ->> 'email'), ''));
begin
  if uid is null or mail = '' then return; end if;
  update super_admins set user_id = uid
    where lower(email) = mail and user_id is distinct from uid;
  update club_members set user_id = uid
    where lower(email) = mail and user_id is null;
end;
$$;

-- Liefert das komplette Zugriffsprofil des eingeloggten Users (für die App)
create or replace function my_access()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'is_super_admin', is_super_admin(),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'member_id', m.id, 'club_id', m.club_id, 'club_name', c.name,
        'club_short', c.short, 'role', m.role
      ))
      from club_members m join clubs c on c.id = m.club_id
      where m.user_id = auth.uid() and m.active
    ), '[]'::jsonb),
    'teams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'team_id', t.id, 'team_name', t.name, 'season', t.season,
        'club_id', t.club_id, 'team_role', my_team_role(t.id)
      ))
      from teams t where t.id in (select my_team_ids())
    ), '[]'::jsonb)
  );
$$;

-- ──────────────────────────────────────────────────────────────────
-- 4) ROW LEVEL SECURITY
-- ──────────────────────────────────────────────────────────────────
alter table super_admins      enable row level security;
alter table clubs             enable row level security;
alter table club_members      enable row level security;
alter table teams             enable row level security;
alter table team_assignments  enable row level security;
alter table players           enable row level security;
alter table ratings           enable row level security;
alter table notes             enable row level security;
alter table player_meta       enable row level security;
alter table si_data           enable row level security;
alter table tips_detail       enable row level security;
alter table activity_log      enable row level security;
alter table matches           enable row level security;
alter table match_players     enable row level security;

-- super_admins: jeder darf seine eigene Zeile per E-Mail sehen (für claim);
-- ändern darf nur ein bestehender Super-Admin.
drop policy if exists sa_select on super_admins;
create policy sa_select on super_admins for select using (
  is_super_admin() or lower(email) = lower(coalesce(auth.jwt() ->> 'email',''))
);
drop policy if exists sa_all on super_admins;
create policy sa_all on super_admins for all using (is_super_admin()) with check (is_super_admin());

-- clubs: super_admin alles; Mitglieder dürfen ihren Verein lesen.
drop policy if exists clubs_sel on clubs;
create policy clubs_sel on clubs for select using (
  is_super_admin() or id in (select my_member_club_ids())
);
drop policy if exists clubs_write on clubs;
create policy clubs_write on clubs for all
  using (is_super_admin() or is_club_admin(id))
  with check (is_super_admin() or is_club_admin(id));

-- club_members: super_admin alles; club_admin verwaltet sein Verein;
-- jeder darf seine eigene Mitgliedszeile lesen (für claim/Profil).
drop policy if exists cm_sel on club_members;
create policy cm_sel on club_members for select using (
  is_super_admin() or is_club_admin(club_id)
  or club_id in (select my_member_club_ids())
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email',''))
);
drop policy if exists cm_write on club_members;
create policy cm_write on club_members for all
  using (is_super_admin() or is_club_admin(club_id))
  with check (is_super_admin() or is_club_admin(club_id));

-- teams: les-/schreibbar wenn Zugriff aufs Team ODER club_admin/super
drop policy if exists teams_sel on teams;
create policy teams_sel on teams for select using (
  is_super_admin() or is_club_admin(club_id) or id in (select my_team_ids())
);
drop policy if exists teams_write on teams;
create policy teams_write on teams for all
  using (is_super_admin() or is_club_admin(club_id))
  with check (is_super_admin() or is_club_admin(club_id));

-- team_assignments: verwalten = super/club_admin; lesen = wer Teamzugriff hat
drop policy if exists ta_sel on team_assignments;
create policy ta_sel on team_assignments for select using (
  is_super_admin() or team_id in (select my_team_ids())
  or exists (select 1 from teams t where t.id = team_id and is_club_admin(t.club_id))
);
drop policy if exists ta_write on team_assignments;
create policy ta_write on team_assignments for all
  using (is_super_admin() or exists (select 1 from teams t where t.id = team_id and is_club_admin(t.club_id)))
  with check (is_super_admin() or exists (select 1 from teams t where t.id = team_id and is_club_admin(t.club_id)));

-- ── Daten-Tabellen: Zugriff nur wenn team_id in my_team_ids() ──
-- Lesen + Einfügen + Ändern: jeder mit Teamzugriff (auch assistant).
-- Löschen: nur can_delete_in_team() (head_coach / club_admin / super).

-- players
drop policy if exists pl_sel on players;
create policy pl_sel on players for select using (team_id in (select my_team_ids()));
drop policy if exists pl_ins on players;
create policy pl_ins on players for insert with check (team_id in (select my_team_ids()));
drop policy if exists pl_upd on players;
create policy pl_upd on players for update using (team_id in (select my_team_ids())) with check (team_id in (select my_team_ids()));
drop policy if exists pl_del on players;
create policy pl_del on players for delete using (can_delete_in_team(team_id));

-- Generische Policies für die übrigen Daten-Tabellen (voller Zugriff bei Teamzugehörigkeit)
do $$
declare tbl text;
begin
  foreach tbl in array array['ratings','notes','player_meta','si_data','tips_detail','activity_log','matches','match_players']
  loop
    execute format('drop policy if exists %1$s_all on %1$s;', tbl);
    execute format(
      'create policy %1$s_all on %1$s for all using (team_id in (select my_team_ids())) with check (team_id in (select my_team_ids()));',
      tbl);
  end loop;
end$$;

-- ──────────────────────────────────────────────────────────────────
-- 5) STANDARD-METHODIK (TIPS/U) als Vorlage
--    Wird beim Anlegen eines Vereins als Startwert verwendet; jeder Verein
--    darf danach abweichen.
-- ──────────────────────────────────────────────────────────────────
create or replace function default_methodology()
returns jsonb language sql immutable as $$
  select '{
    "dims": [
      {"key":"T","name":"Technik","color":"#e07b39","sub":["Ballkontrolle","Passqualität","Dribbling 1v1","Abschluss"]},
      {"key":"I","name":"Spielintelligenz","color":"#6366f1","sub":["Vororientierung","Entscheidung","Lösungen o.Ball","Umschalten"]},
      {"key":"P","name":"Persönlichkeit","color":"#10b981","sub":["Motivation","Resilienz","Coachability","Teamfähigkeit"]},
      {"key":"S","name":"Schnelligkeit","color":"#f59e0b","sub":["Sprintkraft","Agilität","Kognitive Schnelligkeit","Ausdauer"]},
      {"key":"U","name":"Umfeld","color":"#3b82f6","sub":["Schule/Fussball","Fam. Support","Eigenverantwortung","Logistik"]}
    ],
    "cycles": [
      {"key":"z1","short":"Z1","label":"Diagnostik","sub":"Phase 1"},
      {"key":"z2","short":"Z2","label":"Hinrunde","sub":"Phase 2"},
      {"key":"z3","short":"Z3","label":"Winterpause","sub":"Phase 3"},
      {"key":"z4","short":"Z4","label":"Abschluss","sub":"Phase 4"}
    ],
    "scale": {"min":1,"max":4,"step":0.25},
    "si": {"fields":["wahrnehmen","loesungen","entscheidung","gegen_ball"],
           "labels":["Wahrnehmen","Lösungen","Entscheidung","Gegen Ball"]},
    "tips_cats": [
      {"key":"T","title":"Technik","desc":"Fliessende Bewegungen · Präzision · Dosierung","motto":"«Der Ball ist sein/ihr Freund!»","items":[
        "hat einen kontrollierten, dynamischen und orientierten 1. Kontakt",
        "überzeugt durch enges, rhythmisches Ballführen",
        "hat den Ball auch unter Druck unter Kontrolle (Innen-, Aussen-, Vollrist, Sohle, Ferse)",
        "beherrscht Drehungen / Richtungswechsel auf beide Seiten",
        "beherrscht verschiedene Finten und setzt diese im 1vs1 gezielt ein",
        "dosiert die Pässe je nach Spielsituation richtig",
        "schiesst und passt beidfüssig präzise"]},
      {"key":"I","title":"Intelligent","desc":"Spielidee · Orientierung · Entscheid","motto":"«Er/Sie bietet und findet Lösungen!»","items":[
        "orientiert sich durch Schulterblick und offene Körperposition",
        "behält die Übersicht und trifft schnelle, richtige Entscheidungen",
        "erkennt und schafft freie Räume",
        "erkennt und schafft Überzahlsituationen",
        "erkennt Unterzahlsituationen und kann diese lösen",
        "antizipiert die Spielsituation und -entwicklung",
        "verhält sich im offensiven 1v1 richtig",
        "verhält sich im defensiven 1v1 richtig",
        "bleibt in der Box cool und abgebrüht"]},
      {"key":"P","title":"Persönlichkeit","desc":"Selbstvertrauen · Motivation · Respekt","motto":"«Er/Sie hat und gibt Energie!»","items":[
        "zeigt Emotionen und Spielfreude",
        "ist initiativ und will den Ball",
        "stellt sich schwierigen Herausforderungen",
        "ist ehrgeizig und will jedes Duell gewinnen",
        "riskiert etwas, ist mutig und entschlossen",
        "dirigiert und unterstützt seine Mitspieler",
        "überzeugt durch positive Körpersprache",
        "spielt fair und respektiert die Regeln",
        "ist respektvoll und übernimmt Verantwortung"]},
      {"key":"S","title":"Athletik / Schnelligkeit","desc":"Explosivität · Dynamik","motto":"«Er/Sie beschleunigt das Spiel!»","items":[
        "ist stets bereit und steht auf dem Vorderfuss",
        "startet blitzschnell und kraftvoll",
        "variiert das Tempo mit und ohne Ball",
        "präsentiert viele Sprints mit hoher Intensität",
        "attackiert den freien Raum dynamisch",
        "reagiert rasch auf neue Spielsituationen"]}
    ]
  }'::jsonb;
$$;

-- Verein anlegen (nur Super-Admin) inkl. Standard-Methodik + erstem Admin-Login
create or replace function create_club(p_name text, p_short text, p_admin_email text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_club uuid;
begin
  if not is_super_admin() then raise exception 'Nur Super-Admin'; end if;
  insert into clubs(name, short, methodology) values (p_name, p_short, default_methodology())
    returning id into new_club;
  if p_admin_email is not null and length(trim(p_admin_email)) > 0 then
    insert into club_members(club_id, email, role, display)
      values (new_club, lower(trim(p_admin_email)), 'club_admin', '')
      on conflict do nothing;
  end if;
  return new_club;
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 6) SEED — HIER ANPASSEN
--    Trage deine eigene Login-E-Mail als Super-Admin ein.
-- ──────────────────────────────────────────────────────────────────
insert into super_admins(email) values ('dein-login@beispiel.ch')
  on conflict (email) do nothing;

-- Optionaler Demo-Verein zum Ausprobieren (kannst du später löschen):
do $$
declare demo uuid; t uuid;
begin
  if not exists (select 1 from clubs where short = 'DEMO') then
    insert into clubs(name, short, methodology)
      values ('Demo Sportverein', 'DEMO', default_methodology()) returning id into demo;
    insert into club_members(club_id, email, role, display)
      values (demo, 'demo-admin@beispiel.ch', 'club_admin', 'Demo Admin');
    insert into teams(club_id, name, season) values (demo, 'F-Junioren', '2026/27') returning id into t;
    insert into players(team_id, nr, name, geb, fuss, nat, verein, tw) values
      (t,'01','Beispiel, Max','01.01.2016','R','CH','Demo Sportverein', false),
      (t,'02','Muster, Lena','02.02.2016','L','CH','Demo Sportverein', true);
  end if;
end$$;

-- ──────────────────────────────────────────────────────────────────
-- FERTIG.
-- Nächste Schritte:
--  1) In Supabase → Authentication → Providers → Email: "Confirm email" ggf.
--     ausschalten, damit autorisierte Personen direkt einloggen können.
--  2) Lege dein eigenes Auth-Konto an (Authentication → Add user) mit genau
--     der E-Mail, die oben als super_admin steht.
--  3) PrefOS öffnen, einloggen → claim_access() verknüpft dich automatisch.
-- ══════════════════════════════════════════════════════════════════
