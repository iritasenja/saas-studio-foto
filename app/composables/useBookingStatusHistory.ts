import type { Database } from "~/types/database.types";

export type BookingStatusHistory =
  Database["public"]["Tables"]["booking_status_history"]["Row"];

export type BookingStatusHistoryInsert =
  Database["public"]["Tables"]["booking_status_history"]["Insert"];

export type BookingStatusHistoryUpdate =
  Database["public"]["Tables"]["booking_status_history"]["Update"];

export type BookingStatus = Database["public"]["Enums"]["booking_status"];

export const useBookingStatusHistory = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  const history = ref<BookingStatusHistory[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  /**
   * Memuat seluruh riwayat status untuk satu booking.
   */
  async function loadBookingStatusHistory(bookingId: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_status_history")
        .select("*")
        .eq("booking_id", bookingId)
        .eq("tenant_id", tenantId.value)
        .order("created_at", { ascending: false });

      if (err) throw err;

      history.value = data ?? [];
    } catch (err) {
      console.error("Load booking status history error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal memuat riwayat status booking.";
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Menambahkan satu riwayat perubahan status.
   *
   * Biasanya fungsi ini dipanggil setelah status booking berhasil berubah.
   */
  async function addBookingStatusHistory(
    bookingId: string,
    toStatus: BookingStatus,
    fromStatus: BookingStatus | null = null,
    note: string | null = null,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_status_history")
        .insert({
          tenant_id: tenantId.value,
          booking_id: bookingId,
          from_status: fromStatus,
          to_status: toStatus,
          note,
        })
        .select()
        .single();

      if (err) throw err;

      if (data) {
        history.value = [data, ...history.value];
      }

      return data;
    } catch (err) {
      console.error("Add booking status history error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal menyimpan riwayat status booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Menghapus satu history.
   *
   * Biasanya tidak perlu dipakai dari UI operasional,
   * tetapi tetap disediakan untuk kebutuhan administrasi.
   */
  async function deleteBookingStatusHistory(id: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return false;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { error: err } = await supabase
        .from("booking_status_history")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;

      history.value = history.value.filter((item) => item.id !== id);

      return true;
    } catch (err) {
      console.error("Delete booking status history error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal menghapus riwayat status booking.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  function clearBookingStatusHistory() {
    history.value = [];
    error.value = null;
  }

  return {
    history,
    isLoading,
    error,
    loadBookingStatusHistory,
    addBookingStatusHistory,
    deleteBookingStatusHistory,
    clearBookingStatusHistory,
  };
};
