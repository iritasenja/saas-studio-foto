import type { Database } from "~/types/database.types";

type Customer = Database["public"]["Tables"]["customers"]["Row"];
type CustomerInsert = Database["public"]["Tables"]["customers"]["Insert"];
type CustomerUpdate = Database["public"]["Tables"]["customers"]["Update"];

export const useCustomers = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  // State terpusat
  const customers = useState<Customer[]>("customers", () => []);
  const isLoading = useState<boolean>("customers-loading", () => false);
  const error = useState<string | null>("customers-error", () => null);

  // Fungsi internal untuk generate kode otomatis
  async function generateCustomerCode(): Promise<string> {
    if (!tenantId.value) return `CUST-${Date.now().toString().slice(-4)}`;

    // Ambil record terbanyak/terakhir untuk menghitung sequence
    const { count } = await supabase
      .from("customers")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", tenantId.value);

    const nextSeq = (count ?? 0) + 1;
    const formattedSeq = String(nextSeq).padStart(4, "0"); // Contoh: 0001, 0002

    // Format Kode: CUST-0001 (atau bisa ditambah prefix tanggal: CUST-202609-0001)
    return `CUST-${formattedSeq}`;
  }

  // 1. Load Data Pelanggan
  async function loadCustomers() {
    if (!tenantId.value) {
      customers.value = [];
      return [];
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: customerError } = await supabase
        .from("customers")
        .select("*")
        .eq("tenant_id", tenantId.value)
        .order("created_at", { ascending: false });

      if (customerError) throw customerError;

      customers.value = data ?? [];
      return customers.value;
    } catch (err) {
      console.error("Load customers error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal memuat customer.";
      customers.value = [];
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // 2. Tambah Pelanggan Baru
  async function addCustomer(payload: Omit<CustomerInsert, "tenant_id">) {
    if (!tenantId.value) return null;

    isLoading.value = true;
    error.value = null;

    try {
      // Jika code tidak dikirim atau kosong, generate otomatis
      const customerCode =
        payload.code?.trim() || (await generateCustomerCode());

      const { data, error: createError } = await supabase
        .from("customers")
        .insert({
          ...payload,
          code: customerCode,
          tenant_id: tenantId.value,
        })
        .select()
        .single();

      if (createError) throw createError;

      if (data) {
        customers.value = [data, ...customers.value];
      }

      return data;
    } catch (err) {
      console.error("Add customer error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal menambah customer.";
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // 3. Update Pelanggan
  async function updateCustomer(
    id: string,
    payload: Omit<CustomerUpdate, "tenant_id">,
  ) {
    if (!tenantId.value) return null;

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: updateError } = await supabase
        .from("customers")
        .update(payload)
        .eq("id", id)
        .eq("tenant_id", tenantId.value) // Validasi tenant
        .select()
        .single();

      if (updateError) throw updateError;

      // Update item di local state
      if (data) {
        const index = customers.value.findIndex((c) => c.id === id);
        if (index !== -1) {
          customers.value[index] = data;
        }
      }

      return data;
    } catch (err) {
      console.error("Update customer error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal mengubah customer.";
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // 4. Hapus Pelanggan
  async function deleteCustomer(id: string) {
    if (!tenantId.value) return false;

    isLoading.value = true;
    error.value = null;

    try {
      const { error: deleteError } = await supabase
        .from("customers")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value); // Validasi tenant

      if (deleteError) throw deleteError;

      // Hapus item dari local state
      customers.value = customers.value.filter((c) => c.id !== id);
      return true;
    } catch (err) {
      console.error("Delete customer error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal menghapus customer.";
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Reset state
  function clearCustomers() {
    customers.value = [];
    error.value = null;
  }

  return {
    customers,
    isLoading,
    error,
    loadCustomers,
    addCustomer,
    updateCustomer,
    deleteCustomer,
    clearCustomers,
  };
};
