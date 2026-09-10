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

export type BookingStatus = Database["public"]["Enums"]["booking_status"];

export type PaymentStatus = Database["public"]["Enums"]["payment_status"];

// ============================================================
// Booking With Relations
// ============================================================

export type BookingWithRelations = Booking & {
  customer: Customer | null;
  package: Package | null;
  room: StudioRoom | null;
  location: StudioLocation | null;
};

// ============================================================
// Booking Detail
// ============================================================

export type BookingAssigneeWithEmployee = BookingAssignee & {
  employee: Employee | null;
};

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

  const bookings = useState<BookingWithRelations[]>("bookings", () => []);

  const currentBooking = useState<BookingDetail | null>(
    "current-booking",
    () => null,
  );

  const isLoading = useState<boolean>("bookings-loading", () => false);

  const error = useState<string | null>("bookings-error", () => null);

  // ==========================================================
  // Helpers
  // ==========================================================

  function getErrorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) {
      return err.message;
    }

    if (
      typeof err === "object" &&
      err !== null &&
      "message" in err &&
      typeof err.message === "string"
    ) {
      return err.message;
    }

    return fallback;
  }

  // ==========================================================
  // 1. Load Bookings
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
        .order("starts_at", {
          ascending: true,
        });

      if (bookingError) {
        throw bookingError;
      }

      bookings.value = (data ?? []) as BookingWithRelations[];

      return bookings.value;
    } catch (err) {
      console.error("Load bookings error:", err);

      error.value = getErrorMessage(err, "Gagal memuat booking.");

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

    if (!id) {
      error.value = "ID booking tidak valid.";
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

      error.value = getErrorMessage(err, "Gagal memuat detail booking.");

      currentBooking.value = null;

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 3. Get Booking
  // ==========================================================

  async function getBooking(id: string) {
    return loadBooking(id);
  }

  // ==========================================================
  // 4. Add Booking
  // ==========================================================

  async function addBooking(
    payload: Omit<BookingInsert, "tenant_id" | "booking_number">,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      // ======================================================
      // Database menjadi sumber pembuatan booking number.
      //
      // create_booking() bertanggung jawab untuk:
      // - validasi tenant
      // - validasi customer
      // - validasi package
      // - validasi location
      // - validasi room
      // - generate booking_number
      // - insert booking
      // ======================================================

      const { data, error: createError } = await supabase.rpc(
        "create_booking",
        {
          p_tenant_id: tenantId.value,
          p_customer_id: payload.customer_id,
          p_starts_at: payload.starts_at,

          p_package_id: payload.package_id ?? undefined,
          p_location_id: payload.location_id ?? undefined,
          p_room_id: payload.room_id ?? undefined,

          p_ends_at: payload.ends_at ?? undefined,

          p_participant_count: payload.participant_count ?? 1,

          p_status: payload.status ?? "pending",

          p_payment_status: payload.payment_status ?? "unpaid",

          p_subtotal: payload.subtotal ?? 0,

          p_discount_amount: payload.discount_amount ?? 0,

          p_tax_amount: payload.tax_amount ?? 0,

          p_total_amount: payload.total_amount ?? 0,

          p_notes: payload.notes ?? undefined,
        },
      );

      if (createError) {
        throw createError;
      }

      if (!data) {
        throw new Error("Booking berhasil dibuat tetapi data tidak ditemukan.");
      }

      // ======================================================
      // RPC mengembalikan row bookings.
      //
      // Kita ambil kembali data dengan relasi agar hasil
      // addBooking() tetap memiliki struktur
      // BookingWithRelations.
      // ======================================================

      const createdBooking = data as Booking;

      const { data: bookingWithRelations, error: relationError } =
        await supabase
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
          .eq("id", createdBooking.id)
          .eq("tenant_id", tenantId.value)
          .single();

      if (relationError) {
        throw relationError;
      }

      const newBooking = bookingWithRelations as BookingWithRelations;

      bookings.value = [newBooking, ...bookings.value];

      return newBooking;
    } catch (err) {
      console.error("Add booking error:", err);

      error.value = getErrorMessage(err, "Gagal menambah booking.");

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 5. Update Booking
  // ==========================================================

  async function updateBooking(
    id: string,
    payload: Omit<BookingUpdate, "tenant_id">,
  ) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    if (!id) {
      error.value = "ID booking tidak valid.";
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

      const updatedBooking = data as BookingWithRelations;

      const index = bookings.value.findIndex((booking) => booking.id === id);

      if (index !== -1) {
        bookings.value[index] = updatedBooking;
      }

      /*
       * Jika detail booking sedang dibuka,
       * sinkronkan data utama.
       *
       * Detail relations tetap dipertahankan.
       */
      if (currentBooking.value?.id === id) {
        currentBooking.value = {
          ...currentBooking.value,
          ...updatedBooking,
        };
      }

      return updatedBooking;
    } catch (err) {
      console.error("Update booking error:", err);

      error.value = getErrorMessage(err, "Gagal mengubah booking.");

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 6. Update Booking Status
  // ==========================================================

  async function updateBookingStatus(id: string, status: BookingStatus) {
    return updateBooking(id, {
      status,
    });
  }

  // ==========================================================
  // 7. Update Payment Status
  // ==========================================================

  async function updatePaymentStatus(id: string, paymentStatus: PaymentStatus) {
    return updateBooking(id, {
      payment_status: paymentStatus,
    });
  }

  // ==========================================================
  // 8. Delete Booking
  // ==========================================================

  async function deleteBooking(id: string) {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return false;
    }

    if (!id) {
      error.value = "ID booking tidak valid.";
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

      bookings.value = bookings.value.filter((booking) => booking.id !== id);

      if (currentBooking.value?.id === id) {
        currentBooking.value = null;
      }

      return true;
    } catch (err) {
      console.error("Delete booking error:", err);

      error.value = getErrorMessage(err, "Gagal menghapus booking.");

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 9. Refresh
  // ==========================================================

  async function refreshBookings() {
    return loadBookings();
  }

  // ==========================================================
  // 10. Clear Current Booking
  // ==========================================================

  function clearCurrentBooking() {
    currentBooking.value = null;
  }

  // ==========================================================
  // 11. Clear Error
  // ==========================================================

  function clearError() {
    error.value = null;
  }

  // ==========================================================
  // 12. Clear All State
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

    // List
    loadBookings,
    refreshBookings,

    // Detail
    loadBooking,
    getBooking,

    // CRUD
    addBooking,
    updateBooking,
    deleteBooking,

    // Status
    updateBookingStatus,
    updatePaymentStatus,

    // State management
    clearCurrentBooking,
    clearError,
    clearBookings,
  };
};
