-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public IS 'standard public schema';

-- DROP TYPE public."booking_status";

CREATE TYPE public."booking_status" AS ENUM (
	'inquiry',
	'pending',
	'confirmed',
	'checked_in',
	'shooting',
	'production',
	'ready',
	'delivered',
	'completed',
	'cancelled');

-- DROP TYPE public."employee_status";

CREATE TYPE public."employee_status" AS ENUM (
	'active',
	'inactive',
	'terminated');

-- DROP TYPE public."expense_status";

CREATE TYPE public."expense_status" AS ENUM (
	'draft',
	'approved',
	'paid',
	'void');

-- DROP TYPE public."invoice_status";

CREATE TYPE public."invoice_status" AS ENUM (
	'draft',
	'issued',
	'partially_paid',
	'paid',
	'void',
	'overdue');

-- DROP TYPE public."member_role";

CREATE TYPE public."member_role" AS ENUM (
	'owner',
	'admin',
	'manager',
	'photographer',
	'editor',
	'staff');

-- DROP TYPE public."payment_status";

CREATE TYPE public."payment_status" AS ENUM (
	'unpaid',
	'partial',
	'paid',
	'refunded');

-- DROP TYPE public."production_status";

CREATE TYPE public."production_status" AS ENUM (
	'waiting',
	'in_progress',
	'review',
	'revision',
	'approved',
	'completed');

-- DROP TYPE public."subscription_status";

CREATE TYPE public."subscription_status" AS ENUM (
	'trialing',
	'active',
	'past_due',
	'paused',
	'cancelled');

-- DROP TYPE public."task_status";

CREATE TYPE public."task_status" AS ENUM (
	'todo',
	'in_progress',
	'review',
	'revision',
	'done',
	'cancelled');

-- DROP TYPE public."tenant_status";

CREATE TYPE public."tenant_status" AS ENUM (
	'trial',
	'active',
	'suspended',
	'cancelled');
-- public."plans" definition

-- Drop table

-- DROP TABLE public."plans";

CREATE TABLE public."plans" ( id uuid DEFAULT gen_random_uuid() NOT NULL, code text NOT NULL, "name" text NOT NULL, description text NULL, price_monthly numeric(14, 2) DEFAULT 0 NOT NULL, price_yearly numeric(14, 2) DEFAULT 0 NOT NULL, max_members int4 NULL, max_locations int4 NULL, max_storage_bytes int8 NULL, features jsonb DEFAULT '{}'::jsonb NOT NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT plans_code_key UNIQUE (code), CONSTRAINT plans_pkey PRIMARY KEY (id), CONSTRAINT plans_price_monthly_check CHECK ((price_monthly >= (0)::numeric)), CONSTRAINT plans_price_yearly_check CHECK ((price_yearly >= (0)::numeric)));

-- Table Triggers

create trigger trg_plans_updated_at before
update
    on
    public.plans for each row execute function set_updated_at();
ALTER TABLE public."plans" ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY plans_authenticated_select ON public."plans"
 AS PERMISSIVE
 FOR SELECT
 TO authenticated
 USING ((is_active = true));

-- Permissions

ALTER TABLE public."plans" OWNER TO postgres;
GRANT ALL ON TABLE public."plans" TO postgres;
GRANT ALL ON TABLE public."plans" TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public."plans" TO service_role;


-- public.tenants definition

-- Drop table

-- DROP TABLE public.tenants;

CREATE TABLE public.tenants ( id uuid DEFAULT gen_random_uuid() NOT NULL, "name" text NOT NULL, slug text NOT NULL, status public."tenant_status" DEFAULT 'trial'::tenant_status NOT NULL, email text NULL, phone text NULL, timezone text DEFAULT 'Asia/Jakarta'::text NOT NULL, currency_code bpchar(3) DEFAULT 'IDR'::bpchar NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT tenants_pkey PRIMARY KEY (id), CONSTRAINT tenants_slug_key UNIQUE (slug));

-- Table Triggers

create trigger trg_tenants_updated_at before
update
    on
    public.tenants for each row execute function set_updated_at();
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY tenants_select_member ON public.tenants
 AS PERMISSIVE
 FOR SELECT
 TO authenticated
 USING (is_tenant_member(id));
CREATE POLICY tenants_update_admin ON public.tenants
 AS PERMISSIVE
 FOR UPDATE
 TO authenticated
 USING (has_tenant_role(id, ARRAY['owner'::member_role, 'admin'::member_role]))
 WITH CHECK (has_tenant_role(id, ARRAY['owner'::member_role, 'admin'::member_role]));

-- Permissions

ALTER TABLE public.tenants OWNER TO postgres;
GRANT ALL ON TABLE public.tenants TO postgres;
GRANT ALL ON TABLE public.tenants TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.tenants TO service_role;


-- public.addons definition

-- Drop table

-- DROP TABLE public.addons;

CREATE TABLE public.addons ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, "name" text NOT NULL, description text NULL, price numeric(14, 2) DEFAULT 0 NOT NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT addons_pkey PRIMARY KEY (id), CONSTRAINT addons_price_check CHECK ((price >= (0)::numeric)), CONSTRAINT addons_tenant_id_name_key UNIQUE (tenant_id, name), CONSTRAINT addons_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_addons_tenant_active ON public.addons USING btree (tenant_id, is_active);

-- Table Triggers

create trigger trg_addons_updated_at before
update
    on
    public.addons for each row execute function set_updated_at();
ALTER TABLE public.addons ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY addons_member_all ON public.addons
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.addons OWNER TO postgres;
GRANT ALL ON TABLE public.addons TO postgres;
GRANT ALL ON TABLE public.addons TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.addons TO service_role;


-- public.customers definition

-- Drop table

-- DROP TABLE public.customers;

CREATE TABLE public.customers ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, code text NULL, full_name text NOT NULL, email text NULL, phone text NULL, notes text NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT customers_pkey PRIMARY KEY (id), CONSTRAINT customers_tenant_id_code_key UNIQUE (tenant_id, code), CONSTRAINT customers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_customers_tenant_name ON public.customers USING btree (tenant_id, full_name);
CREATE INDEX idx_customers_tenant_phone ON public.customers USING btree (tenant_id, phone);

-- Table Triggers

create trigger trg_customers_updated_at before
update
    on
    public.customers for each row execute function set_updated_at();
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY customers_member_all ON public.customers
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.customers OWNER TO postgres;
GRANT ALL ON TABLE public.customers TO postgres;
GRANT ALL ON TABLE public.customers TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.customers TO service_role;


-- public.expense_categories definition

-- Drop table

-- DROP TABLE public.expense_categories;

CREATE TABLE public.expense_categories ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, "name" text NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT expense_categories_pkey PRIMARY KEY (id), CONSTRAINT expense_categories_tenant_id_name_key UNIQUE (tenant_id, name), CONSTRAINT expense_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY expense_categories_member_all ON public.expense_categories
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.expense_categories OWNER TO postgres;
GRANT ALL ON TABLE public.expense_categories TO postgres;
GRANT ALL ON TABLE public.expense_categories TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.expense_categories TO service_role;


-- public.packages definition

-- Drop table

-- DROP TABLE public.packages;

CREATE TABLE public.packages ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, "name" text NOT NULL, description text NULL, base_price numeric(14, 2) DEFAULT 0 NOT NULL, base_duration_minutes int4 NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, max_people int4 NULL, requires_photographer bool DEFAULT false NOT NULL, requires_room bool DEFAULT false NOT NULL, included_people int4 NULL, extra_duration_price_per_minute numeric(14, 2) DEFAULT 0 NOT NULL, extra_person_price numeric(14, 2) DEFAULT 0 NOT NULL, CONSTRAINT packages_base_price_check CHECK ((base_price >= (0)::numeric)), CONSTRAINT packages_duration_minutes_check CHECK (((base_duration_minutes IS NULL) OR (base_duration_minutes > 0))), CONSTRAINT packages_extra_duration_price_check CHECK ((extra_duration_price_per_minute >= (0)::numeric)), CONSTRAINT packages_extra_person_price_check CHECK ((extra_person_price >= (0)::numeric)), CONSTRAINT packages_included_people_check CHECK (((included_people IS NULL) OR (included_people > 0))), CONSTRAINT packages_max_people_check CHECK (((max_people IS NULL) OR (max_people > 0))), CONSTRAINT packages_people_limit_check CHECK (((max_people IS NULL) OR (included_people IS NULL) OR (max_people >= included_people))), CONSTRAINT packages_pkey PRIMARY KEY (id), CONSTRAINT packages_tenant_id_name_key UNIQUE (tenant_id, name), CONSTRAINT packages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_packages_tenant_active ON public.packages USING btree (tenant_id, is_active);

-- Table Triggers

create trigger trg_packages_updated_at before
update
    on
    public.packages for each row execute function set_updated_at();
ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY packages_member_all ON public.packages
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.packages OWNER TO postgres;
GRANT ALL ON TABLE public.packages TO postgres;
GRANT ALL ON TABLE public.packages TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.packages TO service_role;


-- public.services definition

-- Drop table

-- DROP TABLE public.services;

CREATE TABLE public.services ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, "name" text NOT NULL, description text NULL, base_price numeric(14, 2) DEFAULT 0 NOT NULL, duration_minutes int4 NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT services_base_price_check CHECK ((base_price >= (0)::numeric)), CONSTRAINT services_duration_minutes_check CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0))), CONSTRAINT services_pkey PRIMARY KEY (id), CONSTRAINT services_tenant_id_name_key UNIQUE (tenant_id, name), CONSTRAINT services_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_services_tenant_active ON public.services USING btree (tenant_id, is_active);

-- Table Triggers

create trigger trg_services_updated_at before
update
    on
    public.services for each row execute function set_updated_at();
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY services_member_all ON public.services
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.services OWNER TO postgres;
GRANT ALL ON TABLE public.services TO postgres;
GRANT ALL ON TABLE public.services TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.services TO service_role;


-- public.studio_locations definition

-- Drop table

-- DROP TABLE public.studio_locations;

CREATE TABLE public.studio_locations ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, "name" text NOT NULL, address text NULL, city text NULL, postal_code text NULL, phone text NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT studio_locations_pkey PRIMARY KEY (id), CONSTRAINT studio_locations_tenant_id_name_key UNIQUE (tenant_id, name), CONSTRAINT studio_locations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_studio_locations_tenant ON public.studio_locations USING btree (tenant_id);

-- Table Triggers

create trigger trg_studio_locations_updated_at before
update
    on
    public.studio_locations for each row execute function set_updated_at();
ALTER TABLE public.studio_locations ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY studio_locations_member_all ON public.studio_locations
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.studio_locations OWNER TO postgres;
GRANT ALL ON TABLE public.studio_locations TO postgres;
GRANT ALL ON TABLE public.studio_locations TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.studio_locations TO service_role;


-- public.studio_profiles definition

-- Drop table

-- DROP TABLE public.studio_profiles;

CREATE TABLE public.studio_profiles ( tenant_id uuid NOT NULL, display_name text NOT NULL, legal_name text NULL, logo_url text NULL, website_url text NULL, email text NULL, phone text NULL, address text NULL, tax_id text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT studio_profiles_pkey PRIMARY KEY (tenant_id), CONSTRAINT studio_profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);

-- Table Triggers

create trigger trg_studio_profiles_updated_at before
update
    on
    public.studio_profiles for each row execute function set_updated_at();
ALTER TABLE public.studio_profiles ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY studio_profiles_member_all ON public.studio_profiles
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.studio_profiles OWNER TO postgres;
GRANT ALL ON TABLE public.studio_profiles TO postgres;
GRANT ALL ON TABLE public.studio_profiles TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.studio_profiles TO service_role;


-- public.studio_rooms definition

-- Drop table

-- DROP TABLE public.studio_rooms;

CREATE TABLE public.studio_rooms ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, location_id uuid NOT NULL, "name" text NOT NULL, capacity int4 NULL, description text NULL, is_active bool DEFAULT true NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT studio_rooms_location_id_name_key UNIQUE (location_id, name), CONSTRAINT studio_rooms_pkey PRIMARY KEY (id), CONSTRAINT studio_rooms_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.studio_locations(id) ON DELETE CASCADE, CONSTRAINT studio_rooms_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_studio_rooms_tenant ON public.studio_rooms USING btree (tenant_id, location_id);

-- Table Triggers

create trigger trg_studio_rooms_updated_at before
update
    on
    public.studio_rooms for each row execute function set_updated_at();
ALTER TABLE public.studio_rooms ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY studio_rooms_member_all ON public.studio_rooms
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.studio_rooms OWNER TO postgres;
GRANT ALL ON TABLE public.studio_rooms TO postgres;
GRANT ALL ON TABLE public.studio_rooms TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.studio_rooms TO service_role;


-- public.subscriptions definition

-- Drop table

-- DROP TABLE public.subscriptions;

CREATE TABLE public.subscriptions ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, plan_id uuid NOT NULL, status public."subscription_status" DEFAULT 'trialing'::subscription_status NOT NULL, trial_ends_at timestamptz NULL, current_period_start timestamptz NULL, current_period_end timestamptz NULL, provider text NULL, provider_subscription_id text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT subscriptions_pkey PRIMARY KEY (id), CONSTRAINT subscriptions_tenant_id_key UNIQUE (tenant_id), CONSTRAINT subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public."plans"(id) ON DELETE RESTRICT, CONSTRAINT subscriptions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_subscriptions_plan_status ON public.subscriptions USING btree (plan_id, status);

-- Table Triggers

create trigger trg_subscriptions_updated_at before
update
    on
    public.subscriptions for each row execute function set_updated_at();
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY subscriptions_member_select ON public.subscriptions
 AS PERMISSIVE
 FOR SELECT
 TO authenticated
 USING (is_tenant_member(tenant_id));
CREATE POLICY subscriptions_owner_update ON public.subscriptions
 AS PERMISSIVE
 FOR UPDATE
 TO authenticated
 USING (has_tenant_role(tenant_id, ARRAY['owner'::member_role]))
 WITH CHECK (has_tenant_role(tenant_id, ARRAY['owner'::member_role]));

-- Permissions

ALTER TABLE public.subscriptions OWNER TO postgres;
GRANT ALL ON TABLE public.subscriptions TO postgres;
GRANT ALL ON TABLE public.subscriptions TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.subscriptions TO service_role;


-- public.customer_addresses definition

-- Drop table

-- DROP TABLE public.customer_addresses;

CREATE TABLE public.customer_addresses ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, customer_id uuid NOT NULL, "label" text NULL, address text NOT NULL, city text NULL, postal_code text NULL, is_primary bool DEFAULT false NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT customer_addresses_pkey PRIMARY KEY (id), CONSTRAINT customer_addresses_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE, CONSTRAINT customer_addresses_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_customer_addresses_customer ON public.customer_addresses USING btree (tenant_id, customer_id);
ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY customer_addresses_member_all ON public.customer_addresses
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.customer_addresses OWNER TO postgres;
GRANT ALL ON TABLE public.customer_addresses TO postgres;
GRANT ALL ON TABLE public.customer_addresses TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.customer_addresses TO service_role;


-- public.customer_contacts definition

-- Drop table

-- DROP TABLE public.customer_contacts;

CREATE TABLE public.customer_contacts ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, customer_id uuid NOT NULL, "label" text NULL, contact_type text NOT NULL, contact_value text NOT NULL, is_primary bool DEFAULT false NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT customer_contacts_pkey PRIMARY KEY (id), CONSTRAINT customer_contacts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE, CONSTRAINT customer_contacts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_customer_contacts_customer ON public.customer_contacts USING btree (tenant_id, customer_id);
ALTER TABLE public.customer_contacts ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY customer_contacts_member_all ON public.customer_contacts
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.customer_contacts OWNER TO postgres;
GRANT ALL ON TABLE public.customer_contacts TO postgres;
GRANT ALL ON TABLE public.customer_contacts TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.customer_contacts TO service_role;


-- public.package_items definition

-- Drop table

-- DROP TABLE public.package_items;

CREATE TABLE public.package_items ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, package_id uuid NOT NULL, service_id uuid NULL, addon_id uuid NULL, quantity int4 DEFAULT 1 NOT NULL, notes text NULL, CONSTRAINT package_items_check CHECK ((((service_id IS NOT NULL) AND (addon_id IS NULL)) OR ((service_id IS NULL) AND (addon_id IS NOT NULL)))), CONSTRAINT package_items_pkey PRIMARY KEY (id), CONSTRAINT package_items_quantity_check CHECK ((quantity > 0)), CONSTRAINT package_items_addon_id_fkey FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE RESTRICT, CONSTRAINT package_items_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.packages(id) ON DELETE CASCADE, CONSTRAINT package_items_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE RESTRICT, CONSTRAINT package_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE);
CREATE INDEX idx_package_items_package ON public.package_items USING btree (tenant_id, package_id);
ALTER TABLE public.package_items ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY package_items_member_all ON public.package_items
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.package_items OWNER TO postgres;
GRANT ALL ON TABLE public.package_items TO postgres;
GRANT ALL ON TABLE public.package_items TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.package_items TO service_role;


-- public.availability definition

-- Drop table

-- DROP TABLE public.availability;

CREATE TABLE public.availability ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, employee_id uuid NULL, room_id uuid NULL, weekday int2 NULL, starts_at time NOT NULL, ends_at time NOT NULL, is_available bool DEFAULT true NOT NULL, CONSTRAINT availability_check CHECK ((ends_at > starts_at)), CONSTRAINT availability_pkey PRIMARY KEY (id), CONSTRAINT availability_weekday_check CHECK (((weekday >= 0) AND (weekday <= 6))));
CREATE INDEX idx_availability_tenant ON public.availability USING btree (tenant_id, weekday);
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY availability_member_all ON public.availability
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.availability OWNER TO postgres;
GRANT ALL ON TABLE public.availability TO postgres;
GRANT ALL ON TABLE public.availability TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.availability TO service_role;


-- public.booking_assignees definition

-- Drop table

-- DROP TABLE public.booking_assignees;

CREATE TABLE public.booking_assignees ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_id uuid NOT NULL, employee_id uuid NOT NULL, assignment_role text DEFAULT 'photographer'::text NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT booking_assignees_booking_id_employee_id_assignment_role_key UNIQUE (booking_id, employee_id, assignment_role), CONSTRAINT booking_assignees_pkey PRIMARY KEY (id));
CREATE INDEX idx_booking_assignees_employee ON public.booking_assignees USING btree (tenant_id, employee_id);
ALTER TABLE public.booking_assignees ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY booking_assignees_member_all ON public.booking_assignees
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.booking_assignees OWNER TO postgres;
GRANT ALL ON TABLE public.booking_assignees TO postgres;
GRANT ALL ON TABLE public.booking_assignees TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.booking_assignees TO service_role;


-- public.booking_items definition

-- Drop table

-- DROP TABLE public.booking_items;

CREATE TABLE public.booking_items ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_id uuid NOT NULL, service_id uuid NULL, addon_id uuid NULL, description text NOT NULL, quantity int4 DEFAULT 1 NOT NULL, unit_price numeric(14, 2) DEFAULT 0 NOT NULL, total_price numeric(14, 2) DEFAULT 0 NOT NULL, CONSTRAINT booking_items_pkey PRIMARY KEY (id), CONSTRAINT booking_items_quantity_check CHECK ((quantity > 0)), CONSTRAINT booking_items_total_price_check CHECK ((total_price >= (0)::numeric)), CONSTRAINT booking_items_unit_price_check CHECK ((unit_price >= (0)::numeric)));
CREATE INDEX idx_booking_items_booking ON public.booking_items USING btree (tenant_id, booking_id);
ALTER TABLE public.booking_items ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY booking_items_member_all ON public.booking_items
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.booking_items OWNER TO postgres;
GRANT ALL ON TABLE public.booking_items TO postgres;
GRANT ALL ON TABLE public.booking_items TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.booking_items TO service_role;


-- public.booking_notes definition

-- Drop table

-- DROP TABLE public.booking_notes;

CREATE TABLE public.booking_notes ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_id uuid NOT NULL, body text NOT NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT booking_notes_pkey PRIMARY KEY (id));
CREATE INDEX idx_booking_notes_booking ON public.booking_notes USING btree (tenant_id, booking_id, created_at DESC);
ALTER TABLE public.booking_notes ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY booking_notes_member_all ON public.booking_notes
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.booking_notes OWNER TO postgres;
GRANT ALL ON TABLE public.booking_notes TO postgres;
GRANT ALL ON TABLE public.booking_notes TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.booking_notes TO service_role;


-- public.booking_status_history definition

-- Drop table

-- DROP TABLE public.booking_status_history;

CREATE TABLE public.booking_status_history ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_id uuid NOT NULL, from_status public."booking_status" NULL, to_status public."booking_status" NOT NULL, changed_by uuid NULL, note text NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT booking_status_history_pkey PRIMARY KEY (id));
CREATE INDEX idx_booking_status_history_booking ON public.booking_status_history USING btree (tenant_id, booking_id, created_at DESC);
ALTER TABLE public.booking_status_history ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY booking_status_history_member_all ON public.booking_status_history
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.booking_status_history OWNER TO postgres;
GRANT ALL ON TABLE public.booking_status_history TO postgres;
GRANT ALL ON TABLE public.booking_status_history TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.booking_status_history TO service_role;


-- public.bookings definition

-- Drop table

-- DROP TABLE public.bookings;

CREATE TABLE public.bookings ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_number text NOT NULL, customer_id uuid NOT NULL, package_id uuid NULL, location_id uuid NULL, room_id uuid NULL, starts_at timestamptz NOT NULL, ends_at timestamptz NULL, status public."booking_status" DEFAULT 'pending'::booking_status NOT NULL, "payment_status" public."payment_status" DEFAULT 'unpaid'::payment_status NOT NULL, subtotal numeric(14, 2) DEFAULT 0 NOT NULL, discount_amount numeric(14, 2) DEFAULT 0 NOT NULL, tax_amount numeric(14, 2) DEFAULT 0 NOT NULL, total_amount numeric(14, 2) DEFAULT 0 NOT NULL, notes text NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, participant_count int4 DEFAULT 1 NOT NULL, CONSTRAINT bookings_check CHECK (((ends_at IS NULL) OR (ends_at > starts_at))), CONSTRAINT bookings_discount_amount_check CHECK ((discount_amount >= (0)::numeric)), CONSTRAINT bookings_participant_count_check CHECK ((participant_count > 0)), CONSTRAINT bookings_pkey PRIMARY KEY (id), CONSTRAINT bookings_subtotal_check CHECK ((subtotal >= (0)::numeric)), CONSTRAINT bookings_tax_amount_check CHECK ((tax_amount >= (0)::numeric)), CONSTRAINT bookings_tenant_id_booking_number_key UNIQUE (tenant_id, booking_number), CONSTRAINT bookings_total_amount_check CHECK ((total_amount >= (0)::numeric)));
CREATE INDEX idx_bookings_customer ON public.bookings USING btree (tenant_id, customer_id);
CREATE INDEX idx_bookings_tenant_start ON public.bookings USING btree (tenant_id, starts_at);
CREATE INDEX idx_bookings_tenant_status ON public.bookings USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_bookings_updated_at before
update
    on
    public.bookings for each row execute function set_updated_at();
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY bookings_member_all ON public.bookings
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.bookings OWNER TO postgres;
GRANT ALL ON TABLE public.bookings TO postgres;
GRANT ALL ON TABLE public.bookings TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.bookings TO service_role;


-- public.calendar_events definition

-- Drop table

-- DROP TABLE public.calendar_events;

CREATE TABLE public.calendar_events ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, title text NOT NULL, description text NULL, starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, booking_id uuid NULL, employee_id uuid NULL, room_id uuid NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT calendar_events_check CHECK ((ends_at > starts_at)), CONSTRAINT calendar_events_pkey PRIMARY KEY (id));
CREATE INDEX idx_calendar_events_tenant_start ON public.calendar_events USING btree (tenant_id, starts_at);

-- Table Triggers

create trigger trg_calendar_events_updated_at before
update
    on
    public.calendar_events for each row execute function set_updated_at();
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY calendar_events_member_all ON public.calendar_events
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.calendar_events OWNER TO postgres;
GRANT ALL ON TABLE public.calendar_events TO postgres;
GRANT ALL ON TABLE public.calendar_events TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.calendar_events TO service_role;


-- public.employees definition

-- Drop table

-- DROP TABLE public.employees;

CREATE TABLE public.employees ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, user_id uuid NULL, employee_code text NULL, full_name text NOT NULL, email text NULL, phone text NULL, status public."employee_status" DEFAULT 'active'::employee_status NOT NULL, "position" text NULL, hired_at date NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT employees_pkey PRIMARY KEY (id), CONSTRAINT employees_tenant_id_employee_code_key UNIQUE (tenant_id, employee_code));
CREATE INDEX idx_employees_tenant_status ON public.employees USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_employees_updated_at before
update
    on
    public.employees for each row execute function set_updated_at();
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY employees_member_all ON public.employees
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.employees OWNER TO postgres;
GRANT ALL ON TABLE public.employees TO postgres;
GRANT ALL ON TABLE public.employees TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.employees TO service_role;


-- public.expenses definition

-- Drop table

-- DROP TABLE public.expenses;

CREATE TABLE public.expenses ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, category_id uuid NULL, description text NOT NULL, amount numeric(14, 2) NOT NULL, expense_date date DEFAULT CURRENT_DATE NOT NULL, status public."expense_status" DEFAULT 'draft'::expense_status NOT NULL, paid_at timestamptz NULL, notes text NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT expenses_amount_check CHECK ((amount >= (0)::numeric)), CONSTRAINT expenses_pkey PRIMARY KEY (id));
CREATE INDEX idx_expenses_tenant_date ON public.expenses USING btree (tenant_id, expense_date DESC);
CREATE INDEX idx_expenses_tenant_status ON public.expenses USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_expenses_updated_at before
update
    on
    public.expenses for each row execute function set_updated_at();
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY expenses_member_all ON public.expenses
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.expenses OWNER TO postgres;
GRANT ALL ON TABLE public.expenses TO postgres;
GRANT ALL ON TABLE public.expenses TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.expenses TO service_role;


-- public.invoice_items definition

-- Drop table

-- DROP TABLE public.invoice_items;

CREATE TABLE public.invoice_items ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, invoice_id uuid NOT NULL, description text NOT NULL, quantity int4 DEFAULT 1 NOT NULL, unit_price numeric(14, 2) DEFAULT 0 NOT NULL, total_price numeric(14, 2) DEFAULT 0 NOT NULL, CONSTRAINT invoice_items_pkey PRIMARY KEY (id), CONSTRAINT invoice_items_quantity_check CHECK ((quantity > 0)), CONSTRAINT invoice_items_total_price_check CHECK ((total_price >= (0)::numeric)), CONSTRAINT invoice_items_unit_price_check CHECK ((unit_price >= (0)::numeric)));
CREATE INDEX idx_invoice_items_invoice ON public.invoice_items USING btree (tenant_id, invoice_id);
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY invoice_items_member_all ON public.invoice_items
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.invoice_items OWNER TO postgres;
GRANT ALL ON TABLE public.invoice_items TO postgres;
GRANT ALL ON TABLE public.invoice_items TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.invoice_items TO service_role;


-- public.invoices definition

-- Drop table

-- DROP TABLE public.invoices;

CREATE TABLE public.invoices ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, invoice_number text NOT NULL, booking_id uuid NULL, customer_id uuid NOT NULL, status public."invoice_status" DEFAULT 'draft'::invoice_status NOT NULL, issued_at timestamptz NULL, due_at timestamptz NULL, subtotal numeric(14, 2) DEFAULT 0 NOT NULL, discount_amount numeric(14, 2) DEFAULT 0 NOT NULL, tax_amount numeric(14, 2) DEFAULT 0 NOT NULL, total_amount numeric(14, 2) DEFAULT 0 NOT NULL, notes text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT invoices_discount_amount_check CHECK ((discount_amount >= (0)::numeric)), CONSTRAINT invoices_pkey PRIMARY KEY (id), CONSTRAINT invoices_subtotal_check CHECK ((subtotal >= (0)::numeric)), CONSTRAINT invoices_tax_amount_check CHECK ((tax_amount >= (0)::numeric)), CONSTRAINT invoices_tenant_id_invoice_number_key UNIQUE (tenant_id, invoice_number), CONSTRAINT invoices_total_amount_check CHECK ((total_amount >= (0)::numeric)));
CREATE INDEX idx_invoices_customer ON public.invoices USING btree (tenant_id, customer_id);
CREATE INDEX idx_invoices_tenant_status ON public.invoices USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_invoices_updated_at before
update
    on
    public.invoices for each row execute function set_updated_at();
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY invoices_member_all ON public.invoices
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.invoices OWNER TO postgres;
GRANT ALL ON TABLE public.invoices TO postgres;
GRANT ALL ON TABLE public.invoices TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.invoices TO service_role;


-- public.media_assets definition

-- Drop table

-- DROP TABLE public.media_assets;

CREATE TABLE public.media_assets ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, folder_id uuid NULL, booking_id uuid NULL, storage_bucket text DEFAULT 'studio-media'::text NOT NULL, storage_path text NOT NULL, file_name text NOT NULL, mime_type text NULL, file_size int8 NULL, media_kind text NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT media_assets_pkey PRIMARY KEY (id), CONSTRAINT media_assets_storage_bucket_storage_path_key UNIQUE (storage_bucket, storage_path));
CREATE INDEX idx_media_assets_booking ON public.media_assets USING btree (tenant_id, booking_id);
CREATE INDEX idx_media_assets_folder ON public.media_assets USING btree (tenant_id, folder_id);
ALTER TABLE public.media_assets ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY media_assets_member_all ON public.media_assets
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.media_assets OWNER TO postgres;
GRANT ALL ON TABLE public.media_assets TO postgres;
GRANT ALL ON TABLE public.media_assets TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.media_assets TO service_role;


-- public.media_folders definition

-- Drop table

-- DROP TABLE public.media_folders;

CREATE TABLE public.media_folders ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, parent_id uuid NULL, booking_id uuid NULL, "name" text NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT media_folders_pkey PRIMARY KEY (id), CONSTRAINT media_folders_tenant_id_parent_id_name_key UNIQUE (tenant_id, parent_id, name));
CREATE INDEX idx_media_folders_tenant ON public.media_folders USING btree (tenant_id, parent_id);
ALTER TABLE public.media_folders ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY media_folders_member_all ON public.media_folders
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.media_folders OWNER TO postgres;
GRANT ALL ON TABLE public.media_folders TO postgres;
GRANT ALL ON TABLE public.media_folders TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.media_folders TO service_role;


-- public.payments definition

-- Drop table

-- DROP TABLE public.payments;

CREATE TABLE public.payments ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, invoice_id uuid NOT NULL, payment_reference text NULL, amount numeric(14, 2) NOT NULL, paid_at timestamptz DEFAULT now() NOT NULL, "method" text NOT NULL, status public."payment_status" DEFAULT 'paid'::payment_status NOT NULL, provider text NULL, provider_transaction_id text NULL, notes text NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT payments_amount_check CHECK ((amount > (0)::numeric)), CONSTRAINT payments_pkey PRIMARY KEY (id));
CREATE INDEX idx_payments_invoice ON public.payments USING btree (tenant_id, invoice_id, paid_at DESC);
CREATE INDEX idx_payments_tenant_date ON public.payments USING btree (tenant_id, paid_at DESC);
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY payments_member_all ON public.payments
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.payments OWNER TO postgres;
GRANT ALL ON TABLE public.payments TO postgres;
GRANT ALL ON TABLE public.payments TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.payments TO service_role;


-- public.production_orders definition

-- Drop table

-- DROP TABLE public.production_orders;

CREATE TABLE public.production_orders ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, booking_id uuid NOT NULL, status public."production_status" DEFAULT 'waiting'::production_status NOT NULL, due_at timestamptz NULL, notes text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT production_orders_booking_id_key UNIQUE (booking_id), CONSTRAINT production_orders_pkey PRIMARY KEY (id));
CREATE INDEX idx_production_orders_tenant_status ON public.production_orders USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_production_orders_updated_at before
update
    on
    public.production_orders for each row execute function set_updated_at();
ALTER TABLE public.production_orders ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY production_orders_member_all ON public.production_orders
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.production_orders OWNER TO postgres;
GRANT ALL ON TABLE public.production_orders TO postgres;
GRANT ALL ON TABLE public.production_orders TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.production_orders TO service_role;


-- public.production_task_assignments definition

-- Drop table

-- DROP TABLE public.production_task_assignments;

CREATE TABLE public.production_task_assignments ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, task_id uuid NOT NULL, employee_id uuid NOT NULL, assigned_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT production_task_assignments_pkey PRIMARY KEY (id), CONSTRAINT production_task_assignments_task_id_employee_id_key UNIQUE (task_id, employee_id));
CREATE INDEX idx_production_task_assignments_employee ON public.production_task_assignments USING btree (tenant_id, employee_id);
ALTER TABLE public.production_task_assignments ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY production_task_assignments_member_all ON public.production_task_assignments
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.production_task_assignments OWNER TO postgres;
GRANT ALL ON TABLE public.production_task_assignments TO postgres;
GRANT ALL ON TABLE public.production_task_assignments TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.production_task_assignments TO service_role;


-- public.production_tasks definition

-- Drop table

-- DROP TABLE public.production_tasks;

CREATE TABLE public.production_tasks ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, production_order_id uuid NOT NULL, title text NOT NULL, description text NULL, status public."task_status" DEFAULT 'todo'::task_status NOT NULL, sort_order int4 DEFAULT 0 NOT NULL, due_at timestamptz NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT production_tasks_pkey PRIMARY KEY (id));
CREATE INDEX idx_production_tasks_order ON public.production_tasks USING btree (tenant_id, production_order_id, sort_order);
CREATE INDEX idx_production_tasks_status ON public.production_tasks USING btree (tenant_id, status);

-- Table Triggers

create trigger trg_production_tasks_updated_at before
update
    on
    public.production_tasks for each row execute function set_updated_at();
ALTER TABLE public.production_tasks ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY production_tasks_member_all ON public.production_tasks
 AS PERMISSIVE
 FOR ALL
 TO authenticated
 USING (is_tenant_member(tenant_id))
 WITH CHECK (is_tenant_member(tenant_id));

-- Permissions

ALTER TABLE public.production_tasks OWNER TO postgres;
GRANT ALL ON TABLE public.production_tasks TO postgres;
GRANT ALL ON TABLE public.production_tasks TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.production_tasks TO service_role;


-- public.profiles definition

-- Drop table

-- DROP TABLE public.profiles;

CREATE TABLE public.profiles ( id uuid NOT NULL, full_name text NULL, avatar_url text NULL, phone text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT profiles_pkey PRIMARY KEY (id));

-- Table Triggers

create trigger trg_profiles_updated_at before
update
    on
    public.profiles for each row execute function set_updated_at();
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY profiles_insert_own ON public.profiles
 AS PERMISSIVE
 FOR INSERT
 TO authenticated
 WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY profiles_select_own ON public.profiles
 AS PERMISSIVE
 FOR SELECT
 TO authenticated
 USING ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY profiles_update_own ON public.profiles
 AS PERMISSIVE
 FOR UPDATE
 TO authenticated
 USING ((id = ( SELECT auth.uid() AS uid)))
 WITH CHECK ((id = ( SELECT auth.uid() AS uid)));

-- Permissions

ALTER TABLE public.profiles OWNER TO postgres;
GRANT ALL ON TABLE public.profiles TO postgres;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.profiles TO service_role;


-- public.tenant_members definition

-- Drop table

-- DROP TABLE public.tenant_members;

CREATE TABLE public.tenant_members ( id uuid DEFAULT gen_random_uuid() NOT NULL, tenant_id uuid NOT NULL, user_id uuid NOT NULL, "role" public."member_role" DEFAULT 'staff'::member_role NOT NULL, is_active bool DEFAULT true NOT NULL, joined_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT tenant_members_pkey PRIMARY KEY (id), CONSTRAINT tenant_members_tenant_id_user_id_key UNIQUE (tenant_id, user_id));
CREATE INDEX idx_tenant_members_tenant ON public.tenant_members USING btree (tenant_id, role) WHERE (is_active = true);
CREATE INDEX idx_tenant_members_user ON public.tenant_members USING btree (user_id, tenant_id) WHERE (is_active = true);
ALTER TABLE public.tenant_members ENABLE ROW LEVEL SECURITY;

-- Table Policies

CREATE POLICY tenant_members_delete_admin ON public.tenant_members
 AS PERMISSIVE
 FOR DELETE
 TO authenticated
 USING (has_tenant_role(tenant_id, ARRAY['owner'::member_role, 'admin'::member_role]));
CREATE POLICY tenant_members_insert_admin ON public.tenant_members
 AS PERMISSIVE
 FOR INSERT
 TO authenticated
 WITH CHECK (has_tenant_role(tenant_id, ARRAY['owner'::member_role, 'admin'::member_role]));
CREATE POLICY tenant_members_select_member ON public.tenant_members
 AS PERMISSIVE
 FOR SELECT
 TO authenticated
 USING (is_tenant_member(tenant_id));
CREATE POLICY tenant_members_update_admin ON public.tenant_members
 AS PERMISSIVE
 FOR UPDATE
 TO authenticated
 USING (has_tenant_role(tenant_id, ARRAY['owner'::member_role, 'admin'::member_role]))
 WITH CHECK (has_tenant_role(tenant_id, ARRAY['owner'::member_role, 'admin'::member_role]));

-- Permissions

ALTER TABLE public.tenant_members OWNER TO postgres;
GRANT ALL ON TABLE public.tenant_members TO postgres;
GRANT ALL ON TABLE public.tenant_members TO authenticated;
GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLE public.tenant_members TO service_role;


-- public.availability foreign keys

ALTER TABLE public.availability ADD CONSTRAINT availability_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
ALTER TABLE public.availability ADD CONSTRAINT availability_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.studio_rooms(id) ON DELETE CASCADE;
ALTER TABLE public.availability ADD CONSTRAINT availability_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.booking_assignees foreign keys

ALTER TABLE public.booking_assignees ADD CONSTRAINT booking_assignees_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_assignees ADD CONSTRAINT booking_assignees_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE RESTRICT;
ALTER TABLE public.booking_assignees ADD CONSTRAINT booking_assignees_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.booking_items foreign keys

ALTER TABLE public.booking_items ADD CONSTRAINT booking_items_addon_id_fkey FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE SET NULL;
ALTER TABLE public.booking_items ADD CONSTRAINT booking_items_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_items ADD CONSTRAINT booking_items_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE SET NULL;
ALTER TABLE public.booking_items ADD CONSTRAINT booking_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.booking_notes foreign keys

ALTER TABLE public.booking_notes ADD CONSTRAINT booking_notes_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_notes ADD CONSTRAINT booking_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.booking_notes ADD CONSTRAINT booking_notes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.booking_status_history foreign keys

ALTER TABLE public.booking_status_history ADD CONSTRAINT booking_status_history_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_status_history ADD CONSTRAINT booking_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.booking_status_history ADD CONSTRAINT booking_status_history_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.bookings foreign keys

ALTER TABLE public.bookings ADD CONSTRAINT bookings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.studio_locations(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.packages(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.studio_rooms(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.calendar_events foreign keys

ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.studio_rooms(id) ON DELETE SET NULL;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.employees foreign keys

ALTER TABLE public.employees ADD CONSTRAINT employees_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
ALTER TABLE public.employees ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


-- public.expenses foreign keys

ALTER TABLE public.expenses ADD CONSTRAINT expenses_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.expense_categories(id) ON DELETE SET NULL;
ALTER TABLE public.expenses ADD CONSTRAINT expenses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.expenses ADD CONSTRAINT expenses_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.invoice_items foreign keys

ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;
ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.invoices foreign keys

ALTER TABLE public.invoices ADD CONSTRAINT invoices_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.media_assets foreign keys

ALTER TABLE public.media_assets ADD CONSTRAINT media_assets_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.media_assets ADD CONSTRAINT media_assets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.media_assets ADD CONSTRAINT media_assets_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.media_folders(id) ON DELETE SET NULL;
ALTER TABLE public.media_assets ADD CONSTRAINT media_assets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.media_folders foreign keys

ALTER TABLE public.media_folders ADD CONSTRAINT media_folders_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.media_folders ADD CONSTRAINT media_folders_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.media_folders(id) ON DELETE CASCADE;
ALTER TABLE public.media_folders ADD CONSTRAINT media_folders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.payments foreign keys

ALTER TABLE public.payments ADD CONSTRAINT payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE RESTRICT;
ALTER TABLE public.payments ADD CONSTRAINT payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.production_orders foreign keys

ALTER TABLE public.production_orders ADD CONSTRAINT production_orders_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
ALTER TABLE public.production_orders ADD CONSTRAINT production_orders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.production_task_assignments foreign keys

ALTER TABLE public.production_task_assignments ADD CONSTRAINT production_task_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
ALTER TABLE public.production_task_assignments ADD CONSTRAINT production_task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.production_tasks(id) ON DELETE CASCADE;
ALTER TABLE public.production_task_assignments ADD CONSTRAINT production_task_assignments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.production_tasks foreign keys

ALTER TABLE public.production_tasks ADD CONSTRAINT production_tasks_production_order_id_fkey FOREIGN KEY (production_order_id) REFERENCES public.production_orders(id) ON DELETE CASCADE;
ALTER TABLE public.production_tasks ADD CONSTRAINT production_tasks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


-- public.profiles foreign keys

ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


-- public.tenant_members foreign keys

ALTER TABLE public.tenant_members ADD CONSTRAINT tenant_members_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
ALTER TABLE public.tenant_members ADD CONSTRAINT tenant_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;



-- DROP FUNCTION public.create_booking(uuid, uuid, timestamptz, uuid, uuid, uuid, timestamptz, int4, booking_status, payment_status, numeric, numeric, numeric, numeric, text);

CREATE OR REPLACE FUNCTION public.create_booking(p_tenant_id uuid, p_customer_id uuid, p_starts_at timestamp with time zone, p_package_id uuid DEFAULT NULL::uuid, p_location_id uuid DEFAULT NULL::uuid, p_room_id uuid DEFAULT NULL::uuid, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_participant_count integer DEFAULT 1, p_status booking_status DEFAULT 'pending'::booking_status, p_payment_status payment_status DEFAULT 'unpaid'::payment_status, p_subtotal numeric DEFAULT 0, p_discount_amount numeric DEFAULT 0, p_tax_amount numeric DEFAULT 0, p_total_amount numeric DEFAULT 0, p_notes text DEFAULT NULL::text)
 RETURNS bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking public.bookings;
    v_timezone text;
    v_local_timestamp timestamp;
    v_booking_number text;
    v_random text;
BEGIN

    -- =====================================================
    -- A. Tenant wajib ada dan user adalah member tenant
    -- =====================================================

    IF p_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Tenant is required';
    END IF;

    IF NOT public.is_tenant_member(p_tenant_id) THEN
        RAISE EXCEPTION 'You are not a member of this tenant';
    END IF;


    -- =====================================================
    -- B. Customer harus berasal dari tenant yang sama
    -- =====================================================

    IF NOT EXISTS (
        SELECT 1
        FROM public.customers
        WHERE id = p_customer_id
          AND tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION 'Customer does not belong to this tenant';
    END IF;


    -- =====================================================
    -- C. Package harus berasal dari tenant yang sama
    -- =====================================================

    IF p_package_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM public.packages
            WHERE id = p_package_id
              AND tenant_id = p_tenant_id
       )
    THEN
        RAISE EXCEPTION 'Package does not belong to this tenant';
    END IF;


    -- =====================================================
    -- D. Location harus berasal dari tenant yang sama
    -- =====================================================

    IF p_location_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM public.locations
            WHERE id = p_location_id
              AND tenant_id = p_tenant_id
       )
    THEN
        RAISE EXCEPTION 'Location does not belong to this tenant';
    END IF;


    -- =====================================================
    -- E. Room harus berasal dari tenant yang sama
    -- =====================================================

    IF p_room_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM public.rooms
            WHERE id = p_room_id
              AND tenant_id = p_tenant_id
       )
    THEN
        RAISE EXCEPTION 'Room does not belong to this tenant';
    END IF;


    -- =====================================================
    -- F. Participant minimal 1
    -- =====================================================

    IF p_participant_count < 1 THEN
        RAISE EXCEPTION 'Participant count must be at least 1';
    END IF;


    -- =====================================================
    -- G. End time harus setelah start time
    -- =====================================================

    IF p_ends_at IS NOT NULL
       AND p_ends_at <= p_starts_at
    THEN
        RAISE EXCEPTION 'End time must be after start time';
    END IF;


    -- =====================================================
    -- H. Ambil timezone tenant
    -- =====================================================

    SELECT COALESCE(timezone, 'Asia/Jakarta')
    INTO v_timezone
    FROM public.tenants
    WHERE id = p_tenant_id;


    -- =====================================================
    -- I. Buat timestamp lokal tenant
    -- =====================================================

    v_local_timestamp := now() AT TIME ZONE v_timezone;


    -- =====================================================
    -- J. Buat random suffix 4 karakter
    --    A-Z + 0-9
    -- =====================================================

    SELECT string_agg(
        substr(
            'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
            floor(random() * 36)::integer + 1,
            1
        ),
        ''
    )
    INTO v_random
    FROM generate_series(1, 4);


    -- =====================================================
    -- K. Buat booking number
    --
    -- BK-YYYYMMDD-HHMMSSmmm-RAND
    --
    -- Contoh:
    -- BK-20260910-110530123-A7K2
    -- =====================================================

    v_booking_number :=
        'BK-'
        || to_char(v_local_timestamp, 'YYYYMMDD')
        || '-'
        || to_char(v_local_timestamp, 'HH24MISSMS')
        || '-'
        || v_random;


    -- =====================================================
    -- L. Insert booking
    -- =====================================================

    INSERT INTO public.bookings (
        tenant_id,
        booking_number,
        customer_id,
        package_id,
        location_id,
        room_id,
        starts_at,
        ends_at,
        status,
        payment_status,
        subtotal,
        discount_amount,
        tax_amount,
        total_amount,
        notes,
        created_by,
        participant_count
    )
    VALUES (
        p_tenant_id,
        v_booking_number,
        p_customer_id,
        p_package_id,
        p_location_id,
        p_room_id,
        p_starts_at,
        p_ends_at,
        p_status,
        p_payment_status,
        p_subtotal,
        p_discount_amount,
        p_tax_amount,
        p_total_amount,
        p_notes,
        auth.uid(),
        p_participant_count
    )
    RETURNING *
    INTO v_booking;


    RETURN v_booking;

END;
$function$
;

-- Permissions

ALTER FUNCTION public.create_booking(uuid, uuid, timestamptz, uuid, uuid, uuid, timestamptz, int4, booking_status, payment_status, numeric, numeric, numeric, numeric, text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.create_booking(uuid, uuid, timestamptz, uuid, uuid, uuid, timestamptz, int4, booking_status, payment_status, numeric, numeric, numeric, numeric, text) TO postgres;
GRANT ALL ON FUNCTION public.create_booking(uuid, uuid, timestamptz, uuid, uuid, uuid, timestamptz, int4, booking_status, payment_status, numeric, numeric, numeric, numeric, text) TO authenticated;

-- DROP FUNCTION public.create_tenant(text, text);

CREATE OR REPLACE FUNCTION public.create_tenant(p_name text, p_slug text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  insert into public.tenants (name, slug, status)
  values (p_name, p_slug, 'trial')
  returning id into v_tenant_id;

  insert into public.tenant_members (tenant_id, user_id, role, is_active)
  values (v_tenant_id, (select auth.uid()), 'owner', true);

  insert into public.studio_profiles (tenant_id, display_name)
  values (v_tenant_id, p_name);

  return v_tenant_id;
end;
$function$
;

-- Permissions

ALTER FUNCTION public.create_tenant(text, text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.create_tenant(text, text) TO public;
GRANT ALL ON FUNCTION public.create_tenant(text, text) TO postgres;
GRANT ALL ON FUNCTION public.create_tenant(text, text) TO authenticated;

-- DROP FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$function$
;

-- Permissions

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
GRANT ALL ON FUNCTION public.handle_new_user() TO postgres;

-- DROP FUNCTION public.has_tenant_role(uuid, _member_role);

CREATE OR REPLACE FUNCTION public.has_tenant_role(p_tenant_id uuid, p_roles member_role[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.tenant_members tm
    where tm.tenant_id = p_tenant_id
      and tm.user_id = (select auth.uid())
      and tm.is_active = true
      and tm.role = any(p_roles)
  );
$function$
;

-- Permissions

ALTER FUNCTION public.has_tenant_role(uuid, _member_role) OWNER TO postgres;
GRANT ALL ON FUNCTION public.has_tenant_role(uuid, _member_role) TO public;
GRANT ALL ON FUNCTION public.has_tenant_role(uuid, _member_role) TO postgres;
GRANT ALL ON FUNCTION public.has_tenant_role(uuid, _member_role) TO authenticated;

-- DROP FUNCTION public.is_tenant_member(uuid);

CREATE OR REPLACE FUNCTION public.is_tenant_member(p_tenant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.tenant_members tm
    where tm.tenant_id = p_tenant_id
      and tm.user_id = (select auth.uid())
      and tm.is_active = true
  );
$function$
;

-- Permissions

ALTER FUNCTION public.is_tenant_member(uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.is_tenant_member(uuid) TO public;
GRANT ALL ON FUNCTION public.is_tenant_member(uuid) TO postgres;
GRANT ALL ON FUNCTION public.is_tenant_member(uuid) TO authenticated;

-- DROP FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

-- Permissions

ALTER FUNCTION public.set_updated_at() OWNER TO postgres;
GRANT ALL ON FUNCTION public.set_updated_at() TO postgres;


-- Permissions

GRANT ALL ON SCHEMA public TO pg_database_owner;
GRANT USAGE ON SCHEMA public TO public;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE, USAGE, SELECT ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE, USAGE, SELECT ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE, USAGE, SELECT ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE, USAGE, SELECT ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT TRIGGER, UPDATE, TRUNCATE, MAINTAIN, SELECT, INSERT, DELETE, REFERENCES ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT TRIGGER, UPDATE, TRUNCATE, MAINTAIN, SELECT, INSERT, DELETE, REFERENCES ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT TRIGGER, UPDATE, TRUNCATE, MAINTAIN, SELECT, INSERT, DELETE, REFERENCES ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT TRIGGER, UPDATE, TRUNCATE, MAINTAIN, SELECT, INSERT, DELETE, REFERENCES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT TRIGGER, UPDATE, TRUNCATE, MAINTAIN, SELECT, INSERT, DELETE, REFERENCES ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT TRIGGER, TRUNCATE, MAINTAIN, REFERENCES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT UPDATE, USAGE, SELECT ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
