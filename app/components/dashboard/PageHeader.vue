<script setup lang="ts">
defineProps<{
  title: string;
}>();
</script>

<template>
  <UDashboardNavbar :title="title" class="flex justify-between">
    <template #leading>
      <UDashboardSidebarCollapse variant="subtle" />
    </template>

    <template #trailing>
      <!-- Slot opsional jika page tertentu butuh tombol tambahan -->
      <slot name="trailing">
        <!-- <UButton
          icon="i-lucide-mail"
          color="neutral"
          variant="ghost"
          square
        /> -->
      </slot>
    </template>

    <template #right>
      <UChip position="top-left">
        <UButton icon="i-lucide-mail" color="neutral" variant="subtle" />
      </UChip>
      <UChip position="top-left">
        <UButton icon="i-lucide-bell" color="neutral" variant="subtle" />
      </UChip>
    </template>
  </UDashboardNavbar>
</template>
