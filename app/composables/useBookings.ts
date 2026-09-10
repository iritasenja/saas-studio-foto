import type { Database } from "~/types/database.types";

// ============================================================
// Base Types
// ============================================================

export type Booking = Database["public"]["Tables"]["bookings"]["Row"];
export type BookingInsert = Database["public"]["Tables"]["bookings"]["Insert"];
export type BookingUpdate = Database["public"]["Tables"]["bookings"]["Update"];

export type Customer = Database["public"]["Tables"]["customers"]["Row"];
export type Package = Database["public"]["Tables"]["packages"]["Row"];
export type StudioRoom = Database["public"]["Tables"]["studio_rooms"]["Row"];
export type StudioLocation =
  Database["public"]["Tables"]["studio_locations"]["Row"];

export type BookingItem = Database["public"]["Tables"]["booking_items"]["Row"];
export type BookingAssignee =
  Database["public"]["Tables"]["booking_assignees"]["Row"];
export type BookingStatusHistory =
  Database["public"]["Tables"]["booking_status_history"]["Row"];
export type BookingNote = Database["public"]["Tables"]["booking_notes"]["Row"];
export type Employee = Database["public"]["Tables"]["employees"]["Row"];

// ============================================================
// Booking With Relations
// ============================================================

/**
 * Data Booking untuk Booking List.
 *
 * Digunakan ketika kita membutuhkan informasi:
 * - Customer
 * - Package
 * - Room
 * - Location
 */
export type BookingWithRelations = Booking & {
  customer: Customer | null;
  package: Package | null;
  room: StudioRoom | null;
  location: StudioLocation | null;
};

/**
 * Assignee Booking beserta data employee.
 */
export type BookingAssigneeWithEmployee = BookingAssignee & {
  employee: Employee | null;
};

/**
 * Data lengkap sebuah Booking.
 *
 * Digunakan pada halaman/detail booking.
 */
export type BookingDetail = BookingWithRelations & {
  booking_items: BookingItem[];
  booking_assignees: BookingAssigneeWithEmployee[];
  booking_status_history: BookingStatusHistory[];
  booking_notes: BookingNote[];
};

// ============================================================
// Composable
// ============================================================

export const useBookings = () => {
  const supabase = useSupabaseClient<Database>();
  const { tenantId } = useTenant();

  // ==========================================================
  // State
  // ==========================================================

  /**
   * State untuk Booking List.
   */
  const bookings = useState<BookingWithRelations[]>("bookings", () => []);

  /**
   * State untuk detail Booking yang sedang dibuka.
   */
  const currentBooking = useState<BookingDetail | null>(
    "current-booking",
    () => null,
  );

  const isLoading = useState<boolean>("bookings-loading", () => false);
  const error = useState<string | null>("bookings-error", () => null);

  // ==========================================================
  // Helper RPC: Generate Booking Number
  // ==========================================================
  async function generateBookingNumber(): Promise<string | null> {
    if (!tenantId.value) return null;

    try {
      const { data, error: rpcError } = await supabase.rpc(
        "generate_booking_number",
        { p_tenant_id: tenantId.value },
      );

      if (rpcError) throw rpcError;
      return data;
    } catch (err) {
      console.error("Generate booking number error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal me-generate nomor booking.";
      return null;
    }
  }

  // ==========================================================
  // 1. Load Booking List
  // ==========================================================

  async function loadBookings() {
    if (!tenantId.value) {
      bookings.value = [];
      return [];
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: bookingError } = await supabase
        .from("bookings")
        .select(
          `
          *,
          customer:customers(*),
          package:packages(*),
          room:studio_rooms(*),
          location:studio_locations(*)
        `,
        )
        .eq("tenant_id", tenantId.value)
        .order("starts_at", { ascending: true });

      if (bookingError) {
        throw bookingError;
      }

      bookings.value = (data ?? []) as BookingWithRelations[];

      return bookings.value;
    } catch (err) {
      console.error("Load bookings error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat booking.";

      bookings.value = [];

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 2. Load Booking Detail
  // ==========================================================

  async function loadBooking(id: string) {
    if (!tenantId.value) {
      currentBooking.value = null;
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: bookingError } = await supabase
        .from("bookings")
        .select(
          `
          *,
          customer:customers(*),
          package:packages(*),
          room:studio_rooms(*),
          location:studio_locations(*),

          booking_items(*),

          booking_assignees(
            *,
            employee:employees(*)
          ),

          booking_status_history(*),

          booking_notes(*)
        `,
        )
        .eq("id", id)
        .eq("tenant_id", tenantId.value)
        .single();

      if (bookingError) {
        throw bookingError;
      }

      currentBooking.value = data as BookingDetail;

      return currentBooking.value;
    } catch (err) {
      console.error("Load booking detail error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat detail booking.";

      currentBooking.value = null;

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 3. Add Booking
  // ==========================================================
  async function addBooking(
    payload: Omit<BookingInsert, "tenant_id" | "booking_number"> & {
      booking_number?: string;
    },
  ) {
    if (!tenantId.value) return null;

    isLoading.value = true;
    error.value = null;

    try {
      // Ambil via RPC jika booking_number tidak diset manual
      const bookingNum =
        payload.booking_number?.trim() || (await generateBookingNumber());

      if (!bookingNum) {
        throw new Error("Gagal membuat nomor booking.");
      }

      const { data, error: createError } = await supabase
        .from("bookings")
        .insert({
          ...payload,
          booking_number: bookingNum,
          tenant_id: tenantId.value,
        })
        .select(
          `
          *,
          customer:customers(*),
          package:packages(*),
          room:studio_rooms(*),
          location:studio_locations(*)
        `,
        )
        .single();

      if (createError) throw createError;

      if (data) {
        bookings.value = [data as BookingWithRelations, ...bookings.value];
      }

      return data as BookingWithRelations;
    } catch (err) {
      console.error("Add booking error:", err);
      error.value =
        err instanceof Error ? err.message : "Gagal menambah booking.";
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 4. Update Booking
  // ==========================================================

  async function updateBooking(
    id: string,
    payload: Omit<BookingUpdate, "tenant_id">,
  ) {
    if (!tenantId.value) {
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: updateError } = await supabase
        .from("bookings")
        .update(payload)
        .eq("id", id)
        .eq("tenant_id", tenantId.value)
        .select(
          `
          *,
          customer:customers(*),
          package:packages(*),
          room:studio_rooms(*),
          location:studio_locations(*)
        `,
        )
        .single();

      if (updateError) {
        throw updateError;
      }

      if (data) {
        const updatedBooking = data as BookingWithRelations;

        const index = bookings.value.findIndex((booking) => booking.id === id);

        if (index !== -1) {
          bookings.value[index] = updatedBooking;
        }

        // Jika sedang membuka detail booking yang sama,
        // update juga currentBooking.
        if (currentBooking.value?.id === id) {
          currentBooking.value = {
            ...currentBooking.value,
            ...updatedBooking,
          };
        }
      }

      return data as BookingWithRelations;
    } catch (err) {
      console.error("Update booking error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal mengubah booking.";

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 5. Update Booking Status
  // ==========================================================

  async function updateBookingStatus(id: string, status: Booking["status"]) {
    return updateBooking(id, {
      status,
    });
  }

  // ==========================================================
  // 6. Delete Booking
  // ==========================================================

  async function deleteBooking(id: string) {
    if (!tenantId.value) {
      return false;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { error: deleteError } = await supabase
        .from("bookings")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId.value);

      if (deleteError) {
        throw deleteError;
      }

      // Hapus dari state list
      bookings.value = bookings.value.filter((booking) => booking.id !== id);

      // Hapus dari detail jika sedang dibuka
      if (currentBooking.value?.id === id) {
        currentBooking.value = null;
      }

      return true;
    } catch (err) {
      console.error("Delete booking error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal menghapus booking.";

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 7. Clear State
  // ==========================================================

  function clearBookings() {
    bookings.value = [];
    currentBooking.value = null;
    error.value = null;
  }

  // ==========================================================
  // Return
  // ==========================================================

  return {
    // State
    bookings,
    currentBooking,
    isLoading,
    error,

    // Booking List
    loadBookings,

    // Booking Detail
    loadBooking,

    // CRUD
    addBooking,
    updateBooking,
    deleteBooking,

    // Status
    updateBookingStatus,

    // State
    clearBookings,
  };
};
