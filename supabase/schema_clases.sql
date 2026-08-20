-- Clases — esquema para los ejercicios de las clases de IA
-- Ejecutar completo en: Supabase → SQL Editor → New query → Run
-- Proyecto Supabase independiente de Fibonacci Clinic ("rosibenavides's Project")
-- Todas las tablas y vistas viven en el schema "clases" (no en "public").
--
-- IMPORTANTE: para consultar este schema desde la API de Supabase (PostgREST),
-- agrega "clases" en Project Settings → API → Exposed schemas.

create extension if not exists "pgcrypto";

create schema if not exists clases;

-- ============================= CLASES =============================
create table if not exists clases.clases (
  id uuid primary key default gen_random_uuid(),
  tema text not null,
  fecha date not null default current_date,
  notas text,
  creado_en timestamptz not null default now()
);

-- ============================= EJERCICIOS =============================
create table if not exists clases.ejercicios (
  id uuid primary key default gen_random_uuid(),
  clase_id uuid references clases.clases(id) on delete cascade,
  titulo text not null,
  enunciado text,
  respuesta text,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_progreso','resuelto')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

-- ============================= CLIENTES =============================
create table if not exists clases.clientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  email text,
  telefono text,
  notas text,
  creado_en timestamptz not null default now()
);

-- ============================= PRODUCTOS =============================
create table if not exists clases.productos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  descripcion text,
  precio numeric not null default 0,
  stock numeric not null default 0,
  creado_en timestamptz not null default now()
);

-- ============================= VISTAS =============================
create or replace view clases.vista_resumen_clases as
select
  c.id as clase_id,
  c.tema,
  c.fecha,
  count(e.id) as total_ejercicios,
  count(e.id) filter (where e.estado = 'resuelto') as ejercicios_resueltos
from clases.clases c
left join clases.ejercicios e on e.clase_id = c.id
group by c.id, c.tema, c.fecha
order by c.fecha desc;

create or replace view clases.vista_ejercicios_pendientes as
select e.id, e.titulo, e.estado, c.tema, c.fecha
from clases.ejercicios e
join clases.clases c on c.id = e.clase_id
where e.estado <> 'resuelto'
order by c.fecha desc;

-- ============================= SEGURIDAD (RLS) =============================
-- Solo usuarios autenticados pueden leer/escribir. Sin acceso anónimo.

alter table clases.clases enable row level security;
alter table clases.ejercicios enable row level security;
alter table clases.clientes enable row level security;
alter table clases.productos enable row level security;

do $$
declare
  t text;
begin
  for t in select unnest(array['clases','ejercicios','clientes','productos'])
  loop
    execute format('drop policy if exists "acceso_autenticado" on clases.%I;', t);
    execute format(
      'create policy "acceso_autenticado" on clases.%I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'');',
      t
    );
  end loop;
end $$;
