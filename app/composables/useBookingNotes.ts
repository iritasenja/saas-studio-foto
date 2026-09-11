import type { Database } from "~/types/database.types";

export type BookingNote = Database["public"]["Tables"]["booking_notes"]["Row"];

export type BookingNoteInsert =
  Database["public"]["Tables"]["booking_notes"]["Insert"];

export type BookingNoteUpdate =
  Database["public"]["Tables"]["booking_notes"]["Update"];

export const useBookingNotes = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  const notes = ref<BookingNote[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  /**
   * Memuat seluruh catatan untuk satu booking.
   */
  async function loadBookingNotes(bookingId: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_notes")
        .select("*")
        .eq("booking_id", bookingId)
        .eq("tenant_id", tenantId.value)
        .order("created_at", { ascending: false });

      if (err) throw err;

      notes.value = data ?? [];
    } catch (err) {
      console.error("Load booking notes error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat catatan booking.";
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Menambahkan catatan baru ke booking.
   */
  async function addBookingNote(bookingId: string, body: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    const trimmedBody = body.trim();

    if (!trimmedBody) {
      error.value = "Catatan tidak boleh kosong.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_notes")
        .insert({
          tenant_id: tenantId.value,
          booking_id: bookingId,
          body: trimmedBody,
        })
        .select()
        .single();

      if (err) throw err;

      if (data) {
        notes.value = [data, ...notes.value];
      }

      return data;
    } catch (err) {
      console.error("Add booking note error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal menambahkan catatan booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Memperbarui isi catatan.
   */
  async function updateBookingNote(id: string, body: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    const trimmedBody = body.trim();

    if (!trimmedBody) {
      error.value = "Catatan tidak boleh kosong.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_notes")
        .update({
          body: trimmedBody,
        })
        .eq("id", id)
        .eq("tenant_id", tenantId.value)
        .select()
        .single();

      if (err) throw err;

      if (data) {
        notes.value = notes.value.map((note) => (note.id === id ? data : note));
      }

      return data;
    } catch (err) {
      console.error("Update booking note error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal memperbarui catatan booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Menghapus catatan.
   */
  async function deleteBookingNote(id: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return false;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { error: err } = await supabase
        .from("booking_notes")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;

      notes.value = notes.value.filter((note) => note.id !== id);

      return true;
    } catch (err) {
      console.error("Delete booking note error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal menghapus catatan booking.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  function clearBookingNotes() {
    notes.value = [];
    error.value = null;
  }

  return {
    notes,
    isLoading,
    error,
    loadBookingNotes,
    addBookingNote,
    updateBookingNote,
    deleteBookingNote,
    clearBookingNotes,
  };
};
