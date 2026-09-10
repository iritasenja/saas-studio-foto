<script setup lang="ts">
import type { DropdownMenuItem } from '@nuxt/ui'

defineProps<{
  collapsed?: boolean
}>()

const router = useRouter()
// 1. Sesuaikan variabel yang di-destructure dari useTenant
const { tenant, tenants, setTenant } = useTenant()

// 2. Mapping array `tenants` (berisi daftar TenantMembership)
const teams = computed(() => {
  return tenants.value.map(item => ({
    id: item.tenant_id,
    label: item.tenants?.name || 'Studio Tanpa Nama',
    avatar: {
      // Prioritaskan logo dari database, jika kosong baru pakai fallback public
      src: item.tenants?.logo_url || '/starstudio.png', 
      alt: item.tenants?.name || 'Studio'
    },
    role: item.role,
    raw: item
  }))
})

// Studio yang sedang aktif
const selectedTeam = computed(() => {
  if (!tenant.value) return null
  return teams.value.find(t => t.id === tenant.value?.id) || teams.value[0] || null
})

// Menu items untuk UDropdownMenu
const items = computed<DropdownMenuItem[][]>(() => {
  const teamItems = teams.value.map(team => ({
    label: team.label,
    avatar: team.avatar,
    type: 'checkbox' as const,
    checked: team.id === tenant.value?.id,
    onSelect() {
      if (team.id !== tenant.value?.id) {
        // 3. Panggil setTenant menggunakan objek TenantMembership asli
        setTenant(team.raw)
        refreshNuxtData()
      }
    }
  }))

  const actionItems = [
    {
      label: 'Create Studio',
      icon: 'i-lucide-circle-plus',
      onSelect() {
        router.push('/gate/onboarding')
      }
    },
    {
      label: 'Manage studios',
      icon: 'i-lucide-cog',
      onSelect() {
        router.push('/dashboard/settings/studio')
      }
    }
  ]

  return [teamItems, actionItems]
})
</script>

<template>
  <UDropdownMenu
    :items="items"
    :content="{ align: 'center', collisionPadding: 12 }"
    :ui="{ content: collapsed ? 'w-48' : 'w-(--reka-dropdown-menu-trigger-width)' }"
  >
    <UButton
      v-if="selectedTeam"
      v-bind="{
        ...selectedTeam,
        label: collapsed ? undefined : selectedTeam?.label,
        trailingIcon: collapsed ? undefined : 'i-lucide-chevrons-up-down'
      }"
      color="neutral"
      variant="ghost"
      block
      :square="collapsed"
      class="data-[state=open]:bg-elevated"
      :class="[!collapsed && 'py-2']"
      :ui="{
        trailingIcon: 'text-dimmed'
      }"
    />
  </UDropdownMenu>
</template>