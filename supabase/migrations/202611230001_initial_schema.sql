-- TOPCLASS TRACK relational schema. Apply with: supabase db push
create extension if not exists pgcrypto;
create type public.app_role as enum ('admin','manager','receptionist','technician','customer');
create type public.job_status as enum ('Vehicle Received','Initial Inspection','Awaiting Customer Approval','Awaiting Insurance Approval','Awaiting Spare Parts','Repair Scheduled','Panel Beating','Surface Preparation and Sanding','Spray Painting','Drying and Finishing','Assembly','Polishing and Detailing','Quality Control','Ready for Collection','Vehicle Collected','Job Cancelled');

create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text not null, role public.app_role not null default 'customer', customer_id uuid, active boolean not null default true, created_at timestamptz not null default now());
create table public.customers (id uuid primary key default gen_random_uuid(), reference text unique not null default ('CUS-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))), full_name text not null, phone text not null, whatsapp text, email text, physical_address text, notes text, auth_user_id uuid unique references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
alter table public.profiles add constraint profiles_customer_fk foreign key (customer_id) references public.customers(id) on delete set null;
create table public.vehicles (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id) on delete restrict, make text not null, model text not null, year smallint check(year between 1900 and 2100), registration text not null, colour text, vin text, mileage integer check(mileage >= 0), description text, created_at timestamptz not null default now(), unique(registration));
create table public.repair_jobs (id uuid primary key default gen_random_uuid(), reference text unique not null, vehicle_id uuid not null references public.vehicles(id) on delete restrict, customer_id uuid not null references public.customers(id) on delete restrict, status public.job_status not null default 'Vehicle Received', reported_damage text, requested_services text, initial_inspection text, internal_notes text, customer_notes text, received_at timestamptz not null default now(), expected_completion date, completed_at timestamptz, created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create sequence public.repair_reference_seq;
create or replace function public.assign_repair_reference() returns trigger language plpgsql set search_path=public as $$
begin
 if new.reference is null or new.reference='' then
  new.reference := 'TC-'||to_char(coalesce(new.received_at,now()),'YYYY')||'-'||lpad(nextval('public.repair_reference_seq')::text,4,'0');
 end if;
 return new;
end $$;
create trigger repair_job_reference before insert on public.repair_jobs for each row execute function public.assign_repair_reference();
create table public.job_services (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.repair_jobs(id) on delete cascade, description text not null, completed boolean not null default false, created_at timestamptz not null default now());
create table public.repair_stage_definitions (id bigint generated always as identity primary key, name public.job_status unique not null, position smallint not null, active boolean not null default true);
insert into public.repair_stage_definitions(name,position) select s::public.job_status, n from unnest(enum_range(null::public.job_status)) with ordinality as t(s,n);
create table public.job_stage_history (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.repair_jobs(id) on delete cascade, previous_status public.job_status, new_status public.job_status not null, changed_by uuid references public.profiles(id), description text, customer_message text, created_at timestamptz not null default now(), corrected_from uuid references public.job_stage_history(id), correction_reason text);
create table public.job_photos (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.repair_jobs(id) on delete cascade, storage_path text not null, category text not null default 'inspection', description text, customer_visible boolean not null default false, uploaded_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.job_documents (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.repair_jobs(id) on delete cascade, storage_path text not null, document_type text not null, filename text not null, customer_visible boolean not null default false, uploaded_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.quotations (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.repair_jobs(id) on delete cascade, version integer not null default 1, currency char(3) not null default 'USD', subtotal numeric(12,2) not null default 0, discount numeric(12,2) not null default 0, tax numeric(12,2) not null default 0, total numeric(12,2) not null default 0, deposit_required numeric(12,2) not null default 0, balance_due numeric(12,2) not null default 0, status text not null default 'draft' check(status in ('draft','sent','approved','declined','superseded')), created_by uuid references public.profiles(id), created_at timestamptz not null default now(), unique(job_id,version));
create table public.quotation_items (id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id) on delete cascade, category text not null check(category in ('labour','parts','materials','service','discount','tax')), description text not null, quantity numeric(10,2) not null default 1, unit_price numeric(12,2) not null, amount numeric(12,2) generated always as (quantity*unit_price) stored);
create table public.customer_approvals (id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id) on delete cascade, customer_id uuid not null references public.customers(id), decision text not null check(decision in ('approved','declined')), decided_at timestamptz not null default now(), notes text);
create table public.notifications (id uuid primary key default gen_random_uuid(), customer_id uuid references public.customers(id) on delete cascade, job_id uuid references public.repair_jobs(id) on delete cascade, channel text not null default 'in_app' check(channel in ('in_app','email','whatsapp')), event_type text not null, title text not null, body text not null, delivery_status text not null default 'pending', delivery_error text, read_at timestamptz, created_at timestamptz not null default now());
create table public.staff_assignments (job_id uuid not null references public.repair_jobs(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade, assigned_by uuid references public.profiles(id), assigned_at timestamptz not null default now(), primary key(job_id,profile_id));
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), entity_type text not null, entity_id uuid not null, action text not null, before_data jsonb, after_data jsonb, created_at timestamptz not null default now());

create index vehicles_customer_idx on public.vehicles(customer_id);
create index vehicles_registration_idx on public.vehicles(registration);
create index jobs_customer_idx on public.repair_jobs(customer_id);
create index jobs_vehicle_idx on public.repair_jobs(vehicle_id);
create index jobs_status_idx on public.repair_jobs(status);
create index jobs_due_idx on public.repair_jobs(expected_completion) where completed_at is null;
create index stage_history_job_idx on public.job_stage_history(job_id,created_at desc);
create index notification_customer_idx on public.notifications(customer_id,created_at desc);
create index photos_job_idx on public.job_photos(job_id,created_at desc);

create or replace function public.current_role() returns public.app_role language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() and active $$;
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path=public as $$ select coalesce(public.current_role() <> 'customer',false) $$;
create or replace function public.owns_customer(cid uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.customers c where c.id=cid and c.auth_user_id=auth.uid()) $$;

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.repair_jobs enable row level security;
alter table public.job_services enable row level security;
alter table public.repair_stage_definitions enable row level security;
alter table public.job_stage_history enable row level security;
alter table public.job_photos enable row level security;
alter table public.job_documents enable row level security;
alter table public.quotations enable row level security;
alter table public.quotation_items enable row level security;
alter table public.customer_approvals enable row level security;
alter table public.notifications enable row level security;
alter table public.staff_assignments enable row level security;
alter table public.audit_logs enable row level security;

create policy profile_self_or_admin on public.profiles for select using(id=auth.uid() or public.current_role()='admin');
create policy profile_admin_write on public.profiles for all using(public.current_role()='admin') with check(public.current_role()='admin');
create policy customer_staff_or_owner on public.customers for select using(public.is_staff() or auth_user_id=auth.uid());
create policy customer_staff_write on public.customers for all using(public.is_staff()) with check(public.is_staff());
create policy vehicle_staff_or_owner on public.vehicles for select using(public.is_staff() or public.owns_customer(customer_id));
create policy vehicle_staff_write on public.vehicles for all using(public.is_staff()) with check(public.is_staff());
create policy jobs_staff_or_owner on public.repair_jobs for select using(public.is_staff() or public.owns_customer(customer_id));
create policy jobs_staff_write on public.repair_jobs for all using(public.current_role() in ('admin','manager','receptionist')) with check(public.current_role() in ('admin','manager','receptionist'));
create policy services_read on public.job_services for select using(exists(select 1 from public.repair_jobs j where j.id=job_id and (public.is_staff() or public.owns_customer(j.customer_id))));
create policy services_write on public.job_services for all using(public.is_staff()) with check(public.is_staff());
create policy stage_def_read on public.repair_stage_definitions for select using(true);
create policy stage_def_admin on public.repair_stage_definitions for all using(public.current_role()='admin') with check(public.current_role()='admin');
create policy history_read on public.job_stage_history for select using(exists(select 1 from public.repair_jobs j where j.id=job_id and (public.is_staff() or public.owns_customer(j.customer_id))));
create policy history_staff_write on public.job_stage_history for insert with check(public.is_staff());
create policy history_manager_corrections on public.job_stage_history for update using(public.current_role() in ('admin','manager')) with check(public.current_role() in ('admin','manager'));
create policy photos_read on public.job_photos for select using(exists(select 1 from public.repair_jobs j where j.id=job_id and (public.is_staff() or (public.owns_customer(j.customer_id) and customer_visible))));
create policy photos_staff_write on public.job_photos for all using(public.is_staff()) with check(public.is_staff());
create policy docs_read on public.job_documents for select using(exists(select 1 from public.repair_jobs j where j.id=job_id and (public.is_staff() or (public.owns_customer(j.customer_id) and customer_visible))));
create policy docs_staff_write on public.job_documents for all using(public.is_staff()) with check(public.is_staff());
create policy quotes_read on public.quotations for select using(exists(select 1 from public.repair_jobs j where j.id=job_id and (public.is_staff() or (public.owns_customer(j.customer_id) and status<>'draft'))));
create policy quotes_staff_write on public.quotations for all using(public.current_role() in ('admin','manager')) with check(public.current_role() in ('admin','manager'));
create policy quote_items_read on public.quotation_items for select using(exists(select 1 from public.quotations q join public.repair_jobs j on j.id=q.job_id where q.id=quotation_id and (public.is_staff() or (public.owns_customer(j.customer_id) and q.status<>'draft'))));
create policy quote_items_staff_write on public.quotation_items for all using(public.current_role() in ('admin','manager')) with check(public.current_role() in ('admin','manager'));
create policy approvals_read on public.customer_approvals for select using(public.is_staff() or public.owns_customer(customer_id));
create policy approvals_owner_insert on public.customer_approvals for insert with check(public.owns_customer(customer_id));
create policy notifications_read on public.notifications for select using(public.is_staff() or public.owns_customer(customer_id));
create policy notifications_owner_update on public.notifications for update using(public.owns_customer(customer_id)) with check(public.owns_customer(customer_id));
create policy notifications_staff_insert on public.notifications for insert with check(public.is_staff());
create policy assignments_read on public.staff_assignments for select using(public.is_staff());
create policy assignments_manager_write on public.staff_assignments for all using(public.current_role() in ('admin','manager')) with check(public.current_role() in ('admin','manager'));
create policy audit_admin_read on public.audit_logs for select using(public.current_role()='admin');
create policy audit_staff_insert on public.audit_logs for insert with check(public.is_staff());

-- Atomic stage transition: a technician can update only a job assigned to them.
-- Each transition writes history, an in-app notification, and an audit event together.
create or replace function public.transition_job_stage(p_job_id uuid,p_new_status public.job_status,p_description text,p_customer_message text)
returns public.repair_jobs language plpgsql security definer set search_path=public as $$
declare prior public.repair_jobs; updated public.repair_jobs; actor_role public.app_role;
begin
 actor_role := public.current_role();
 if actor_role is null or actor_role='customer' then raise exception 'Not authorized'; end if;
 if actor_role='technician' and not exists(select 1 from public.staff_assignments where job_id=p_job_id and profile_id=auth.uid()) then raise exception 'Job is not assigned to this technician'; end if;
 select * into prior from public.repair_jobs where id=p_job_id for update;
 if not found then raise exception 'Repair job not found'; end if;
 update public.repair_jobs set status=p_new_status,customer_notes=coalesce(p_customer_message,customer_notes),updated_at=now(),completed_at=case when p_new_status='Vehicle Collected' then now() else completed_at end where id=p_job_id returning * into updated;
 insert into public.job_stage_history(job_id,previous_status,new_status,changed_by,description,customer_message) values(p_job_id,prior.status,p_new_status,auth.uid(),p_description,p_customer_message);
 insert into public.notifications(customer_id,job_id,channel,event_type,title,body,delivery_status) values(updated.customer_id,p_job_id,'in_app','repair_stage_changed','Repair update: '||p_new_status,coalesce(p_customer_message,p_description,'Your repair stage has changed.'),'delivered');
 insert into public.audit_logs(actor_id,entity_type,entity_id,action,before_data,after_data) values(auth.uid(),'repair_job',p_job_id,'stage_changed',jsonb_build_object('status',prior.status),jsonb_build_object('status',updated.status));
 return updated;
end $$;
revoke all on function public.transition_job_stage(uuid,public.job_status,text,text) from public, anon;
grant execute on function public.transition_job_stage(uuid,public.job_status,text,text) to authenticated;

-- Row policies scope records; these column grants also keep staff-only fields
-- such as internal_notes and technician descriptions out of customer queries.
revoke select on public.repair_jobs from authenticated;
grant select (id,reference,vehicle_id,customer_id,status,reported_damage,requested_services,initial_inspection,customer_notes,received_at,expected_completion,completed_at,created_at,updated_at) on public.repair_jobs to authenticated;
revoke select on public.job_stage_history from authenticated;
grant select (id,job_id,new_status,customer_message,created_at) on public.job_stage_history to authenticated;

-- Private storage buckets. Browser clients never receive service role credentials.
insert into storage.buckets(id,name,public) values('job-photos','job-photos',false),('job-documents','job-documents',false) on conflict(id) do nothing;
create policy storage_staff_read on storage.objects for select using(bucket_id in ('job-photos','job-documents') and public.is_staff());
create policy storage_customer_visible_read on storage.objects for select using(bucket_id='job-photos' and exists(select 1 from public.job_photos p join public.repair_jobs j on j.id=p.job_id where p.storage_path=name and p.customer_visible and public.owns_customer(j.customer_id)));
create policy storage_staff_upload on storage.objects for insert with check(bucket_id in ('job-photos','job-documents') and public.is_staff());
create policy storage_staff_update on storage.objects for update using(bucket_id in ('job-photos','job-documents') and public.is_staff());
