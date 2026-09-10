<template>
  <UDashboardPanel id="dashboard-main">
    <!-- Navbar dinamis sesuai halaman -->
    <template #header>
      <DashboardPageHeader title="Dashboard Overview" />
    </template>

    <!-- Area konten utama -->
    <template #body>
      <div class="space-y-6 w-full">
        <div>
          <div>
            <h1 class="text-3xl font-bold">Dashboard</h1>

            <p class="text-muted mt-1">
              Selamat datang di Asisten Studio Foto.
            </p>
          </div>
        </div>

        <UAlert
          v-if="error"
          color="error"
          variant="soft"
          icon="i-lucide-circle-alert"
          :title="error"
        />

        <div v-if="isLoading">Memuat studio...</div>

        <template v-else-if="tenant">
          <UCard class="w-full">
            <div class="space-y-3">
              <div class="flex items-center gap-3">
                <UIcon name="i-lucide-building-2" class="size-6" />

                <div>
                  <p class="font-semibold">
                    {{ tenant.name }}
                  </p>

                  <p class="text-sm text-muted">
                    {{ tenant.slug }}
                  </p>
                </div>
              </div>

              <div class="flex gap-2">
                <UBadge color="primary">
                  {{ tenant.status }}
                </UBadge>

                <UBadge color="neutral">
                  {{ role }}
                </UBadge>
              </div>
            </div>
          </UCard>

          <UCard>
            <pre class="text-sm overflow-auto">{{ tenant }}</pre>
          </UCard>
        </template>

        <UAlert
          v-else
          color="warning"
          variant="soft"
          icon="i-lucide-circle-alert"
          title="Anda belum memiliki studio."
        />
      </div>
    </template>
  </UDashboardPanel>
</template>

<script setup lang="ts">
import { onMounted } from "vue";

definePageMeta({
  layout: "dashboard",
  title: "Dashboard",
});

const {
  tenant,
  role,
  isLoading,
  error,
  //   loadTenant
} = useTenant();

// Memastikan pemanggilan data tenant hanya berjalan di client-side (browser)
// onMounted(async () => {
//   await loadTenant()
// })
</script>
