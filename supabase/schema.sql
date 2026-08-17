-- Fibonacci Clinic — esquema de base de datos para Supabase
-- Ejecutar completo en: Supabase → SQL Editor → New query → Run

create extension if not exists "pgcrypto";

-- ============================= INSUMOS =============================
create table if not exists insumos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  categoria text,
  unidad_medida text not null,
  stock_actual numeric not null default 0,
  stock_minimo numeric not null default 0,
  costo_unitario numeric not null default 0,
  proveedor text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table if not exists movimientos_inventario (
  id uuid primary key default gen_random_uuid(),
  insumo_id uuid references insumos(id) on delete set null,
  tipo text not null check (tipo in ('entrada','salida')),
  cantidad numeric not null,
  motivo text,
  referencia_id uuid,
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- ============================= TRATAMIENTOS =============================
create table if not exists tratamientos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  descripcion text,
  tiempo_estimado_min integer not null default 0,
  precio_venta numeric not null default 0,
  activo boolean not null default true
);

create table if not exists tratamiento_insumos (
  id uuid primary key default gen_random_uuid(),
  tratamiento_id uuid not null references tratamientos(id) on delete cascade,
  insumo_id uuid not null references insumos(id) on delete cascade,
  cantidad numeric not null
);

-- ============================= PACIENTES =============================
create table if not exists pacientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  telefono text,
  email text,
  notas text,
  creado_en timestamptz not null default now()
);

-- ============================= RESERVAS =============================
create table if not exists reservas (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete set null,
  tratamiento_id uuid references tratamientos(id) on delete set null,
  fecha date not null,
  hora time not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','confirmada','atendida','cancelada')),
  notas text
);

-- ============================= VENTAS =============================
create table if not exists ventas (
  id uuid primary key default gen_random_uuid(),
  fecha date not null default current_date,
  paciente_id uuid references pacientes(id) on delete set null,
  metodo_pago text,
  monto_total numeric not null default 0,
  reserva_id uuid references reservas(id) on delete set null,
  creado_en timestamptz not null default now()
);

create table if not exists venta_tratamientos (
  id uuid primary key default gen_random_uuid(),
  venta_id uuid not null references ventas(id) on delete cascade,
  tratamiento_id uuid references tratamientos(id) on delete set null,
  precio numeric not null
);

-- ============================= SEGURIDAD (RLS) =============================
-- Solo usuarios autenticados (tu login de Supabase Auth) pueden leer/escribir.
-- Los visitantes anónimos no tienen ningún acceso.

alter table insumos enable row level security;
alter table movimientos_inventario enable row level security;
alter table tratamientos enable row level security;
alter table tratamiento_insumos enable row level security;
alter table pacientes enable row level security;
alter table reservas enable row level security;
alter table ventas enable row level security;
alter table venta_tratamientos enable row level security;

do $$
declare
  t text;
begin
  for t in select unnest(array[
    'insumos','movimientos_inventario','tratamientos','tratamiento_insumos',
    'pacientes','reservas','ventas','venta_tratamientos'
  ])
  loop
    execute format('drop policy if exists "acceso_autenticado" on %I;', t);
    execute format(
      'create policy "acceso_autenticado" on %I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'');',
      t
    );
  end loop;
end $$;

-- ============================= TIEMPO REAL =============================
-- Permite que la app reciba cambios en vivo (multi-dispositivo) vía Supabase Realtime.
do $$
declare
  t text;
begin
  for t in select unnest(array[
    'insumos','movimientos_inventario','tratamientos','tratamiento_insumos',
    'pacientes','reservas','ventas','venta_tratamientos'
  ])
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I;', t);
    end if;
  end loop;
end $$;
