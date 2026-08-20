-- Clases — esquema para los ejercicios de las clases de IA
-- Ejecutar completo en: Supabase → SQL Editor → New query → Run
-- Proyecto Supabase independiente de Fibonacci Clinic ("rosibenavides's Project")

create extension if not exists "pgcrypto";

-- ============================= CLASES =============================
create table if not exists clases (
  id uuid primary key default gen_random_uuid(),
  tema text not null,
  fecha date not null default current_date,
  notas text,
  creado_en timestamptz not null default now()
);

-- ============================= EJERCICIOS =============================
create table if not exists ejercicios (
  id uuid primary key default gen_random_uuid(),
  clase_id uuid references clases(id) on delete cascade,
  titulo text not null,
  enunciado text,
  respuesta text,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_progreso','resuelto')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

-- ============================= VISTAS =============================
create or replace view vista_resumen_clases as
select
  c.id as clase_id,
  c.tema,
  c.fecha,
  count(e.id) as total_ejercicios,
  count(e.id) filter (where e.estado = 'resuelto') as ejercicios_resueltos
from clases c
left join ejercicios e on e.clase_id = c.id
group by c.id, c.tema, c.fecha
order by c.fecha desc;

create or replace view vista_ejercicios_pendientes as
select e.id, e.titulo, e.estado, c.tema, c.fecha
from ejercicios e
join clases c on c.id = e.clase_id
where e.estado <> 'resuelto'
order by c.fecha desc;

-- ============================= SEGURIDAD (RLS) =============================
-- Solo usuarios autenticados pueden leer/escribir. Sin acceso anónimo.

alter table clases enable row level security;
alter table ejercicios enable row level security;

do $$
declare
  t text;
begin
  for t in select unnest(array['clases','ejercicios'])
  loop
    execute format('drop policy if exists "acceso_autenticado" on %I;', t);
    execute format(
      'create policy "acceso_autenticado" on %I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'');',
      t
    );
  end loop;
end $$;
