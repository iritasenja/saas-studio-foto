<script setup lang="ts">
import type { Database } from "~/types/database.types";

definePageMeta({
  layout: "dashboard",
  title: "Booking List",
});

type BookingStatus = Database["public"]["Enums"]["booking_status"];

type PaymentStatus = Database["public"]["Enums"]["payment_status"];

const { bookings, isLoading, error, loadBookings } = useBookings();

useTrackLoading(isLoading);

const search = ref("");
const selectedStatus = ref<BookingStatus | "all">("all");

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
      return "warning";

    case "production":
      return "warning";

    case "ready":
      return "success";

    case "delivered":
      return "success";

    case "completed":
      return "success";

    case "cancelled":
      return "error";

    case "inquiry":
      return "neutral";

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

onMounted(() => {
  loadBookings();
});
</script>

<template>
  <UDashboardPanel id="booking-list">
    <template #header>
      <DashboardPageHeader title="Booking List" description="List Data Booking">
        <template #right>
          <UButton
            icon="i-lucide-user-plus"
            label="Booking Baru"
            size="sm"
            type="button"
            color="primary"
            variant="solid"
            to="/dashboard/bookings/create"
          />
        </template>
      </DashboardPageHeader>
    </template>

    <template #body>
      <div class="space-y-6">
        <!-- Page intro -->
        <div>
          <h1 class="text-2xl font-semibold">Booking</h1>

          <p class="text-sm text-muted-foreground mt-1">
            Kelola jadwal dan proses booking customer.
          </p>
        </div>

        <!-- Toolbar -->
        <div
          class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
        >
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <UInput
              v-model="search"
              icon="i-lucide-search"
              placeholder="Cari booking atau customer..."
              class="w-full sm:w-80"
              clearable
            />

            <USelect
              v-model="selectedStatus"
              :items="statusOptions"
              value-key="value"
              label-key="label"
              class="w-full sm:w-48"
            />
          </div>

          <UButton
            icon="i-lucide-refresh-cw"
            variant="outline"
            color="neutral"
            :loading="isLoading"
            @click="refreshBookings"
          >
            Refresh
          </UButton>
        </div>

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

                  <th class="px-4 py-3">
                    <!-- Action -->
                  </th>
                </tr>
              </thead>

              <tbody>
                <tr
                  v-for="booking in filteredBookings"
                  :key="booking.id"
                  class="border-b border-default last:border-0 hover:bg-elevated/50"
                >
                  <!-- Booking number -->
                  <td class="px-4 py-4">
                    <div class="font-mono text-xs font-medium">
                      {{ booking.booking_number }}
                    </div>

                    <div class="mt-1 text-xs text-muted-foreground">
                      {{ booking.participant_count }} orang
                    </div>
                  </td>

                  <!-- Customer -->
                  <td class="px-4 py-4">
                    <div class="font-medium">
                      {{ booking.customer?.full_name ?? "—" }}
                    </div>
                  </td>

                  <!-- Schedule -->
                  <td class="px-4 py-4 whitespace-nowrap">
                    <div>
                      {{ formatDateTime(booking.starts_at) }}
                    </div>

                    <div
                      v-if="booking.ends_at"
                      class="mt-1 text-xs text-muted-foreground"
                    >
                      sampai {{ formatDateTime(booking.ends_at) }}
                    </div>
                  </td>

                  <!-- Package -->
                  <td class="px-4 py-4">
                    {{ booking.package?.name ?? "—" }}
                  </td>

                  <!-- Status -->
                  <td class="px-4 py-4">
                    <UBadge
                      :color="statusColor(booking.status)"
                      variant="subtle"
                    >
                      {{ statusLabel(booking.status) }}
                    </UBadge>
                  </td>

                  <!-- Payment -->
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

                  <!-- Action -->
                  <td class="px-4 py-4 text-right">
                    <UButton
                      icon="i-lucide-ellipsis"
                      color="neutral"
                      variant="ghost"
                      size="sm"
                      :to="`/dashboard/bookings/${booking.id}`"
                    />
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
    </template>
  </UDashboardPanel>
</template>
