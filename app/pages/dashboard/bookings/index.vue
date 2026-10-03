<script setup lang="ts">
import type { Database } from "~/types/database.types";

definePageMeta({
  layout: "dashboard",
  title: "Booking List",
});

type BookingStatus = Database["public"]["Enums"]["booking_status"];
type PaymentStatus = Database["public"]["Enums"]["payment_status"];

const router = useRouter();
const toast = useToast();

const {
  bookings,
  isLoading,
  error,
  loadBookings,
  deleteBooking,
  cancelBooking,
} = useBookings();

useTrackLoading(isLoading);

const search = ref("");
const selectedStatus = ref<BookingStatus | "all">("all");

type BookingAction = "delete" | "cancel";

const isActionModalOpen = ref(false);

const bookingAction = ref<{
  id: string;
  number: string;
  action: BookingAction;
} | null>(null);

const isProcessingAction = ref(false);

const statusOptions: {
  label: string;
  value: BookingStatus | "all";
}[] = [
  { label: "Semua Status", value: "all" },
  { label: "Inquiry", value: "inquiry" },
  { label: "Pending", value: "pending" },
  { label: "Confirmed", value: "confirmed" },
  { label: "Checked In", value: "checked_in" },
  { label: "Shooting", value: "shooting" },
  { label: "Production", value: "production" },
  { label: "Ready", value: "ready" },
  { label: "Delivered", value: "delivered" },
  { label: "Completed", value: "completed" },
  { label: "Cancelled", value: "cancelled" },
];

const filteredBookings = computed(() => {
  const keyword = search.value.trim().toLowerCase();

  return bookings.value.filter((booking) => {
    const matchesStatus =
      selectedStatus.value === "all" || booking.status === selectedStatus.value;

    if (!keyword) {
      return matchesStatus;
    }

    const customerName = booking.customer?.full_name?.toLowerCase() ?? "";
    const bookingNumber = booking.booking_number?.toLowerCase() ?? "";
    const notes = booking.notes?.toLowerCase() ?? "";

    const matchesSearch =
      bookingNumber.includes(keyword) ||
      customerName.includes(keyword) ||
      notes.includes(keyword);

    return matchesStatus && matchesSearch;
  });
});

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(value);
}

function statusLabel(status: BookingStatus) {
  const option = statusOptions.find((item) => item.value === status);
  return option?.label ?? status;
}

function statusColor(
  status: BookingStatus,
): "neutral" | "primary" | "secondary" | "success" | "warning" | "error" {
  switch (status) {
    case "confirmed":
      return "primary";
    case "checked_in":
      return "secondary";
    case "shooting":
    case "production":
      return "warning";
    case "ready":
    case "delivered":
    case "completed":
      return "success";
    case "cancelled":
      return "error";
    case "inquiry":
    case "pending":
    default:
      return "neutral";
  }
}

function paymentLabel(status: PaymentStatus) {
  switch (status) {
    case "paid":
      return "Lunas";
    case "partial":
      return "Sebagian";
    case "refunded":
      return "Refund";
    case "unpaid":
    default:
      return "Belum Bayar";
  }
}

function paymentColor(
  status: PaymentStatus,
): "neutral" | "primary" | "secondary" | "success" | "warning" | "error" {
  switch (status) {
    case "paid":
      return "success";
    case "partial":
      return "warning";
    case "refunded":
      return "error";
    case "unpaid":
    default:
      return "neutral";
  }
}

async function refreshBookings() {
  await loadBookings();
}

// Modal konfirmasi hapus
function canDeleteBooking(status: BookingStatus) {
  // Hard delete hanya untuk booking inquiry.
  // RPC delete_booking tetap menjadi pengaman terakhir di database.
  return status === "inquiry";
}

function canCancelBooking(status: BookingStatus) {
  return status !== "cancelled" && status !== "completed";
}

function canEditBooking(status: BookingStatus) {
  return status !== "cancelled" && status !== "completed";
}

function openBookingAction(
  bookingId: string,
  bookingNumber: string,
  action: BookingAction,
) {
  bookingAction.value = {
    id: bookingId,
    number: bookingNumber,
    action,
  };

  isActionModalOpen.value = true;
}

const actionModalTitle = computed(() => {
  if (!bookingAction.value) return "Konfirmasi Aksi";

  return bookingAction.value.action === "delete"
    ? "Hapus Booking"
    : "Batalkan Booking";
});

const actionModalDescription = computed(() => {
  if (!bookingAction.value) return "";

  if (bookingAction.value.action === "delete") {
    return "Booking ini akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.";
  }

  return "Booking akan berstatus cancelled. Invoice yang belum memiliki pembayaran akan di-void, sedangkan pembayaran yang sudah tercatat tetap dipertahankan.";
});

const actionButtonLabel = computed(() => {
  return bookingAction.value?.action === "delete"
    ? "Hapus"
    : "Batalkan Booking";
});

const actionButtonColor = computed(() => {
  return bookingAction.value?.action === "delete" ? "error" : "warning";
});

async function confirmBookingAction() {
  if (!bookingAction.value) return;

  const { id, number, action } = bookingAction.value;

  isProcessingAction.value = true;

  try {
    if (action === "delete") {
      const success = await deleteBooking(id);

      if (!success) {
        throw new Error("Booking tidak dapat dihapus.");
      }

      toast.add({
        title: "Booking Dihapus",
        description: `Booking ${number} berhasil dihapus permanen.`,
        color: "success",
        icon: "i-lucide-check-circle-2",
      });
    } else {
      await cancelBooking(id);

      toast.add({
        title: "Booking Dibatalkan",
        description: `Booking ${number} berhasil dibatalkan.`,
        color: "success",
        icon: "i-lucide-circle-x",
      });
    }

    isActionModalOpen.value = false;
    bookingAction.value = null;
  } catch (err) {
    const message =
      err instanceof Error ? err.message : "Terjadi kesalahan sistem.";

    toast.add({
      title:
        action === "delete"
          ? "Gagal Menghapus Booking"
          : "Gagal Membatalkan Booking",
      description: message,
      color: "error",
      icon: "i-lucide-alert-triangle",
    });
  } finally {
    isProcessingAction.value = false;
  }
}

function closeBookingAction() {
  if (isProcessingAction.value) return;

  isActionModalOpen.value = false;
  bookingAction.value = null;
}

// Navigasi ke detail booking
function navigateToDetail(bookingId: string) {
  router.push(`/dashboard/bookings/${bookingId}`);
}

// Helper menu dropdown per baris
function getRowActions(booking: any) {
  const actions = [
    [
      {
        label: "Lihat Detail",
        icon: "i-lucide-eye",
        to: `/dashboard/bookings/${booking.id}`,
      },
      {
        label: "Edit Booking",
        icon: "i-lucide-pencil",
        disabled: !canEditBooking(booking.status),
        to: `/dashboard/bookings/${booking.id}/edit`,
      },
    ],
  ];

  if (canDeleteBooking(booking.status)) {
    actions.push([
      {
        label: "Hapus Booking",
        icon: "i-lucide-trash-2",
        color: "error" as const,
        onSelect: () =>
          openBookingAction(booking.id, booking.booking_number, "delete"),
      },
    ]);
  } else if (canCancelBooking(booking.status)) {
    actions.push([
      {
        label: "Batalkan Booking",
        icon: "i-lucide-circle-x",
        color: "warning" as const,
        onSelect: () =>
          openBookingAction(booking.id, booking.booking_number, "cancel"),
      },
    ]);
  }

  return actions;
}

onMounted(() => {
  loadBookings();
});
</script>

<template>
  <UDashboardPanel id="booking-list">
    <template #header>
      <DashboardPageHeader
        title="Booking List"
        description="Kelola Jadwal dan Booking"
      >
        <template #right>
          <UButton
            icon="i-lucide-user-plus"
            label="Booking Baru"
            size="md"
            type="button"
            color="primary"
            variant="solid"
            to="/dashboard/bookings/create"
          />
        </template>
      </DashboardPageHeader>

      <UDashboardToolbar>
        <template #left>
          <UInput
            v-model="search"
            icon="i-lucide-search"
            placeholder="Cari booking atau customer..."
            class="w-full sm:w-80"
            clearable
          />
        </template>

        <template #right>
          <USelect
            v-model="selectedStatus"
            :items="statusOptions"
            value-key="value"
            label-key="label"
            class="w-full sm:w-48"
          />
          <UButton
            icon="i-lucide-refresh-cw"
            variant="outline"
            color="neutral"
            :loading="isLoading"
            @click="refreshBookings"
          >
            Refresh
          </UButton>
        </template>
      </UDashboardToolbar>
    </template>

    <template #body>
      <div class="space-y-6">
        <!-- Error -->
        <UAlert
          v-if="error"
          color="error"
          variant="soft"
          title="Gagal memuat booking"
          :description="error"
        />

        <!-- Loading -->
        <div
          v-if="isLoading && bookings.length === 0"
          class="flex justify-center py-12"
        >
          <UIcon name="i-lucide-loader-circle" class="size-6 animate-spin" />
        </div>

        <!-- Empty -->
        <UCard v-else-if="filteredBookings.length === 0">
          <div class="py-12 text-center">
            <UIcon
              name="i-lucide-calendar-x"
              class="mx-auto size-10 text-muted-foreground"
            />

            <h3 class="mt-4 font-medium">Belum ada booking</h3>

            <p class="mt-1 text-sm text-muted-foreground">
              Belum ada booking yang sesuai dengan pencarian atau filter.
            </p>

            <UButton
              class="mt-5"
              icon="i-lucide-plus"
              label="Buat Booking"
              to="/dashboard/bookings/create"
            />
          </div>
        </UCard>

        <!-- Booking table -->
        <UCard v-else>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr
                  class="border-b border-accented text-left text-muted-foreground"
                >
                  <th class="px-4 py-3 font-medium">Booking</th>
                  <th class="px-4 py-3 font-medium">Customer</th>
                  <th class="px-4 py-3 font-medium">Jadwal</th>
                  <th class="px-4 py-3 font-medium">Paket</th>
                  <th class="px-4 py-3 font-medium">Status</th>
                  <th class="px-4 py-3 font-medium">Pembayaran</th>
                  <th class="px-4 py-3 font-medium text-right">Total</th>
                  <th class="px-4 py-3"></th>
                </tr>
              </thead>

              <tbody>
                <tr
                  v-for="booking in filteredBookings"
                  :key="booking.id"
                  class="cursor-pointer border-b border-default transition-colors last:border-0 hover:bg-elevated/50"
                  @click="navigateToDetail(booking.id)"
                >
                  <!-- Booking number -->
                  <td class="px-4 py-4 whitespace-nowrap">
                    <span
                      class="font-mono font-medium text-primary hover:underline"
                    >
                      {{ booking.booking_number }}
                    </span>

                    <!-- <div class="mt-1 text-xs text-muted-foreground">
                      {{ booking.participant_count }} orang
                    </div> -->
                  </td>

                  <!-- Customer -->
                  <td class="px-4 py-4 whitespace-nowrap">
                    <div class="font-medium">
                      {{ booking.customer?.full_name ?? "—" }}
                    </div>
                  </td>

                  <!-- Schedule -->
                  <td class="px-4 py-4 whitespace-nowrap">
                    <div class="gap-1">
                      <span class="text-muted">start:</span>
                      {{ formatDateTime(booking.starts_at) }}
                    </div>

                    <div
                      v-if="booking.ends_at"
                      class="mt-1 text-xs text-muted-foreground gap-1"
                    >
                      <span class="text-muted">end:</span>
                      {{ formatDateTime(booking.ends_at) }}
                    </div>
                  </td>

                  <!-- Package -->
                  <td class="px-4 py-4 whitespace-nowrap">
                    <div>
                      {{ booking.package?.name ?? "—" }}
                    </div>

                    <div class="mt-1 text-xs text-muted-foreground">
                      {{ booking.participant_count }} orang
                    </div>
                  </td>

                  <!-- Status proses -->
                  <td class="px-4 py-4">
                    <UBadge
                      :color="statusColor(booking.status)"
                      variant="subtle"
                    >
                      {{ statusLabel(booking.status) }}
                    </UBadge>
                  </td>

                  <!-- Payment / status keuangan -->
                  <td class="px-4 py-4">
                    <UBadge
                      :color="paymentColor(booking.payment_status)"
                      variant="subtle"
                    >
                      {{ paymentLabel(booking.payment_status) }}
                    </UBadge>
                  </td>

                  <!-- Total -->
                  <td class="px-4 py-4 text-right whitespace-nowrap">
                    {{ formatCurrency(booking.total_amount) }}
                  </td>

                  <!-- Action Column -->
                  <td class="px-4 py-4 text-right" @click.stop>
                    <UDropdownMenu :items="getRowActions(booking)">
                      <UButton
                        icon="i-lucide-ellipsis"
                        color="neutral"
                        variant="ghost"
                        size="sm"
                        aria-label="Aksi"
                      />
                    </UDropdownMenu>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Result count -->
          <div
            class="border-t border-default px-4 py-3 text-xs text-muted-foreground"
          >
            Menampilkan {{ filteredBookings.length }} booking
          </div>
        </UCard>
      </div>

      <!-- Modal Konfirmasi Aksi Booking -->
      <UModal
        v-model:open="isActionModalOpen"
        :title="actionModalTitle"
        :description="actionModalDescription"
      >
        <template #body>
          <div v-if="bookingAction" class="space-y-3">
            <p class="text-sm text-muted-foreground">
              Kode Booking:
              <span class="font-mono font-semibold text-foreground">
                {{ bookingAction.number }}
              </span>
            </p>

            <UAlert
              v-if="bookingAction.action === 'cancel'"
              color="warning"
              variant="soft"
              icon="i-lucide-info"
              title="Catatan keuangan"
              description="Pembayaran yang sudah tercatat tidak akan dihapus. Refund dilakukan melalui proses refund tersendiri."
            />
          </div>
        </template>

        <template #footer>
          <div class="flex justify-end gap-2">
            <UButton
              label="Batal"
              color="neutral"
              variant="outline"
              :disabled="isProcessingAction"
              @click="closeBookingAction"
            />

            <UButton
              :label="actionButtonLabel"
              :color="actionButtonColor"
              variant="solid"
              :loading="isProcessingAction"
              @click="confirmBookingAction"
            />
          </div>
        </template>
      </UModal>
    </template>
  </UDashboardPanel>
</template>
