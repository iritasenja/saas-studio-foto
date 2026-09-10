// app/composables/useTenant.ts
import type { Database } from "~/types/database.types";

type Tenant = Database["public"]["Tables"]["tenants"]["Row"];
type TenantMember = Database["public"]["Tables"]["tenant_members"]["Row"];

export type TenantMembership = TenantMember & {
  tenants: Tenant | null;
};

export const useTenant = () => {
  const supabase = useSupabaseClient<Database>();

  // Shared state
  const tenant = useState<Tenant | null>("current-tenant", () => null);
  const membership = useState<TenantMember | null>(
    "current-membership",
    () => null,
  );
  const tenants = useState<TenantMembership[]>("tenant-memberships", () => []);
  const isLoading = useState<boolean>("tenant-loading", () => false);
  const error = useState<string | null>("tenant-error", () => null);

  // Menyimpan tenant aktif di browser
  const activeTenantId = useCookie<string | null>("active-tenant-id", {
    default: () => null,
    sameSite: "lax",
  });

  const tenantId = computed(() => tenant.value?.id ?? null);
  const role = computed(() => membership.value?.role ?? null);
  const hasTenants = computed(() => tenants.value.length > 0);

  function setTenant(item: TenantMembership) {
    if (!item.tenants) return;

    tenant.value = item.tenants;

    membership.value = {
      id: item.id,
      tenant_id: item.tenant_id,
      user_id: item.user_id,
      role: item.role,
      is_active: item.is_active,
      joined_at: item.joined_at,
    };

    // Simpan tenant aktif
    activeTenantId.value = item.tenant_id;
  }

  async function loadTenants() {
    isLoading.value = true;
    error.value = null;

    try {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError) {
        throw userError;
      }

      if (!user) {
        clearTenant();
        return false;
      }

      const { data, error: membershipError } = await supabase
        .from("tenant_members")
        .select(
          `
          id,
          tenant_id,
          user_id,
          role,
          is_active,
          joined_at,
          tenants (
            id,
            name,
            slug,
            status,
            email,
            phone,
            timezone,
            currency_code,
            created_at,
            updated_at
          )
        `,
        )
        .eq("user_id", user.id)
        .eq("is_active", true)
        .order("joined_at", { ascending: true });

      if (membershipError) {
        throw membershipError;
      }

      tenants.value = (data ?? []) as TenantMembership[];

      if (tenants.value.length === 0) {
        clearTenant();
        return false;
      }

      // =====================================================
      // PILIH TENANT AKTIF
      // =====================================================

      // 1. Coba menggunakan tenant yang tersimpan di cookie
      const savedTenant = tenants.value.find(
        (item) => item.tenant_id === activeTenantId.value,
      );

      if (savedTenant) {
        setTenant(savedTenant);
      } else {
        // 2. Jika cookie tidak ada / tenant sudah tidak tersedia,
        //    gunakan tenant pertama
        setTenant(tenants.value[0]);
      }

      return true;
    } catch (err) {
      console.error("Load tenants error:", err);

      error.value = err instanceof Error ? err.message : "Gagal memuat studio.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  function clearTenant() {
    tenant.value = null;
    membership.value = null;
    tenants.value = [];
    activeTenantId.value = null;
    error.value = null;
  }

  return {
    tenant,
    tenantId,
    membership,
    tenants,
    role,
    hasTenants,
    isLoading,
    error,
    activeTenantId,
    loadTenants,
    setTenant,
    clearTenant,
  };
};
