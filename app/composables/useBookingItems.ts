// app/composables/useBookingItems.ts
import type { Database } from "~/types/database.types";

export type BookingItem = Database["public"]["Tables"]["booking_items"]["Row"];

export type BookingItemInsert =
  Database["public"]["Tables"]["booking_items"]["Insert"];

export type BookingItemUpdate =
  Database["public"]["Tables"]["booking_items"]["Update"];

export const useBookingItems = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  const items = ref<BookingItem[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  // ============================================================
  // LOAD
  // ============================================================

  async function loadBookingItems(bookingId: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_items")
        .select("*")
        .eq("booking_id", bookingId)
        .eq("tenant_id", tenantId.value)
        .order("id", { ascending: true });

      if (err) throw err;

      items.value = data ?? [];
    } catch (err) {
      console.error("Load booking items error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat item booking.";
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  async function addBookingItem(
    bookingId: string,
    payload: Omit<BookingItemInsert, "id" | "tenant_id" | "booking_id">,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_items")
        .insert({
          ...payload,
          tenant_id: tenantId.value,
          booking_id: bookingId,
        })
        .select()
        .single();

      if (err) throw err;

      if (data) {
        items.value = [...items.value, data];
      }

      return data;
    } catch (err) {
      console.error("Add booking item error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal menambahkan item booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  async function updateBookingItem(
    id: string,
    payload: Omit<BookingItemUpdate, "id" | "tenant_id" | "booking_id">,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_items")
        .update(payload)
        .eq("id", id)
        .eq("tenant_id", tenantId.value)
        .select()
        .single();

      if (err) throw err;

      if (data) {
        items.value = items.value.map((item) => (item.id === id ? data : item));
      }

      return data;
    } catch (err) {
      console.error("Update booking item error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memperbarui item booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  async function deleteBookingItem(id: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return false;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { error: err } = await supabase
        .from("booking_items")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;

      items.value = items.value.filter((item) => item.id !== id);

      return true;
    } catch (err) {
      console.error("Delete booking item error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal menghapus item booking.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // CLEAR
  // ============================================================

  function clearBookingItems() {
    items.value = [];
    error.value = null;
  }

  return {
    items,
    isLoading,
    error,

    loadBookingItems,
    addBookingItem,
    updateBookingItem,
    deleteBookingItem,
    clearBookingItems,
  };
};
