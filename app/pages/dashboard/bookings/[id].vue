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
  updatePaymentStatus,
} = useBookings();

const bookingId = computed(() => String(route.params.id ?? ""));
const isUpdating = ref(false);
const actionError = ref<string | null>(null);

const statusOptions: { label: string; value: BookingStatus }[] = [
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

const paymentOptions: { label: string; value: PaymentStatus }[] = [
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

function formatDateTime(value: string | null) {
  if (!value) return "-";

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
  return (
    statusOptions.find((option) => option.value === status)?.label ?? status
  );
}

function statusColor(
  status: BookingStatus,
): "neutral" | "primary" | "secondary" | "success" | "warning" | "error" {
  if (status === "cancelled") return "error";
  if (["ready", "delivered", "completed"].includes(status)) return "success";
  if (["shooting", "production"].includes(status)) return "warning";
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

async function changeStatus(status: BookingStatus) {
  if (!booking.value || status === booking.value.status) return;

  actionError.value = null;
  isUpdating.value = true;

  const result = await updateBookingStatus(booking.value.id, status);

  if (!result) {
    actionError.value = error.value ?? "Gagal mengubah status booking.";
  }

  isUpdating.value = false;
}

async function changePaymentStatus(status: PaymentStatus) {
  if (!booking.value || status === booking.value.payment_status) return;

  actionError.value = null;
  isUpdating.value = true;

  const result = await updatePaymentStatus(booking.value.id, status);

  if (!result) {
    actionError.value = error.value ?? "Gagal mengubah status pembayaran.";
  }

  isUpdating.value = false;
}

onMounted(() => loadBooking(bookingId.value));

watch(bookingId, (id) => {
  if (id) loadBooking(id);
});
</script>

<template>
  <UDashboardPanel id="booking-detail">
    <template #header>
      <DashboardPageHeader
        :title="booking?.booking_number ?? 'Detail Booking'"
        description="Informasi sesi, customer, pembayaran, dan proses produksi"
      >
        <template #left>
          <UButton
            icon="i-lucide-arrow-left"
            color="neutral"
            variant="ghost"
            aria-label="Kembali ke daftar booking"
            to="/dashboard/bookings"
          />
        </template>

        <template #right>
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
      </DashboardPageHeader>
    </template>

    <template #body>
      <div class="space-y-6 p-4 sm:p-6">
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
                Dibuat {{ formatDateTime(booking.created_at) }}
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
                    (item) => item.value === booking.payment_status,
                  )?.label
                }}
              </UBadge>
            </div>
          </div>

          <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
            <div class="space-y-6">
              <UCard>
                <template #header
                  ><h2 class="font-semibold">Status Operasional</h2></template
                >
                <div class="grid gap-4 sm:grid-cols-2">
                  <UFormField label="Status booking">
                    <USelect
                      :model-value="booking.status"
                      :items="statusOptions"
                      value-key="value"
                      label-key="label"
                      :disabled="isUpdating"
                      class="w-full"
                      @update:model-value="changeStatus"
                    />
                  </UFormField>
                  <UFormField label="Status pembayaran">
                    <USelect
                      :model-value="booking.payment_status"
                      :items="paymentOptions"
                      value-key="value"
                      label-key="label"
                      :disabled="isUpdating"
                      class="w-full"
                      @update:model-value="changePaymentStatus"
                    />
                  </UFormField>
                </div>
              </UCard>

              <UCard>
                <template #header
                  ><h2 class="font-semibold">Jadwal Sesi</h2></template
                >
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
                  {{ booking.participant_count }} peserta
                </p>
              </UCard>

              <UCard>
                <template #header
                  ><h2 class="font-semibold">
                    Paket & Rincian Harga
                  </h2></template
                >
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
                  <span class="whitespace-nowrap font-medium">{{
                    formatCurrency(booking.subtotal)
                  }}</span>
                </div>
                <div class="mt-4 space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span>Subtotal</span
                    ><span>{{ formatCurrency(booking.subtotal) }}</span>
                  </div>
                  <div class="flex justify-between">
                    <span>Diskon</span
                    ><span>-{{ formatCurrency(booking.discount_amount) }}</span>
                  </div>
                  <div class="flex justify-between">
                    <span>Pajak</span
                    ><span>{{ formatCurrency(booking.tax_amount) }}</span>
                  </div>
                  <div
                    class="flex justify-between border-t border-accented pt-3 text-base font-semibold"
                  >
                    <span>Total</span
                    ><span>{{ formatCurrency(booking.total_amount) }}</span>
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
                    <span>{{ item.description }} x{{ item.quantity }}</span
                    ><span>{{ formatCurrency(item.total_price) }}</span>
                  </div>
                </div>
              </UCard>

              <UCard>
                <template #header
                  ><h2 class="font-semibold">Catatan Booking</h2></template
                >
                <p class="whitespace-pre-wrap text-sm">
                  {{ booking.notes || "Belum ada catatan." }}
                </p>
              </UCard>
            </div>

            <div class="space-y-6">
              <UCard>
                <template #header
                  ><h2 class="font-semibold">Kontak Customer</h2></template
                >
                <div class="space-y-3 text-sm">
                  <p class="font-medium">
                    {{ booking.customer?.full_name ?? "-" }}
                  </p>
                  <p>
                    {{ booking.customer?.phone || "Tidak ada nomor telepon" }}
                  </p>
                  <p>{{ booking.customer?.email || "Tidak ada email" }}</p>
                </div>
              </UCard>

              <UCard v-if="booking.booking_assignees.length">
                <template #header
                  ><h2 class="font-semibold">Tim Penanggung Jawab</h2></template
                >
                <div class="space-y-3">
                  <div
                    v-for="assignment in booking.booking_assignees"
                    :key="assignment.id"
                    class="flex items-center justify-between gap-3 text-sm"
                  >
                    <span>{{
                      assignment.employee?.full_name ??
                      "Employee tidak ditemukan"
                    }}</span
                    ><UBadge color="neutral" variant="subtle">{{
                      assignment.assignment_role
                    }}</UBadge>
                  </div>
                </div>
              </UCard>

              <UCard>
                <template #header
                  ><h2 class="font-semibold">Riwayat Status</h2></template
                >
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
    </template>
  </UDashboardPanel>
</template>
