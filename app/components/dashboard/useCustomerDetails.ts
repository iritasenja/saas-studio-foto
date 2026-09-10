import type { Database } from "~/types/database.types";

export type CustomerAddress =
  Database["public"]["Tables"]["customer_addresses"]["Row"];
export type CustomerAddressInsert =
  Database["public"]["Tables"]["customer_addresses"]["Insert"];

export type CustomerContact =
  Database["public"]["Tables"]["customer_contacts"]["Row"];
export type CustomerContactInsert =
  Database["public"]["Tables"]["customer_contacts"]["Insert"];

export const useCustomerDetails = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  const addresses = ref<CustomerAddress[]>([]);
  const contacts = ref<CustomerContact[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  // Load Alamat & Kontak berdasarkan customer_id
  async function loadCustomerDetails(customerId: string) {
    if (!tenantId.value) return;

    isLoading.value = true;
    error.value = null;

    try {
      const [addrRes, contactRes] = await Promise.all([
        supabase
          .from("customer_addresses")
          .select("*")
          .eq("customer_id", customerId)
          .eq("tenant_id", tenantId.value)
          .order("is_primary", { ascending: false }),
        supabase
          .from("customer_contacts")
          .select("*")
          .eq("customer_id", customerId)
          .eq("tenant_id", tenantId.value)
          .order("is_primary", { ascending: false }),
      ]);

      if (addrRes.error) throw addrRes.error;
      if (contactRes.error) throw contactRes.error;

      addresses.value = addrRes.data ?? [];
      contacts.value = contactRes.data ?? [];
    } catch (err) {
      console.error("Error loading customer details:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal memuat detail customer.";
    } finally {
      isLoading.value = false;
    }
  }

  // --- CRUD ALAMAT ---
  async function addAddress(payload: Omit<CustomerAddressInsert, "tenant_id">) {
    if (!tenantId.value) return null;
    try {
      const { data, error: err } = await supabase
        .from("customer_addresses")
        .insert({ ...payload, tenant_id: tenantId.value })
        .select()
        .single();

      if (err) throw err;
      if (data) addresses.value = [data, ...addresses.value];
      return data;
    } catch (err) {
      console.error("Add address error:", err);
      return null;
    }
  }

  async function deleteAddress(id: string) {
    if (!tenantId.value) return false;
    try {
      const { error: err } = await supabase
        .from("customer_addresses")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;
      addresses.value = addresses.value.filter((a) => a.id !== id);
      return true;
    } catch (err) {
      console.error("Delete address error:", err);
      return false;
    }
  }

  // --- CRUD KONTAK TAMBAHAN ---
  async function addContact(payload: Omit<CustomerContactInsert, "tenant_id">) {
    if (!tenantId.value) return null;
    try {
      const { data, error: err } = await supabase
        .from("customer_contacts")
        .insert({ ...payload, tenant_id: tenantId.value })
        .select()
        .single();

      if (err) throw err;
      if (data) contacts.value = [data, ...contacts.value];
      return data;
    } catch (err) {
      console.error("Add contact error:", err);
      return null;
    }
  }

  async function deleteContact(id: string) {
    if (!tenantId.value) return false;
    try {
      const { error: err } = await supabase
        .from("customer_contacts")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;
      contacts.value = contacts.value.filter((c) => c.id !== id);
      return true;
    } catch (err) {
      console.error("Delete contact error:", err);
      return false;
    }
  }

  return {
    addresses,
    contacts,
    isLoading,
    error,
    loadCustomerDetails,
    addAddress,
    deleteAddress,
    addContact,
    deleteContact,
  };
};
