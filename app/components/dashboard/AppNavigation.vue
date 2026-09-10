<script lang="ts" setup>
import type { NavigationMenuItem } from "@nuxt/ui";

defineProps<{
  collapsed?: boolean;
}>();

const open = defineModel<boolean>("open", { default: false });

const navItems = ref<NavigationMenuItem[][]>([
  [
    {
      label: "Dashboard",
      icon: "i-lucide-star",
      to: "/dashboard",
      onSelect: () => {
        open.value = false;
      },
    },
    {
      label: "Calendar",
      icon: "i-lucide-calendar",
      to: "#",
      onSelect: () => {
        open.value = false;
      },
    },
    {
      label: "Booking List",
      icon: "i-lucide-clipboard-list",
      to: "#",
      onSelect: () => {
        open.value = false;
      },
    },
    {
      label: "Payments",
      icon: "i-lucide-credit-card",
      to: "#",
      onSelect: () => {
        open.value = false;
      },
    },
    // {
    //   label: "Customers",
    //   icon: "i-lucide-users",
    //   to: "/dashboard/customers",
    //   onSelect: () => {
    //     open.value = false;
    //   },
    // },
    {
      label: "Daftar Kustomer",
      icon: "i-lucide-users",
      to: "/dashboard/customers/daftar-customer",
      onSelect: () => {
        open.value = false;
      },
    },
    {
      label: "Settings",
      to: "#",
      icon: "i-lucide-settings",
      defaultOpen: true,
      type: "trigger",
      children: [
        {
          label: "General",
          to: "/dashboard/settings",
          exact: true,
          onSelect: () => {
            open.value = false;
          },
        },
        {
          label: "Members",
          to: "#",
          onSelect: () => {
            open.value = false;
          },
        },
        {
          label: "Notifications",
          to: "#",
          onSelect: () => {
            open.value = false;
          },
        },
        {
          label: "Packages",
          to: "#",
          onSelect: () => {
            open.value = false;
          },
        },
      ],
    },
  ],
  [
    {
      label: "Feedback",
      icon: "i-lucide-message-circle",
      to: "#",
      target: "_blank",
      onSelect: () => {
        open.value = false;
      },
    },
    {
      label: "Help & Support",
      icon: "i-lucide-info",
      to: "#",
      target: "_blank",
      onSelect: () => {
        open.value = false;
      },
    },
  ],
]);
</script>

<template>
  <div class="flex flex-col flex-1">
    <UNavigationMenu
      :collapsed="collapsed"
      :items="navItems[0]"
      orientation="vertical"
      tooltip
      popover
    />
    <UNavigationMenu
      :collapsed="collapsed"
      :items="navItems[1]"
      orientation="vertical"
      tooltip
      class="mt-auto"
    />
  </div>
</template>
