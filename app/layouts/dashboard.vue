<script setup lang="ts">
import { onMounted } from "vue";

const toast = useToast();
const open = ref(false);

const { profile, loadProfile } = useCurrentUser();
const { tenants, loadTenants } = useTenant();

// Inisialisasi data user & tenant di level layout (Client-side sync)
onMounted(async () => {
  // Hanya fetch jika state masih kosong (menghindari duplikasi request setelah middleware berjalan)
  const promises = [];

  if (!profile.value) promises.push(loadProfile());
  if (!tenants.value || tenants.value.length === 0)
    promises.push(loadTenants());

  if (promises.length > 0) {
    await Promise.all(promises);
  }
});

// onMounted(async () => {
//   const cookie = useCookie('cookie-consent')
//   if (cookie.value === 'accepted') return

//   toast.add({
//     title: 'We use first-party cookies to enhance your experience on our website.',
//     duration: 0,
//     close: false,
//     actions: [
//       {
//         label: 'Accept',
//         color: 'neutral',
//         variant: 'outline',
//         onClick: () => {
//           cookie.value = 'accepted'
//         }
//       },
//       {
//         label: 'Opt out',
//         color: 'neutral',
//         variant: 'ghost'
//       }
//     ]
//   })
// })
</script>

<template>
  <UDashboardGroup>
    <UDashboardSidebar
      id="default"
      v-model:open="open"
      collapsible
      resizable
      class="bg-elevated/25"
      :ui="{ footer: 'lg:border-t lg:border-default' }"
    >
      <template #header="{ collapsed }">
        <DashboardTeamsMenu :collapsed="collapsed" />
      </template>

      <template #default="{ collapsed }">
        <DashboardAppNavigation v-model:open="open" :collapsed="collapsed" />
      </template>

      <template #footer="{ collapsed }">
        <DashboardUserMenu :collapsed="collapsed" />
      </template>
    </UDashboardSidebar>

    <!-- Slot langsung ke Page component -->
    <slot />

    <!-- <NotificationsSlideover /> -->
  </UDashboardGroup>
</template>
