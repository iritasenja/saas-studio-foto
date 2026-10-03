// app/composables/useBookings.ts
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
// Invoice / Payment Types
// ============================================================

export type Invoice = Database["public"]["Tables"]["invoices"]["Row"];

export type InvoiceItem = Database["public"]["Tables"]["invoice_items"]["Row"];

export type Payment = Database["public"]["Tables"]["payments"]["Row"];

// ============================================================
// Booking With Relations
// ============================================================

export type BookingWithRelations = Booking & {
  customer: Customer | null;
  package: Package | null;
  room: StudioRoom | null;
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
  invoices?: Invoice[] | null;
};

// ============================================================
// Create Booking Input
// ============================================================
//
// Input ini sengaja TIDAK menggunakan BookingInsert secara langsung.
//
// Alasannya:
// - tenant_id ditentukan oleh tenant aktif
// - booking_number dibuat database
// - payment_status ditentukan oleh transaction RPC
//
// Jadi frontend tidak boleh menentukan tiga nilai tersebut.
// ============================================================

export type CreateBookingInput = {
  customer_id: string;

  starts_at: string;

  package_id?: string | null;

  room_id?: string | null;

  ends_at?: string | null;

  participant_count?: number;

  subtotal?: number;

  discount_amount?: number;

  tax_amount?: number;

  total_amount?: number;

  notes?: string | null;

  // ----------------------------------------------------------
  // Invoice
  // ----------------------------------------------------------

  create_invoice?: boolean;

  invoice_due_at?: string | null;

  invoice_notes?: string | null;

  invoice_items?: CreateBookingInvoiceItem[];
};

export type CreateBookingInvoiceItem = {
  description: string;
  quantity: number;
  unit_price: number;
};

// ============================================================
// Transaction Result
// ============================================================

export type CreateBookingTransactionResult = {
  booking: Booking;
  invoice: Invoice | null;
  payment: Payment | null;
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
              room:studio_rooms(*)
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
              booking_items(*),
              booking_assignees(
                *,
                employee:employees(*)
              ),
              booking_status_history(*),
              booking_notes(*),
              invoices(*)
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
  //
  // Booking dibuat melalui:
  //
  // create_booking_transaction()
  //
  // Database menangani:
  // - booking
  // - invoice optional
  // - initial payment optional
  // - payment_status
  // - booking_number
  //
  // Satu RPC = satu transaksi database.
  // ==========================================================

  async function addBooking(
    payload: CreateBookingInput,
  ): Promise<BookingWithRelations | null> {
    if (!tenantId.value) {
      error.value = "Tenant aktif tidak ditemukan.";
      return null;
    }

    if (!payload.customer_id) {
      error.value = "Customer wajib dipilih.";
      return null;
    }

    if (!payload.starts_at) {
      error.value = "Waktu mulai booking wajib diisi.";
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      // ------------------------------------------------------
      // Normalisasi invoice
      // ------------------------------------------------------

      const createInvoice = payload.create_invoice ?? false;

      const invoiceItems = payload.invoice_items ?? [];

      // ------------------------------------------------------
      // Validasi frontend ringan
      // ------------------------------------------------------

      if (createInvoice && invoiceItems.length === 0) {
        throw new Error("Invoice membutuhkan minimal satu item.");
      }

      // ------------------------------------------------------
      // Create booking transaction
      // ------------------------------------------------------
      //
      // Database menentukan:
      // - booking_number
      // - booking status = pending
      // - payment_status = unpaid
      //
      // Pembayaran TIDAK dibuat di sini.
      // Pembayaran dilakukan melalui usePayments.addPayment()
      // setelah booking berhasil dibuat.
      // ------------------------------------------------------

      const { data, error: createError } = await supabase.rpc(
        "create_booking_transaction",
        {
          p_tenant_id: tenantId.value,

          p_customer_id: payload.customer_id,

          p_starts_at: payload.starts_at,

          p_package_id: payload.package_id ?? null,

          p_room_id: payload.room_id ?? null,

          p_ends_at: payload.ends_at ?? null,

          p_participant_count: payload.participant_count ?? 1,

          p_subtotal: payload.subtotal ?? 0,

          p_discount_amount: payload.discount_amount ?? 0,

          p_tax_amount: payload.tax_amount ?? 0,

          p_total_amount: payload.total_amount ?? 0,

          p_notes: payload.notes ?? null,

          // Invoice
          p_create_invoice: createInvoice,

          p_invoice_due_at: payload.invoice_due_at ?? null,

          p_invoice_notes: payload.invoice_notes ?? null,

          p_invoice_items: invoiceItems,
        },
      );

      if (createError) {
        throw createError;
      }

      if (!data) {
        throw new Error(
          "Booking berhasil dibuat tetapi data transaksi tidak ditemukan.",
        );
      }

      // ------------------------------------------------------
      // RPC result
      // ------------------------------------------------------

      const transaction = data as unknown as CreateBookingTransactionResult;

      if (!transaction.booking?.id) {
        throw new Error(
          "Booking berhasil dibuat tetapi data booking tidak valid.",
        );
      }

      // ------------------------------------------------------
      // Ambil kembali booking dengan relasi
      // ------------------------------------------------------

      const { data: bookingWithRelations, error: relationError } =
        await supabase
          .from("bookings")
          .select(
            `
            *,
            customer:customers(*),
            package:packages(*),
            room:studio_rooms(*)
          `,
          )
          .eq("id", transaction.booking.id)
          .eq("tenant_id", tenantId.value)
          .single();

      if (relationError) {
        throw relationError;
      }

      const newBooking = bookingWithRelations as BookingWithRelations;

      // ------------------------------------------------------
      // Update local state
      // ------------------------------------------------------

      bookings.value = [newBooking, ...bookings.value];

      return newBooking;
    } catch (err) {
      console.error("Add booking transaction error:", err);

      error.value = getErrorMessage(err, "Gagal membuat booking.");

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
            room:studio_rooms(*)
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
  //
  // Dipertahankan untuk kompatibilitas dengan kode lama.
  //
  // Untuk alur pembayaran baru, jangan gunakan fungsi ini
  // dari UI. payment_status seharusnya mengikuti invoice/payment.
  // ==========================================================

  async function updatePaymentStatus(id: string, paymentStatus: PaymentStatus) {
    return updateBooking(id, {
      payment_status: paymentStatus,
    });
  }

  // ==========================================================

  async function cancelBooking(id: string) {
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
      const { data, error: cancelError } = await supabase.rpc(
        "cancel_booking",
        {
          p_tenant_id: tenantId.value,
          p_booking_id: id,
        },
      );

      if (cancelError) {
        throw cancelError;
      }

      if (!data) {
        throw new Error("Gagal membatalkan booking.");
      }

      const cancelledBooking = data as Booking;

      const index = bookings.value.findIndex((booking) => booking.id === id);

      if (index !== -1) {
        bookings.value[index] = {
          ...bookings.value[index],
          ...cancelledBooking,
        };
      }

      if (currentBooking.value?.id === id) {
        currentBooking.value = {
          ...currentBooking.value,
          ...cancelledBooking,
        };
      }

      return cancelledBooking;
    } catch (err) {
      console.error("Cancel booking error:", err);

      error.value = getErrorMessage(err, "Booking tidak dapat dibatalkan.");

      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // 8. Delete Booking
  // ==========================================================
  //
  // IMPORTANT:
  //
  // Jangan lagi melakukan:
  //
  //   .from("bookings").delete()
  //
  // karena Migration 05 sudah mencabut DELETE policy langsung.
  //
  // Semua hard delete harus melalui:
  //
  //   delete_booking()
  //
  // Database kemudian menentukan apakah booking memang boleh
  // dihapus.
  //
  // Aturan database:
  //
  // - hanya booking yang masih boleh dihapus yang akan berhasil
  // - booking yang sudah memiliki invoice akan ditolak
  // - booking yang sudah masuk proses akan ditolak
  // - booking detail/history yang CASCADE akan ikut terhapus
  // ==========================================================

  async function deleteBooking(id: string): Promise<boolean> {
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
      const { data, error: deleteError } = await supabase.rpc(
        "delete_booking",
        {
          p_tenant_id: tenantId.value,

          p_booking_id: id,
        },
      );

      if (deleteError) {
        throw deleteError;
      }

      // RPC mengembalikan boolean.
      if (data !== true) {
        throw new Error("Booking tidak berhasil dihapus.");
      }

      // ------------------------------------------------------
      // Update local state
      // ------------------------------------------------------

      bookings.value = bookings.value.filter((booking) => booking.id !== id);

      if (currentBooking.value?.id === id) {
        currentBooking.value = null;
      }

      return true;
    } catch (err) {
      console.error("Delete booking error:", err);

      error.value = getErrorMessage(err, "Booking tidak dapat dihapus.");

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
  // Watcher
  // ==========================================================

  watch(
    tenantId,
    async (newTenantId, oldTenantId) => {
      if (newTenantId && newTenantId !== oldTenantId) {
        bookings.value = [];
        currentBooking.value = null;

        await loadBookings();
      } else if (!newTenantId) {
        clearBookings();
      }
    },
    {
      immediate: false,
    },
  );

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

    cancelBooking,

    // Status
    updateBookingStatus,
    updatePaymentStatus,

    // State management
    clearCurrentBooking,
    clearError,
    clearBookings,
  };
};
