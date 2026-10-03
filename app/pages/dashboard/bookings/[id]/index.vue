<script setup lang="ts">
import type { Database } from "~/types/database.types";
import type { BookingDetail } from "~/composables/useBookings";

definePageMeta({
  layout: "dashboard",
  title: "Booking Detail",
});

type BookingStatus = Database["public"]["Enums"]["booking_status"];
type PaymentStatus = Database["public"]["Enums"]["payment_status"];

const route = useRoute();
const router = useRouter();

const {
  currentBooking,
  isLoading,
  error,
  loadBooking,
  updateBookingStatus,
  cancelBooking,
  deleteBooking,
} = useBookings();

const {
  payments,
  loadPayments,
  refundPayment,
  isSaving: isRefundSaving,
  error: paymentError,
} = usePayments();

const bookingId = computed(() => String(route.params.id ?? ""));

const isUpdating = ref(false);
const actionError = ref<string | null>(null);

const isProcessingAction = ref(false);
const actionModal = ref<"delete" | "cancel" | null>(null);

// ======================================================
// REFUND
// ======================================================

const refundModalOpen = ref(false);
const refundPaymentId = ref<string | null>(null);
const refundReference = ref("");
const refundNotes = ref("");
const refundError = ref<string | null>(null);

// ======================================================
// BOOKING STATUS
// ======================================================

const statusOptions: {
  label: string;
  value: BookingStatus;
}[] = [
  { label: "Inquiry", value: "inquiry" },
  { label: "Pending", value: "pending" },
  { label: "Confirmed", value: "confirmed" },
  { label: "Checked In", value: "checked_in" },
  { label: "Shooting", value: "shooting" },
  { label: "Production", value: "production" },
  { label: "Ready", value: "ready" },
  { label: "Delivered", value: "delivered" },
  { label: "Completed", value: "completed" },
];

const allowedNextStatuses: Record<BookingStatus, BookingStatus[]> = {
  inquiry: ["pending"],
  pending: ["confirmed"],
  confirmed: ["checked_in", "shooting"],
  checked_in: ["shooting"],
  shooting: ["production"],
  production: ["ready"],
  ready: ["delivered"],
  delivered: ["completed"],
  completed: [],
  cancelled: [],
};

const availableStatusOptions = computed(() => {
  if (!booking.value) {
    return [];
  }

  const current = booking.value.status;

  return statusOptions.filter((option) => {
    return (
      option.value === current ||
      allowedNextStatuses[current]?.includes(option.value)
    );
  });
});

// ======================================================
// PAYMENT STATUS
// ======================================================

const paymentOptions: {
  label: string;
  value: PaymentStatus;
}[] = [
  { label: "Belum Bayar", value: "unpaid" },
  { label: "Sebagian", value: "partial" },
  { label: "Lunas", value: "paid" },
  { label: "Refund", value: "refunded" },
];

const booking = computed<BookingDetail | null>(() => currentBooking.value);

const sortedHistory = computed(() =>
  [...(booking.value?.booking_status_history ?? [])].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  ),
);

// ======================================================
// BOOKING ACTION PERMISSIONS
// ======================================================

const canDeleteBooking = computed(() => {
  return booking.value?.status === "inquiry";
});

const canCancelBooking = computed(() => {
  if (!booking.value) return false;

  return !["completed", "cancelled"].includes(booking.value.status);
});

const canEditBooking = computed(() => {
  if (!booking.value) return false;

  return !["completed", "cancelled"].includes(booking.value.status);
});

// ======================================================
// FORMATTERS
// ======================================================

function formatDateTime(value: string | null) {
  if (!value) return "-";

  return new Intl.DateTimeFormat("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatCurrency(value: number | null | undefined) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(value ?? 0);
}

// ======================================================
// STATUS HELPERS
// ======================================================

function statusLabel(status: BookingStatus) {
  return (
    statusOptions.find((option) => option.value === status)?.label ?? status
  );
}

function statusColor(
  status: BookingStatus,
): "neutral" | "primary" | "secondary" | "success" | "warning" | "error" {
  if (status === "cancelled") return "error";

  if (["ready", "delivered", "completed"].includes(status)) {
    return "success";
  }

  if (["shooting", "production"].includes(status)) {
    return "warning";
  }

  if (status === "confirmed") return "primary";
  if (status === "checked_in") return "secondary";

  return "neutral";
}

function paymentColor(
  status: PaymentStatus,
): "neutral" | "primary" | "secondary" | "success" | "warning" | "error" {
  if (status === "paid") return "success";
  if (status === "partial") return "warning";
  if (status === "refunded") return "error";

  return "neutral";
}

function paymentStatusLabel(status: PaymentStatus) {
  return (
    paymentOptions.find((option) => option.value === status)?.label ?? status
  );
}

// ======================================================
// REFUND ACTION
// ======================================================

function openRefundModal(paymentId: string) {
  refundPaymentId.value = paymentId;
  refundReference.value = "";
  refundNotes.value = "";
  refundError.value = null;
  refundModalOpen.value = true;
}

function closeRefundModal() {
  if (isRefundSaving.value) return;

  refundModalOpen.value = false;
  refundPaymentId.value = null;
  refundReference.value = "";
  refundNotes.value = "";
  refundError.value = null;
}

async function confirmRefund() {
  if (!refundPaymentId.value) {
    return;
  }

  refundError.value = null;

  const result = await refundPayment(refundPaymentId.value, {
    refund_reference: refundReference.value,
    refund_notes: refundNotes.value,
  });

  if (!result) {
    refundError.value = paymentError.value ?? "Gagal memproses refund.";

    return;
  }

  const currentInvoiceId = invoiceId.value;

  closeRefundModal();

  if (currentInvoiceId) {
    await loadPayments(currentInvoiceId);
  }

  await loadBooking(bookingId.value);
}

// ======================================================
// BOOKING ACTION MODAL
// ======================================================

function openDeleteModal() {
  actionModal.value = "delete";
}

function openCancelModal() {
  actionModal.value = "cancel";
}

function closeActionModal() {
  if (isProcessingAction.value) return;

  actionModal.value = null;
}

async function confirmAction() {
  if (!booking.value || !actionModal.value) {
    return;
  }

  isProcessingAction.value = true;
  actionError.value = null;

  try {
    if (actionModal.value === "delete") {
      const success = await deleteBooking(booking.value.id);

      if (!success) {
        throw new Error("Booking tidak dapat dihapus.");
      }

      await router.push("/dashboard/bookings");

      return;
    }

    await cancelBooking(booking.value.id);

    actionModal.value = null;

    await loadBooking(booking.value.id);

    if (invoiceId.value) {
      await loadPayments(invoiceId.value);
    }
  } catch (err) {
    console.error("Booking action error:", err);

    actionError.value =
      err instanceof Error ? err.message : "Gagal memproses booking.";
  } finally {
    isProcessingAction.value = false;
  }
}

// ======================================================
// BOOKING STATUS
// ======================================================

async function changeStatus(status: BookingStatus) {
  if (!booking.value || status === booking.value.status) {
    return;
  }

  const currentStatus = booking.value.status;

  const allowed = allowedNextStatuses[currentStatus]?.includes(status) ?? false;

  if (!allowed) {
    actionError.value = `Status ${statusLabel(status)} tidak dapat dipilih dari status ${statusLabel(currentStatus)}.`;

    return;
  }

  actionError.value = null;
  isUpdating.value = true;

  try {
    const result = await updateBookingStatus(booking.value.id, status);

    if (!result) {
      actionError.value = error.value ?? "Gagal mengubah status booking.";
    }
  } catch (err) {
    actionError.value =
      err instanceof Error ? err.message : "Gagal mengubah status booking.";
  } finally {
    isUpdating.value = false;
  }
}

// ======================================================
// INVOICE
// ======================================================

const invoiceId = computed(() => {
  const current = booking.value;

  if (!current) {
    return null;
  }

  if (current.invoices?.length) {
    return current.invoices[0]?.id;
  }

  return null;
});

// ======================================================
// LOAD
// ======================================================

onMounted(async () => {
  await loadBooking(bookingId.value);

  if (invoiceId.value) {
    await loadPayments(invoiceId.value);
  }
});

watch(bookingId, async (id) => {
  if (!id) return;

  await loadBooking(id);

  if (invoiceId.value) {
    await loadPayments(invoiceId.value);
  }
});
</script>

<template>
  <UDashboardPanel id="booking-detail">
    <template #header>
      <DashboardPageHeader
        :title="booking?.booking_number ?? 'Detail Booking'"
        description="Informasi sesi, customer, pembayaran, dan proses produksi"
      />

      <UDashboardToolbar>
        <template #right>
          <UButton
            v-if="booking && canEditBooking"
            icon="i-lucide-pencil"
            label="Edit Booking"
            color="primary"
            variant="soft"
            :to="`/dashboard/bookings/${booking.id}/edit`"
          />

          <UButton
            v-if="booking && canCancelBooking"
            icon="i-lucide-circle-x"
            label="Batalkan"
            color="warning"
            variant="soft"
            :loading="isProcessingAction"
            @click="openCancelModal"
          />

          <UButton
            v-if="booking && canDeleteBooking"
            icon="i-lucide-trash-2"
            label="Hapus"
            color="error"
            variant="soft"
            :loading="isProcessingAction"
            @click="openDeleteModal"
          />

          <UButton
            icon="i-lucide-refresh-cw"
            color="neutral"
            variant="outline"
            :loading="isLoading"
            @click="loadBooking(bookingId)"
          >
            Refresh
          </UButton>
        </template>
      </UDashboardToolbar>
    </template>

    <template #body>
      <div class="space-y-6">
        <div v-if="isLoading && !booking" class="flex justify-center py-16">
          <UIcon name="i-lucide-loader-circle" class="size-7 animate-spin" />
        </div>

        <UAlert
          v-else-if="error && !booking"
          color="error"
          variant="soft"
          icon="i-lucide-circle-alert"
          title="Gagal memuat detail booking"
          :description="error"
        />

        <template v-else-if="booking">
          <UAlert
            v-if="actionError"
            color="error"
            variant="soft"
            icon="i-lucide-circle-alert"
            :title="actionError"
          />

          <div
            class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
          >
            <div>
              <p class="font-mono text-sm text-muted-foreground">
                {{ booking.booking_number }}
              </p>

              <h1 class="mt-1 text-2xl font-semibold">
                {{ booking.customer?.full_name ?? "Customer tidak ditemukan" }}
              </h1>

              <p class="mt-1 text-sm text-muted-foreground">
                Dibuat
                {{ formatDateTime(booking.created_at) }}
              </p>
            </div>

            <div class="flex flex-wrap gap-2">
              <UBadge :color="statusColor(booking.status)" variant="subtle">
                {{ statusLabel(booking.status) }}
              </UBadge>

              <UBadge
                :color="paymentColor(booking.payment_status)"
                variant="subtle"
              >
                {{
                  paymentOptions.find(
                    (item) => item.value === booking?.payment_status,
                  )?.label
                }}
              </UBadge>
            </div>
          </div>

          <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
            <div class="space-y-6">
              <!-- STATUS -->
              <UCard>
                <template #header>
                  <h2 class="font-semibold">Status Operasional</h2>
                </template>

                <div class="grid gap-4 sm:grid-cols-2">
                  <UFormField label="Status booking">
                    <USelect
                      :model-value="booking.status"
                      :items="availableStatusOptions"
                      value-key="value"
                      label-key="label"
                      :disabled="
                        isUpdating ||
                        booking.status === 'completed' ||
                        booking.status === 'cancelled'
                      "
                      class="w-full"
                      @update:model-value="changeStatus"
                    />
                  </UFormField>

                  <UFormField label="Status pembayaran">
                    <div
                      class="flex min-h-9 items-center rounded-md border border-default bg-elevated/30 px-3"
                    >
                      <UBadge
                        :color="paymentColor(booking.payment_status)"
                        variant="subtle"
                      >
                        {{
                          paymentOptions.find(
                            (item) => item.value === booking.payment_status,
                          )?.label
                        }}
                      </UBadge>
                    </div>

                    <template #description>
                      Status pembayaran mengikuti invoice dan transaksi
                      pembayaran.
                    </template>
                  </UFormField>
                </div>
              </UCard>

              <!-- JADWAL -->
              <UCard>
                <template #header>
                  <h2 class="font-semibold">Jadwal Sesi</h2>
                </template>

                <dl class="grid gap-4 sm:grid-cols-3">
                  <div>
                    <dt class="text-sm text-muted-foreground">Mulai</dt>
                    <dd class="mt-1 font-medium">
                      {{ formatDateTime(booking.starts_at) }}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm text-muted-foreground">Selesai</dt>
                    <dd class="mt-1 font-medium">
                      {{ formatDateTime(booking.ends_at) }}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm text-muted-foreground">Ruangan</dt>
                    <dd class="mt-1 font-medium">
                      {{ booking.room?.name ?? "-" }}
                    </dd>
                  </div>
                </dl>

                <p class="mt-4 text-sm text-muted-foreground">
                  {{ booking.participant_count }}
                  peserta
                </p>
              </UCard>

              <!-- PAKET -->
              <UCard>
                <template #header>
                  <div class="flex items-center justify-between">
                    <h2 class="font-semibold">Paket & Rincian Harga</h2>

                    <UButton
                      v-if="invoiceId"
                      icon="i-lucide-receipt"
                      color="primary"
                      variant="soft"
                      label="Lihat Invoice"
                      :to="`/dashboard/invoices/${invoiceId}`"
                    />
                  </div>
                </template>

                <div
                  class="flex items-start justify-between gap-4 border-b border-default pb-4"
                >
                  <div>
                    <p class="font-medium">
                      {{ booking.package?.name ?? "Tanpa paket" }}
                    </p>

                    <p
                      v-if="booking.package?.description"
                      class="mt-1 text-sm text-muted-foreground"
                    >
                      {{ booking.package.description }}
                    </p>
                  </div>

                  <span class="whitespace-nowrap font-medium">
                    {{ formatCurrency(booking.subtotal) }}
                  </span>
                </div>

                <div class="mt-4 space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span>Subtotal</span>
                    <span>
                      {{ formatCurrency(booking.subtotal) }}
                    </span>
                  </div>

                  <div class="flex justify-between">
                    <span>Diskon</span>
                    <span>
                      -{{ formatCurrency(booking.discount_amount) }}
                    </span>
                  </div>

                  <div class="flex justify-between">
                    <span>Pajak</span>
                    <span>
                      {{ formatCurrency(booking.tax_amount) }}
                    </span>
                  </div>

                  <div
                    class="flex justify-between border-t border-accented pt-3 text-base font-semibold"
                  >
                    <span>Total</span>
                    <span>
                      {{ formatCurrency(booking.total_amount) }}
                    </span>
                  </div>
                </div>

                <div
                  v-if="booking.booking_items.length"
                  class="mt-5 border-t border-default pt-4"
                >
                  <p class="mb-3 text-sm font-medium">Item tambahan</p>

                  <div
                    v-for="item in booking.booking_items"
                    :key="item.id"
                    class="flex justify-between gap-4 py-1 text-sm"
                  >
                    <span>
                      {{ item.description }}
                      x{{ item.quantity }}
                    </span>

                    <span>
                      {{ formatCurrency(item.total_price) }}
                    </span>
                  </div>
                </div>
              </UCard>

              <!-- PEMBAYARAN -->
              <UCard>
                <template #header>
                  <div class="flex items-center justify-between gap-3">
                    <h2 class="font-semibold">Pembayaran</h2>

                    <UBadge
                      v-if="payments.length"
                      color="neutral"
                      variant="subtle"
                    >
                      {{ payments.length }}
                      transaksi
                    </UBadge>
                  </div>
                </template>

                <div v-if="payments.length" class="divide-y divide-default">
                  <div
                    v-for="payment in payments"
                    :key="payment.id"
                    class="flex flex-col gap-4 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between"
                  >
                    <div class="min-w-0 space-y-1">
                      <div class="flex flex-wrap items-center gap-2">
                        <span class="font-semibold">
                          {{ formatCurrency(payment.amount) }}
                        </span>

                        <UBadge
                          :color="paymentColor(payment.status)"
                          variant="subtle"
                        >
                          {{ paymentStatusLabel(payment.status) }}
                        </UBadge>
                      </div>

                      <p class="text-sm text-muted-foreground">
                        {{ payment.method }}
                        ·
                        {{ formatDateTime(payment.paid_at) }}
                      </p>

                      <p
                        v-if="payment.payment_reference"
                        class="text-sm text-muted-foreground"
                      >
                        Referensi:
                        <span class="font-mono">
                          {{ payment.payment_reference }}
                        </span>
                      </p>

                      <p
                        v-if="payment.notes"
                        class="whitespace-pre-wrap text-sm text-muted-foreground"
                      >
                        {{ payment.notes }}
                      </p>

                      <!-- DETAIL REFUND -->
                      <div
                        v-if="payment.status === 'refunded'"
                        class="mt-2 rounded-md bg-elevated/50 p-3 text-sm"
                      >
                        <p class="font-medium">Refund</p>

                        <p
                          v-if="payment.refunded_at"
                          class="text-muted-foreground"
                        >
                          {{ formatDateTime(payment.refunded_at) }}
                        </p>

                        <p
                          v-if="payment.refund_reference"
                          class="text-muted-foreground"
                        >
                          Referensi:
                          <span class="font-mono">
                            {{ payment.refund_reference }}
                          </span>
                        </p>

                        <p
                          v-if="payment.refund_notes"
                          class="whitespace-pre-wrap text-muted-foreground"
                        >
                          {{ payment.refund_notes }}
                        </p>
                      </div>
                    </div>

                    <!-- REFUND BUTTON -->
                    <UButton
                      v-if="payment.status === 'paid'"
                      icon="i-lucide-rotate-ccw"
                      label="Refund"
                      color="error"
                      variant="soft"
                      class="shrink-0"
                      :disabled="isRefundSaving"
                      @click="openRefundModal(payment.id)"
                    />
                  </div>
                </div>

                <p v-else class="text-sm text-muted-foreground">
                  Belum ada transaksi pembayaran.
                </p>
              </UCard>

              <!-- CATATAN -->
              <UCard>
                <template #header>
                  <h2 class="font-semibold">Catatan Booking</h2>
                </template>

                <p class="whitespace-pre-wrap text-sm">
                  {{ booking.notes || "Belum ada catatan." }}
                </p>
              </UCard>
            </div>

            <!-- SIDEBAR -->
            <div class="space-y-6">
              <!-- CUSTOMER -->
              <UCard>
                <template #header>
                  <h2 class="font-semibold">Kontak Customer</h2>
                </template>

                <div class="space-y-3 text-sm">
                  <p class="font-medium">
                    {{ booking.customer?.full_name ?? "-" }}
                  </p>

                  <p>
                    {{ booking.customer?.phone || "Tidak ada nomor telepon" }}
                  </p>

                  <p>
                    {{ booking.customer?.email || "Tidak ada email" }}
                  </p>
                </div>
              </UCard>

              <!-- ASSIGNEES -->
              <UCard v-if="booking.booking_assignees.length">
                <template #header>
                  <h2 class="font-semibold">Tim Penanggung Jawab</h2>
                </template>

                <div class="space-y-3">
                  <div
                    v-for="assignment in booking.booking_assignees"
                    :key="assignment.id"
                    class="flex items-center justify-between gap-3 text-sm"
                  >
                    <span>
                      {{
                        assignment.employee?.full_name ??
                        "Employee tidak ditemukan"
                      }}
                    </span>

                    <UBadge color="neutral" variant="subtle">
                      {{ assignment.assignment_role }}
                    </UBadge>
                  </div>
                </div>
              </UCard>

              <!-- STATUS HISTORY -->
              <UCard>
                <template #header>
                  <h2 class="font-semibold">Riwayat Status</h2>
                </template>

                <div v-if="sortedHistory.length" class="space-y-4">
                  <div
                    v-for="entry in sortedHistory"
                    :key="entry.id"
                    class="border-l-2 border-primary pl-3"
                  >
                    <p class="text-sm font-medium">
                      {{ statusLabel(entry.to_status) }}
                    </p>

                    <p class="text-xs text-muted-foreground">
                      {{ formatDateTime(entry.created_at) }}
                    </p>

                    <p
                      v-if="entry.note"
                      class="mt-1 text-sm text-muted-foreground"
                    >
                      {{ entry.note }}
                    </p>
                  </div>
                </div>

                <p v-else class="text-sm text-muted-foreground">
                  Belum ada riwayat perubahan status.
                </p>
              </UCard>
            </div>
          </div>
        </template>
      </div>

      <!-- ==================================================
           REFUND MODAL
           ================================================== -->

      <UModal
        :open="refundModalOpen"
        title="Refund Pembayaran"
        description="Refund akan mengubah transaksi pembayaran menjadi refunded. Data pembayaran tidak dihapus."
        @update:open="
          (open) => {
            if (!open) closeRefundModal();
          }
        "
      >
        <template #body>
          <div class="space-y-4">
            <UAlert
              v-if="refundError"
              color="error"
              variant="soft"
              icon="i-lucide-circle-alert"
              title="Refund gagal"
              :description="refundError"
            />

            <UAlert
              color="warning"
              variant="soft"
              icon="i-lucide-info"
              title="Perhatian"
              description="Refund diproses untuk satu transaksi pembayaran yang dipilih. Transaksi tidak akan dihapus."
            />

            <UFormField label="Referensi refund" description="Opsional">
              <UInput
                v-model="refundReference"
                placeholder="Contoh: RF-2026-0001"
                class="w-full"
                :disabled="isRefundSaving"
              />
            </UFormField>

            <UFormField label="Catatan refund" description="Opsional">
              <UTextarea
                v-model="refundNotes"
                placeholder="Catatan mengenai refund..."
                class="w-full"
                :rows="4"
                :disabled="isRefundSaving"
              />
            </UFormField>
          </div>
        </template>

        <template #footer>
          <div class="flex justify-end gap-2">
            <UButton
              label="Batal"
              color="neutral"
              variant="outline"
              :disabled="isRefundSaving"
              @click="closeRefundModal"
            />

            <UButton
              label="Proses Refund"
              color="error"
              icon="i-lucide-rotate-ccw"
              :loading="isRefundSaving"
              @click="confirmRefund"
            />
          </div>
        </template>
      </UModal>

      <!-- ==================================================
           DELETE / CANCEL MODAL
           ================================================== -->

      <UModal
        :open="actionModal !== null"
        :title="actionModal === 'delete' ? 'Hapus Booking' : 'Batalkan Booking'"
        :description="
          actionModal === 'delete'
            ? 'Booking akan dihapus secara permanen.'
            : 'Booking akan berubah menjadi Cancelled. Data pembayaran yang sudah tercatat tetap dipertahankan.'
        "
        @update:open="
          (open) => {
            if (!open) closeActionModal();
          }
        "
      >
        <template #body>
          <div v-if="booking" class="space-y-4">
            <p class="text-sm">
              Booking

              <span class="font-mono font-semibold">
                {{ booking.booking_number }}
              </span>
            </p>

            <UAlert
              v-if="actionModal === 'cancel'"
              color="warning"
              variant="soft"
              icon="i-lucide-info"
              title="Perhatian"
              description="Invoice yang belum memiliki pembayaran akan di-void. Pembayaran yang sudah tercatat tidak akan dihapus."
            />

            <UAlert
              v-if="actionModal === 'delete'"
              color="error"
              variant="soft"
              icon="i-lucide-triangle-alert"
              title="Hapus permanen"
              description="Penghapusan hanya diperbolehkan untuk booking yang belum masuk proses finansial."
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
              @click="closeActionModal"
            />

            <UButton
              :label="
                actionModal === 'delete' ? 'Hapus Booking' : 'Batalkan Booking'
              "
              :color="actionModal === 'delete' ? 'error' : 'warning'"
              :loading="isProcessingAction"
              @click="confirmAction"
            />
          </div>
        </template>
      </UModal>
    </template>
  </UDashboardPanel>
</template>
