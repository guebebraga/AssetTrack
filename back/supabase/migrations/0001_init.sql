-- AssetTrack - esquema inicial para Supabase/Postgres.
-- Ejecutar en el SQL Editor de Supabase o con `supabase db push`.
-- El backend usa la service_role key, por eso RLS queda habilitado sin
-- políticas públicas: el frontend nunca accede directo a las tablas.

create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  role text not null default 'viewer' check (role in ('admin', 'operator', 'viewer')),
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.asset_categories (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  name text not null,
  code_prefix text not null default '',
  description text not null default '',
  unique (organization_id, name)
);

create table if not exists public.access_points (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  name text not null,
  type text not null default 'other',
  description text not null default '',
  configured boolean not null default true
);

create table if not exists public.zones (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  name text not null,
  description text not null default '',
  active boolean not null default true
);

create table if not exists public.readers (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  name text not null,
  type text not null default 'virtual'
    check (type in ('fixed_uhf', 'handheld', 'room_sensor', 'virtual')),
  status text not null default 'active'
    check (status in ('active', 'inactive', 'maintenance')),
  access_id text references public.access_points(id) on delete set null,
  zone_id text references public.zones(id) on delete set null,
  antenna_count integer not null default 1 check (antenna_count >= 1),
  protocol text not null default 'none'
    check (protocol in ('llrp', 'mqtt', 'http', 'sdk', 'none')),
  host text not null default '',
  port integer,
  topic text not null default '',
  model text not null default '',
  firmware text not null default '',
  notes text not null default '',
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, id),
  check (not (access_id is not null and zone_id is not null))
);

create table if not exists public.suppliers (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  name text not null,
  service_type text not null default '',
  contact text not null default '',
  notes text not null default '',
  active boolean not null default true
);

create table if not exists public.assets (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  category_id text not null references public.asset_categories(id) on delete restrict,
  description text not null default '',
  rfid_epc text not null,
  location text not null default 'unknown'
    check (location in ('inside', 'outside', 'unknown', 'pendingVerification')),
  situation text not null default 'available'
    check (situation in ('available', 'inUse', 'onLoan', 'atSupplier', 'pendingReturn', 'maintenance')),
  operational_status text not null default 'operational'
    check (operational_status in ('operational', 'needsInspection', 'outOfService')),
  last_detection_at timestamptz,
  last_entry_at timestamptz,
  last_exit_at timestamptz,
  last_movement_at timestamptz,
  responsible text,
  supplier_id text references public.suppliers(id) on delete set null,
  expected_return_at timestamptz,
  created_at timestamptz not null default now(),
  last_access_id text references public.access_points(id) on delete set null,
  last_reader_id text references public.readers(id) on delete set null,
  room_id text references public.zones(id) on delete set null,
  last_room_entry_at timestamptz,
  last_room_exit_at timestamptz,
  last_room_detection_at timestamptz,
  notes text not null default '',
  unique (organization_id, code),
  unique (organization_id, rfid_epc)
);

create table if not exists public.movement_events (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  asset_id text not null references public.assets(id) on delete cascade,
  type text not null check (type in (
    'entry', 'exit', 'loan', 'loanReturn', 'supplierDelivery', 'supplierReceipt',
    'sendForRefill', 'receiveAfterRefill', 'unitExchange', 'roomEntry', 'roomExit',
    'roomTransfer', 'adminAdjustment', 'ambiguousRead', 'inventoryCorrection'
  )),
  timestamp timestamptz not null,
  origin text not null default 'manual'
    check (origin in ('rfidRead', 'manual', 'simulator', 'system', 'correction')),
  status text not null default 'confirmed'
    check (status in ('confirmed', 'pendingReview', 'rejected')),
  access_id text,
  reader_id text,
  room_id text,
  responsible text,
  supplier_id text,
  reason text not null default '',
  notes text not null default '',
  related_operation_id text,
  alert_message text
);

create table if not exists public.loans (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  asset_id text not null references public.assets(id) on delete cascade,
  borrower text not null,
  delivered_at timestamptz not null,
  due_at timestamptz,
  reason text not null default '',
  notes text not null default '',
  status text not null default 'active'
    check (status in ('active', 'returned', 'overdue', 'pendingVerification')),
  returned_at timestamptz,
  return_confirmed_inside boolean not null default false
);

create table if not exists public.supplier_operations (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  supplier_id text not null references public.suppliers(id) on delete restrict,
  delivered_asset_ids text[] not null default '{}',
  received_asset_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  due_at timestamptz,
  reason text not null default '',
  notes text not null default '',
  status text not null default 'prepared'
    check (status in ('prepared', 'delivered', 'partiallyReceived', 'completed', 'pendingReview')),
  received_at timestamptz
);

create table if not exists public.alerts (
  id text primary key,
  organization_id text not null references public.organizations(id) on delete cascade,
  type text not null check (type in (
    'outsideTooLong', 'loanOverdue', 'supplierPending', 'incompleteReturn',
    'ambiguousRead', 'noRecentDetection', 'incompatibleMovement', 'unknownReader'
  )),
  severity text not null default 'info'
    check (severity in ('info', 'warning', 'critical')),
  title text not null,
  message text not null,
  created_at timestamptz not null default now(),
  asset_id text,
  simulated boolean not null default true,
  resolved_at timestamptz,
  source text not null default 'system'
);

create table if not exists public.app_settings (
  organization_id text primary key references public.organizations(id) on delete cascade,
  organization_name text not null default 'Sanatorio Modelo',
  app_name text not null default 'AssetTrack',
  outside_threshold_hours integer not null default 72,
  dedupe_window_seconds integer not null default 30,
  alert_detection_hours integer not null default 72,
  rfid_source_name text not null default 'Lector RFID UHF simulado',
  rfid_source_status text not null default 'Simulada',
  rfid_connected boolean not null default false,
  demo_mode boolean not null default false,
  reader_antenna_count integer not null default 2,
  theme_mode_name text not null default 'system'
);

create table if not exists public.idempotency_keys (
  key text primary key,
  endpoint text not null,
  response_json jsonb not null default '{}'::jsonb,
  status_code integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists assets_org_location_idx on public.assets (organization_id, location);
create index if not exists assets_org_situation_idx on public.assets (organization_id, situation);
create index if not exists assets_org_epc_idx on public.assets (organization_id, rfid_epc);
create index if not exists movement_events_asset_ts_idx on public.movement_events (asset_id, timestamp);
create index if not exists movement_events_org_status_idx on public.movement_events (organization_id, status);
create index if not exists loans_asset_idx on public.loans (asset_id);
create index if not exists alerts_org_open_idx on public.alerts (organization_id, resolved_at);
create index if not exists readers_org_status_idx on public.readers (organization_id, status);

-- Perfil automático al crear un usuario en Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, organization_id, role, full_name)
  values (
    new.id::text,
    'org-default',
    'viewer',
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email)
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Datos mínimos de arranque. No se crean activos ficticios.
insert into public.organizations (id, name)
values ('org-default', 'Sanatorio Modelo')
on conflict (id) do nothing;

insert into public.app_settings (organization_id, organization_name, demo_mode)
values ('org-default', 'Sanatorio Modelo', false)
on conflict (organization_id) do nothing;

insert into public.asset_categories (id, organization_id, name, code_prefix, description)
values
  ('cat-oxigeno', 'org-default', 'Oxígeno', 'O2', 'Balones y contenedores de oxígeno.'),
  ('cat-equipamiento', 'org-default', 'Equipamiento', 'EQP', 'Equipos médicos y accesorios.'),
  ('cat-mobiliario', 'org-default', 'Mobiliario', 'MOB', 'Mobiliario clínico.')
on conflict (id) do nothing;

insert into public.access_points (id, organization_id, name, type, description)
values
  ('acc-principal', 'org-default', 'Entrada principal', 'main', 'Acceso principal.'),
  ('acc-proveedores', 'org-default', 'Entrada de proveedores', 'supplier', 'Andén de proveedores.'),
  ('acc-servicio', 'org-default', 'Acceso de servicio', 'service', 'Acceso de personal.')
on conflict (id) do nothing;

insert into public.zones (id, organization_id, name, description)
values
  ('zon-uti', 'org-default', 'Unidad de Terapia Intensiva', 'Área crítica.'),
  ('zon-guardia', 'org-default', 'Guardia', 'Área de urgencias.')
on conflict (id) do nothing;

insert into public.readers (
  id, organization_id, name, type, status, access_id, antenna_count, protocol, notes
)
values (
  'LEC-VIRTUAL-01', 'org-default', 'Lector virtual de pruebas', 'virtual',
  'active', 'acc-principal', 1, 'none',
  'Lector virtual para probar el simulador sin hardware.'
)
on conflict (id) do nothing;

-- RLS habilitado: solo la service_role del backend accede a las tablas.
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.asset_categories enable row level security;
alter table public.access_points enable row level security;
alter table public.zones enable row level security;
alter table public.readers enable row level security;
alter table public.suppliers enable row level security;
alter table public.assets enable row level security;
alter table public.movement_events enable row level security;
alter table public.loans enable row level security;
alter table public.supplier_operations enable row level security;
alter table public.alerts enable row level security;
alter table public.app_settings enable row level security;
alter table public.idempotency_keys enable row level security;
