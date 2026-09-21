<!-- app/pages/dashboard/bookings/create.vue -->
<script setup lang="ts">
import type { Database } from "~/types/database.types";

definePageMeta({
  layout: "dashboard",
  title: "Create New Booking",
});

type Customer = Database["public"]["Tables"]["customers"]["Row"];
type Package = Database["public"]["Tables"]["packages"]["Row"];
type Room = Database["public"]["Tables"]["studio_rooms"]["Row"];

const supabase = useSupabaseClient<Database>();
const router = useRouter();

// ======================================================
// COMPOSABLES
// ======================================================

const {
  customers,
  loadCustomers,
  addCustomer,
  error: customerError,
} = useCustomers();

const {
  addBooking,
  isLoading: isBookingLoading,
  error: bookingError,
} = useBookings();

const { tenantId } = useTenant();

// ======================================================
// MASTER DATA
// ======================================================

const packages = ref<Package[]>([]);
const rooms = ref<Room[]>([]);

const isLoadingMasterData = ref(false);

// ======================================================
// CUSTOMER
// ======================================================

const customerSearch = ref("");
const isCreatingCustomer = ref(false);
const isSavingCustomer = ref(false);
const customerFormError = ref<string | null>(null);

const newCustomerForm = reactive({
  code: "",
  full_name: "",
  phone: "",
  email: "",
  notes: "",
});

// Customer aktif yang dipilih
const selectedCustomer = computed<Customer | null>(() => {
  if (!form.customer_id) return null;

  return (
    customers.value.find((customer) => customer.id === form.customer_id) ?? null
  );
});

// Customer yang tampil berdasarkan pencarian
const filteredCustomers = computed(() => {
  const keyword = customerSearch.value.trim().toLowerCase();

  const activeCustomers = customers.value.filter(
    (customer) => customer.is_active,
  );

  if (!keyword) {
    return activeCustomers;
  }

  return activeCustomers.filter((customer) => {
    return [customer.full_name, customer.code, customer.phone, customer.email]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(keyword));
  });
});

const customerOptions = computed(() =>
  filteredCustomers.value.map((customer) => ({
    label: customer.code
      ? `${customer.full_name} (${customer.code})`
      : customer.full_name,
    value: customer.id,
  })),
);

// ======================================================
// FORM BOOKING
// ======================================================

const now = new Date();

function formatDateForInput(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

function formatTimeForInput(date: Date) {
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");

  return `${hours}:${minutes}`;
}

const defaultStart = new Date(now.getTime() + 60 * 60 * 1000);

const form = reactive({
  customer_id: "",
  package_id: "",
  room_id: "",

  starts_at: formatDateForInput(defaultStart),
  start_time: formatTimeForInput(defaultStart),

  duration_minutes: 60,
  participant_count: 1,

  notes: "",

  status: "pending" as Database["public"]["Enums"]["booking_status"],
  payment_status: "unpaid" as Database["public"]["Enums"]["payment_status"],
});

// ======================================================
// PRICE
// ======================================================

const discountAmount = ref(0);
const taxAmount = ref(0);

const selectedPackage = computed<Package | null>(() => {
  if (!form.package_id) return null;

  return packages.value.find((item) => item.id === form.package_id) ?? null;
});

const basePrice = computed(() => {
  return Number(selectedPackage.value?.base_price ?? 0);
});

const baseDuration = computed(() => {
  return Number(selectedPackage.value?.base_duration_minutes ?? 0);
});

const includedPeople = computed(() => {
  return Number(selectedPackage.value?.included_people ?? 1);
});

const maxPeople = computed(() => {
  const value = selectedPackage.value?.max_people;

  return value == null ? null : Number(value);
});

const extraPersonPrice = computed(() => {
  return Number(selectedPackage.value?.extra_person_price ?? 0);
});

const extraDurationPricePerMinute = computed(() => {
  return Number(selectedPackage.value?.extra_duration_price_per_minute ?? 0);
});

const extraPeople = computed(() => {
  return Math.max(0, form.participant_count - includedPeople.value);
});

const extraPeopleAmount = computed(() => {
  return extraPeople.value * extraPersonPrice.value;
});

const extraDurationMinutes = computed(() => {
  if (!baseDuration.value) return 0;

  return Math.max(0, form.duration_minutes - baseDuration.value);
});

const extraDurationAmount = computed(() => {
  return extraDurationMinutes.value * extraDurationPricePerMinute.value;
});

const subtotal = computed(() => {
  return basePrice.value + extraPeopleAmount.value + extraDurationAmount.value;
});

const totalAmount = computed(() => {
  return Math.max(
    0,
    subtotal.value -
      Number(discountAmount.value || 0) +
      Number(taxAmount.value || 0),
  );
});

// ======================================================
// ROOM OPTIONS
// ======================================================

const roomOptions = computed(() =>
  rooms.value.map((room) => ({
    label: room.name,
    value: room.id,
  })),
);

// ======================================================
// PACKAGE OPTIONS
// ======================================================

const packageOptions = computed(() =>
  packages.value
    .filter((item) => item.is_active)
    .map((item) => ({
      label: item.name,
      value: item.id,
    })),
);

// ======================================================
// VALIDATION
// ======================================================

const submitError = ref<string | null>(null);

const canSubmit = computed(() => {
  return (
    Boolean(form.customer_id) &&
    Boolean(form.starts_at) &&
    Boolean(form.start_time) &&
    // Boolean(form.room_id) &&
    form.participant_count > 0
  );
});

// ======================================================
// LOAD MASTER DATA
// ======================================================

async function loadMasterData() {
  if (!tenantId.value) return;

  isLoadingMasterData.value = true;

  try {
    const [packageResult, roomResult] = await Promise.all([
      supabase
        .from("packages")
        .select("*")
        .eq("tenant_id", tenantId.value)
        .order("name", { ascending: true }),

      supabase
        .from("studio_rooms")
        .select("*")
        .eq("tenant_id", tenantId.value)
        .order("name", { ascending: true }),
    ]);

    if (packageResult.error) {
      throw packageResult.error;
    }

    if (roomResult.error) {
      throw roomResult.error;
    }

    packages.value = packageResult.data ?? [];
    rooms.value = roomResult.data ?? [];
  } catch (error) {
    console.error("Load booking master data error:", error);

    submitError.value =
      error instanceof Error ? error.message : "Gagal memuat data booking.";
  } finally {
    isLoadingMasterData.value = false;
  }
}

// ======================================================
// WATCH
// ======================================================

const selectedRoom = computed<Room | null>(() => {
  if (!form.room_id) return null;

  return rooms.value.find((room) => room.id === form.room_id) ?? null;
});

// Ketika package berubah, sesuaikan durasi dan jumlah peserta
watch(
  () => form.package_id,
  () => {
    const packageData = selectedPackage.value;

    if (!packageData) return;

    // Package menjadi default durasi.
    // Petugas masih boleh mengubahnya secara manual setelah ini.
    if (packageData.base_duration_minutes != null) {
      form.duration_minutes = Number(packageData.base_duration_minutes);
    }

    // Default jumlah peserta mengikuti package.
    if (packageData.included_people != null) {
      form.participant_count = Number(packageData.included_people);
    }
  },
);

// ======================================================
// CUSTOMER — NEW
// ======================================================

function openNewCustomerForm() {
  customerFormError.value = null;

  newCustomerForm.code = "";
  newCustomerForm.full_name = "";
  newCustomerForm.phone = "";
  newCustomerForm.email = "";
  newCustomerForm.notes = "";

  isCreatingCustomer.value = true;
}

function closeNewCustomerForm() {
  if (isSavingCustomer.value) return;

  isCreatingCustomer.value = false;
  customerFormError.value = null;
}

async function saveNewCustomer() {
  const fullName = newCustomerForm.full_name.trim();

  if (!fullName) {
    customerFormError.value = "Nama customer wajib diisi.";
    return;
  }

  customerFormError.value = null;
  isSavingCustomer.value = true;

  try {
    const customer = await addCustomer({
      code: newCustomerForm.code.trim() || null,
      full_name: fullName,
      phone: newCustomerForm.phone.trim() || null,
      email: newCustomerForm.email.trim() || null,
      notes: newCustomerForm.notes.trim() || null,
      is_active: true,
    });

    if (!customer) {
      customerFormError.value =
        customerError.value ?? "Gagal membuat customer baru.";
      return;
    }

    // Langsung pilih customer yang baru dibuat
    form.customer_id = customer.id;

    // Bersihkan pencarian agar customer baru terlihat
    customerSearch.value = "";

    // Tutup modal
    isCreatingCustomer.value = false;
  } catch (error) {
    console.error("Create customer from booking error:", error);

    customerFormError.value =
      error instanceof Error ? error.message : "Gagal membuat customer baru.";
  } finally {
    isSavingCustomer.value = false;
  }
}

// ======================================================
// BOOKING
// ======================================================

// helper representasi timezone
function toLocalISOString(date: Date) {
  const offset = -date.getTimezoneOffset();

  const sign = offset >= 0 ? "+" : "-";
  const hours = String(Math.floor(Math.abs(offset) / 60)).padStart(2, "0");
  const minutes = String(Math.abs(offset) % 60).padStart(2, "0");

  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");

  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  const second = String(date.getSeconds()).padStart(2, "0");

  return `${year}-${month}-${day}T${hour}:${minute}:${second}${sign}${hours}:${minutes}`;
}

function buildStartsAt() {
  const start = new Date(`${form.starts_at}T${form.start_time}:00`);

  if (Number.isNaN(start.getTime())) {
    return null;
  }

  return toLocalISOString(start);
}

function buildEndsAt() {
  const start = new Date(`${form.starts_at}T${form.start_time}:00`);

  const duration = Number(form.duration_minutes);

  if (Number.isNaN(start.getTime()) || !duration || duration <= 0) {
    return null;
  }

  const end = new Date(start.getTime() + duration * 60 * 1000);

  return toLocalISOString(end);
}

const endTime = computed(() => {
  if (!form.starts_at || !form.start_time) {
    return "";
  }

  const duration = Number(form.duration_minutes);

  if (!duration || duration <= 0) {
    return "";
  }

  const start = new Date(`${form.starts_at}T${form.start_time}:00`);

  if (Number.isNaN(start.getTime())) {
    return "";
  }

  const end = new Date(start.getTime() + duration * 60 * 1000);

  return end.toLocaleTimeString("id-ID", {
    hour: "2-digit",
    minute: "2-digit",
  });
});

async function onSubmit() {
  submitError.value = null;

  const startsAt = buildStartsAt();
  const endsAt = buildEndsAt();

  if (!tenantId.value) {
    submitError.value = "Tenant aktif tidak ditemukan.";
    return;
  }

  if (!startsAt || !endsAt) {
    submitError.value = "Tanggal, jam mulai, dan durasi booking tidak valid.";
    return;
  }

  if (!form.customer_id) {
    submitError.value = "Customer wajib dipilih.";
    return;
  }

  // if (!form.room_id) {
  //   submitError.value = "Ruangan studio wajib dipilih.";
  //   return;
  // }

  if (!form.starts_at || !form.start_time) {
    submitError.value = "Tanggal dan jam booking wajib diisi.";
    return;
  }

  if (form.participant_count < 1) {
    submitError.value = "Jumlah peserta minimal 1 orang.";
    return;
  }

  if (maxPeople.value !== null && form.participant_count > maxPeople.value) {
    submitError.value = `Jumlah peserta melebihi batas maksimal paket (${maxPeople.value} orang).`;
    return;
  }

  submitError.value = null;

  const booking = await addBooking({
    customer_id: form.customer_id,
    package_id: form.package_id || null,
    room_id: form.room_id || null,

    starts_at: startsAt,
    ends_at: endsAt,

    participant_count: form.participant_count,

    status: "pending",
    payment_status: "unpaid",

    subtotal: subtotal.value,
    discount_amount: Number(discountAmount.value || 0),
    tax_amount: Number(taxAmount.value || 0),
    total_amount: totalAmount.value,

    notes: form.notes.trim() || null,
  });

  if (!booking) {
    submitError.value = bookingError.value ?? "Gagal membuat booking.";
    return;
  }

  // addBooking() sudah mengambil detail booking
  // setelah RPC create_booking berhasil.
  await router.push(`/dashboard/bookings/${booking.id}`);
}

// ======================================================
// FORMAT
// ======================================================

function formatCurrency(value: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(value);
}

// ======================================================
// INITIAL LOAD
// ======================================================

onMounted(async () => {
  await Promise.all([loadCustomers(), loadMasterData()]);
});
</script>

<template>
  <UDashboardPanel>
    <template #header>
      <DashboardPageHeader title="Booking Baru">
        <template #right>
          <UButton
            icon="i-lucide-user-plus"
            size="md"
            color="primary"
            variant="soft"
            type="button"
            @click="openNewCustomerForm"
          >
            Customer Baru
          </UButton>
        </template>
      </DashboardPageHeader>
    </template>

    <template #body>
      <div class="mx-auto max-w-5xl p-4 sm:p-6">
        <form class="space-y-6" @submit.prevent="onSubmit">
          <!-- ================================================= -->
          <!-- CUSTOMER -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div class="flex items-center justify-between gap-4">
                <div>
                  <h2 class="font-semibold">Customer</h2>
                  <p class="text-sm text-muted-foreground">
                    Pilih customer yang melakukan sesi foto.
                  </p>
                </div>

                <UButton
                  icon="i-lucide-user-plus"
                  size="md"
                  color="primary"
                  variant="soft"
                  type="button"
                  @click="openNewCustomerForm"
                >
                  Customer Baru
                </UButton>
              </div>
            </template>

            <div class="space-y-4">
              <!-- Search customer -->
              <UFormField label="Cari Customer">
                <UInput
                  v-model="customerSearch"
                  icon="i-lucide-search"
                  placeholder="Cari nama, kode, telepon, atau email..."
                  class="w-full"
                  clearable
                />
              </UFormField>

              <!-- Customer selector -->
              <UFormField label="Customer" required>
                <USelect
                  v-model="form.customer_id"
                  :items="customerOptions"
                  placeholder="Pilih customer..."
                  class="w-full"
                />
              </UFormField>

              <!-- Tidak ditemukan -->
              <div
                v-if="customerSearch.trim() && filteredCustomers.length === 0"
                class="rounded-lg border border-dashed p-4 text-center"
              >
                <p class="text-sm text-muted-foreground">
                  Customer dengan kata
                  <strong> "{{ customerSearch }}" </strong>
                  tidak ditemukan.
                </p>

                <UButton
                  class="mt-3"
                  size="sm"
                  icon="i-lucide-user-plus"
                  color="primary"
                  variant="soft"
                  type="button"
                  @click="openNewCustomerForm"
                >
                  Buat Customer Baru
                </UButton>
              </div>

              <!-- Customer terpilih -->
              <div
                v-if="selectedCustomer"
                class="rounded-lg border bg-muted/30 p-4"
              >
                <div class="flex items-start justify-between gap-4">
                  <div class="space-y-1">
                    <div class="flex items-center gap-2">
                      <p class="font-medium">
                        {{ selectedCustomer.full_name }}
                      </p>

                      <UBadge
                        v-if="selectedCustomer.code"
                        size="xs"
                        color="neutral"
                        variant="subtle"
                      >
                        {{ selectedCustomer.code }}
                      </UBadge>
                    </div>

                    <p class="text-sm text-muted-foreground">
                      {{ selectedCustomer.phone || "Tidak ada nomor telepon" }}
                    </p>

                    <p
                      v-if="selectedCustomer.email"
                      class="text-sm text-muted-foreground"
                    >
                      {{ selectedCustomer.email }}
                    </p>
                  </div>

                  <UButton
                    icon="i-lucide-x"
                    size="xs"
                    color="neutral"
                    variant="ghost"
                    type="button"
                    aria-label="Hapus pilihan customer"
                    @click="form.customer_id = ''"
                  />
                </div>
              </div>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- JADWAL -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div>
                <h2 class="font-semibold">Jadwal Sesi</h2>
                <p class="text-sm text-muted-foreground">
                  Tentukan tanggal, jam, dan durasi sesi foto.
                </p>
              </div>
            </template>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <UFormField label="Tanggal" required>
                <UInput v-model="form.starts_at" type="date" class="w-full" />
              </UFormField>

              <UFormField label="Jam Mulai" required>
                <UInput v-model="form.start_time" type="time" class="w-full" />
              </UFormField>

              <UFormField label="Durasi (menit)" required>
                <UInput
                  v-model.number="form.duration_minutes"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </UFormField>

              <UFormField label="Jam Selesai">
                <UInput
                  :model-value="endTime"
                  readonly
                  icon="i-lucide-clock"
                  class="w-full"
                />
              </UFormField>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- PACKAGE -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div>
                <h2 class="font-semibold">Paket & Sesi</h2>
                <p class="text-sm text-muted-foreground">
                  Tentukan paket dan jumlah peserta.
                </p>
              </div>
            </template>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <UFormField label="Paket">
                <USelect
                  v-model="form.package_id"
                  :items="packageOptions"
                  placeholder="Pilih paket..."
                  class="w-full"
                />
              </UFormField>

              <UFormField label="Jumlah Peserta" required>
                <UInput
                  v-model.number="form.participant_count"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </UFormField>
            </div>

            <!-- Package information -->
            <div
              v-if="selectedPackage"
              class="mt-4 rounded-lg border bg-muted/30 p-4"
            >
              <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <div>
                  <p class="text-xs text-muted-foreground">Harga Dasar</p>
                  <p class="font-medium">
                    {{ formatCurrency(basePrice) }}
                  </p>
                </div>

                <div>
                  <p class="text-xs text-muted-foreground">Durasi Dasar</p>
                  <p class="font-medium">{{ baseDuration }} menit</p>
                </div>

                <div>
                  <p class="text-xs text-muted-foreground">Termasuk</p>
                  <p class="font-medium">{{ includedPeople }} orang</p>
                </div>

                <div>
                  <p class="text-xs text-muted-foreground">Maksimal</p>
                  <p class="font-medium">
                    {{
                      maxPeople === null
                        ? "Tidak dibatasi"
                        : `${maxPeople} orang`
                    }}
                  </p>
                </div>
              </div>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- RUANGAN STUDIO -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div>
                <h2 class="font-semibold">Ruangan Studio</h2>
                <p class="text-sm text-muted-foreground">
                  Pilih ruangan studio jika sesi dilakukan di studio.
                </p>
              </div>
            </template>

            <div>
              <UFormField label="Ruangan Studio">
                <USelect
                  v-model="form.room_id"
                  :items="roomOptions"
                  :disabled="roomOptions.length === 0"
                  placeholder="Tidak menggunakan ruangan studio"
                  class="w-full"
                />
              </UFormField>

              <p
                v-if="roomOptions.length === 0"
                class="mt-3 text-xs text-muted-foreground"
              >
                Belum ada ruangan studio yang tersedia untuk tenant ini.
              </p>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- HARGA -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div>
                <h2 class="font-semibold">Ringkasan Harga</h2>
              </div>
            </template>

            <div class="space-y-3">
              <div class="flex justify-between gap-4 text-sm">
                <span>Harga Paket</span>
                <span>
                  {{ formatCurrency(basePrice) }}
                </span>
              </div>

              <div
                v-if="extraPeopleAmount > 0"
                class="flex justify-between gap-4 text-sm"
              >
                <span> Extra {{ extraPeople }} peserta </span>
                <span>
                  {{ formatCurrency(extraPeopleAmount) }}
                </span>
              </div>

              <div
                v-if="extraDurationAmount > 0"
                class="flex justify-between gap-4 text-sm"
              >
                <span>
                  Extra durasi ({{ extraDurationMinutes }}
                  menit)
                </span>
                <span>
                  {{ formatCurrency(extraDurationAmount) }}
                </span>
              </div>

              <div
                class="flex justify-between gap-4 border-t border-accented pt-3 font-medium"
              >
                <span>Subtotal</span>
                <span>
                  {{ formatCurrency(subtotal) }}
                </span>
              </div>

              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <UFormField label="Diskon">
                  <UInput
                    v-model.number="discountAmount"
                    type="number"
                    min="0"
                    class="w-full"
                  />
                </UFormField>

                <UFormField label="Pajak">
                  <UInput
                    v-model.number="taxAmount"
                    type="number"
                    min="0"
                    class="w-full"
                  />
                </UFormField>
              </div>

              <div
                class="flex justify-between gap-4 border-t border-accented pt-4 text-lg font-semibold"
              >
                <span>Total</span>
                <span>
                  {{ formatCurrency(totalAmount) }}
                </span>
              </div>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- CATATAN -->
          <!-- ================================================= -->

          <UCard>
            <template #header>
              <div>
                <h2 class="font-semibold">Catatan</h2>
              </div>
            </template>

            <UTextarea
              v-model="form.notes"
              placeholder="Catatan tambahan untuk booking..."
              :rows="4"
              class="w-full"
            />
          </UCard>

          <!-- ================================================= -->
          <!-- BOOKING STATUS -->
          <!-- ================================================= -->

          <UCard>
            <div class="flex items-start gap-3">
              <UIcon
                name="i-lucide-clock-3"
                class="mt-0.5 size-5 text-warning"
              />

              <div>
                <p class="font-medium">
                  Booking akan dibuat sebagai
                  <UBadge color="warning" variant="subtle"> Pending </UBadge>
                </p>

                <p class="mt-1 text-sm text-muted-foreground">
                  Slot belum dianggap resmi terkonfirmasi. Setelah customer
                  melakukan pembayaran, staff dapat mencatat pembayaran dan
                  mengubah booking menjadi
                  <strong>Confirmed</strong>.
                </p>
              </div>
            </div>
          </UCard>

          <!-- ================================================= -->
          <!-- ERROR -->
          <!-- ================================================= -->

          <UAlert
            v-if="submitError"
            color="error"
            variant="soft"
            icon="i-lucide-circle-alert"
            :title="submitError"
          />

          <!-- ================================================= -->
          <!-- ACTION -->
          <!-- ================================================= -->

          <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <UButton
              color="neutral"
              variant="ghost"
              type="button"
              to="/dashboard/bookings"
              :disabled="isBookingLoading"
            >
              Batal
            </UButton>

            <UButton
              color="primary"
              type="submit"
              icon="i-lucide-calendar-plus"
              :loading="isBookingLoading"
              :disabled="!canSubmit || isLoadingMasterData"
            >
              Buat Booking
            </UButton>
          </div>
        </form>
      </div>
    </template>
  </UDashboardPanel>

  <!-- ======================================================= -->
  <!-- MODAL CUSTOMER BARU -->
  <!-- ======================================================= -->

  <USlideover
    v-model:open="isCreatingCustomer"
    title="Add New Customer"
    description="Setelah disimpan, customer akan otomatis dipilih untuk booking ini."
    :ui="{ content: 'lg:min-w-xl' }"
  >
    <template #body>
      <form
        id="new-customer-form"
        class="space-y-5"
        @submit.prevent="saveNewCustomer"
      >
        <UAlert
          v-if="customerFormError"
          color="error"
          variant="soft"
          icon="i-lucide-circle-alert"
          :title="customerFormError"
        />

        <UFormField label="Nama Lengkap" required>
          <UInput
            v-model="newCustomerForm.full_name"
            placeholder="Nama lengkap customer"
            class="w-full"
            autofocus
          />
        </UFormField>

        <UFormField label="Telepon / WhatsApp">
          <UInput
            v-model="newCustomerForm.phone"
            placeholder="08123456789"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Email">
          <UInput
            v-model="newCustomerForm.email"
            type="email"
            placeholder="customer@email.com"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Catatan">
          <UTextarea
            v-model="newCustomerForm.notes"
            placeholder="Catatan tambahan..."
            :rows="3"
            class="w-full"
          />
        </UFormField>
      </form>
    </template>

    <template #footer>
      <div class="flex w-full justify-end gap-2 pt-2">
        <UButton
          type="button"
          color="neutral"
          variant="ghost"
          :disabled="isSavingCustomer"
          @click="closeNewCustomerForm"
        >
          Batal
        </UButton>

        <UButton
          form="new-customer-form"
          type="submit"
          color="primary"
          icon="i-lucide-user-plus"
          :loading="isSavingCustomer"
        >
          Simpan & Pilih Customer
        </UButton>
      </div>
    </template>
  </USlideover>
</template>
