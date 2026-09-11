import type { Database } from "~/types/database.types";

export type BookingAssignee =
  Database["public"]["Tables"]["booking_assignees"]["Row"];

export type BookingAssigneeInsert =
  Database["public"]["Tables"]["booking_assignees"]["Insert"];

export type BookingAssigneeUpdate =
  Database["public"]["Tables"]["booking_assignees"]["Update"];

export const useBookingAssignees = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  const assignees = ref<BookingAssignee[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  // ============================================================
  // LOAD
  // ============================================================

  async function loadBookingAssignees(bookingId: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_assignees")
        .select("*")
        .eq("booking_id", bookingId)
        .eq("tenant_id", tenantId.value)
        .order("created_at", { ascending: true });

      if (err) throw err;

      assignees.value = data ?? [];
    } catch (err) {
      console.error("Load booking assignees error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat petugas booking.";
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  async function addBookingAssignee(
    bookingId: string,
    employeeId: string,
    assignmentRole = "photographer",
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_assignees")
        .insert({
          tenant_id: tenantId.value,
          booking_id: bookingId,
          employee_id: employeeId,
          assignment_role: assignmentRole,
        })
        .select()
        .single();

      if (err) throw err;

      if (data) {
        assignees.value = [...assignees.value, data];
      }

      return data;
    } catch (err) {
      console.error("Add booking assignee error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal menambahkan petugas booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  async function updateBookingAssignee(
    id: string,
    payload: Omit<BookingAssigneeUpdate, "id" | "tenant_id" | "booking_id">,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase
        .from("booking_assignees")
        .update(payload)
        .eq("id", id)
        .eq("tenant_id", tenantId.value)
        .select()
        .single();

      if (err) throw err;

      if (data) {
        assignees.value = assignees.value.map((assignee) =>
          assignee.id === id ? data : assignee,
        );
      }

      return data;
    } catch (err) {
      console.error("Update booking assignee error:", err);

      error.value =
        err instanceof Error
          ? err.message
          : "Gagal memperbarui petugas booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  async function deleteBookingAssignee(id: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return false;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { error: err } = await supabase
        .from("booking_assignees")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (err) throw err;

      assignees.value = assignees.value.filter(
        (assignee) => assignee.id !== id,
      );

      return true;
    } catch (err) {
      console.error("Delete booking assignee error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal menghapus petugas booking.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // CLEAR
  // ============================================================

  function clearBookingAssignees() {
    assignees.value = [];
    error.value = null;
  }

  return {
    assignees,
    isLoading,
    error,

    loadBookingAssignees,
    addBookingAssignee,
    updateBookingAssignee,
    deleteBookingAssignee,
    clearBookingAssignees,
  };
};
