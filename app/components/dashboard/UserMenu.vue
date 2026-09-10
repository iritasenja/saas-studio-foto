<script setup lang="ts">
import type { DropdownMenuItem } from "@nuxt/ui";

defineProps<{
  collapsed?: boolean;
}>();

const colorMode = useColorMode();
const appConfig = useAppConfig();

const colors = [
  "red",
  "orange",
  "amber",
  "yellow",
  "lime",
  "green",
  "emerald",
  "teal",
  "cyan",
  "sky",
  "blue",
  "indigo",
  "violet",
  "purple",
  "fuchsia",
  "pink",
  "rose",
];
const neutrals = [
  "slate",
  "gray",
  "zinc",
  "neutral",
  "stone",
  "taupe",
  "mauve",
  "mist",
  "olive",
];

const { name, userEmail, avatarUrl } = useCurrentUser();
const { role } = useTenant();
const { logout } = useAuth();

// Handler logout yang menangani redirect & error handling
async function handleLogout() {
  try {
    await logout();
    // Redirect ke halaman login setelah berhasil logout
    await navigateTo("/gate/login", { replace: true, external: true });
  } catch (err) {
    console.error("Logout error:", err);
  }
}

const currentUser = computed(() => ({
  name: name.value,
  email: userEmail.value,
  role: role.value ?? "member",
  avatar: {
    src: avatarUrl.value ?? undefined,
    alt: name.value,
  },
}));

const items = computed<DropdownMenuItem[][]>(() => [
  [
    {
      type: "label",
      slot: "account-item",
      label: currentUser.value.name,
      email: currentUser.value.email,
      avatar: currentUser.value.avatar,
    },
  ],
  [
    {
      label: "Account",
      icon: "i-lucide-user",
    },
    {
      label: "Security",
      icon: "i-lucide-user-shield",
      to: "/dashboard/user/security",
    },
  ],
  [
    {
      label: "Billing",
      icon: "i-lucide-credit-card",
      to: "#",
    },
  ],
  [
    {
      label: "Theme",
      icon: "i-lucide-palette",
      children: [
        {
          label: "Primary",
          slot: "chip",
          chip: appConfig.ui.colors.primary,
          content: {
            align: "center",
            collisionPadding: 16,
          },
          children: colors.map((color) => ({
            label: color,
            chip: color,
            slot: "chip",
            checked: appConfig.ui.colors.primary === color,
            type: "checkbox",
            onSelect: (e) => {
              e.preventDefault();

              appConfig.ui.colors.primary = color;
            },
          })),
        },
        {
          label: "Neutral",
          slot: "chip",
          chip:
            appConfig.ui.colors.neutral === "neutral"
              ? "old-neutral"
              : appConfig.ui.colors.neutral,
          content: {
            align: "end",
            collisionPadding: 16,
          },
          children: neutrals.map((color) => ({
            label: color,
            chip: color === "neutral" ? "old-neutral" : color,
            slot: "chip",
            type: "checkbox",
            checked: appConfig.ui.colors.neutral === color,
            onSelect: (e) => {
              e.preventDefault();

              appConfig.ui.colors.neutral = color;
            },
          })),
        },
      ],
    },
    {
      label: "Appearance",
      slot: "appearance", // Menggunakan custom slot
      disabled: true, // Agar label utama tidak bisa diklik sebagai tombol biasa
    },
  ],
  [
    {
      label: "Log out",
      icon: "i-lucide-log-out",
      // Panggil handler logout di sini
      onSelect: handleLogout,
    },
  ],
]);
</script>

<template>
  <UDropdownMenu
    :items="items"
    :content="{ align: 'center', collisionPadding: 12 }"
    :ui="{
      content: collapsed ? 'w-48' : 'w-(--reka-dropdown-menu-trigger-width)',
    }"
  >
    <UButton
      color="neutral"
      variant="ghost"
      block
      :square="collapsed"
      class="data-[state=open]:bg-elevated py-2"
      :ui="{
        trailingIcon: 'text-dimmed',
      }"
      :trailing-icon="collapsed ? undefined : 'i-lucide-chevrons-up-down'"
    >
      <!-- Layout tombol saat sidebar terbuka / terkunci -->
      <div class="flex items-center gap-2.5 w-full min-w-0 text-left">
        <!-- Avatar User -->
        <UAvatar
          :src="currentUser.avatar.src"
          :alt="currentUser.avatar.alt"
          size="2xs"
          class="shrink-0"
        />

        <!-- Informasi User (Tampil hanya jika TIDAK collapsed) -->
        <template v-if="!collapsed">
          <div class="flex flex-col flex-1 min-w-0 leading-tight">
            <span class="truncate font-semibold text-highlighted">
              {{ currentUser.name }}
            </span>

            <span class="truncate text-[11px] text-dimmed mt-0.5">
              <UBadge
                :label="currentUser.role"
                color="primary"
                variant="subtle"
                size="xs"
                class="shrink-0 px-1.5 py-0 text-[10px]"
              />
            </span>
          </div>
        </template>
      </div>
    </UButton>

    <!-- Slot Dropdown Item Header (Tampilan saat menu dibuka) -->
    <template #account-item="{ item }">
      <div class="flex items-center gap-2 p-1">
        <UAvatar :src="currentUser.avatar.src" size="md" />
        <div class="flex flex-col min-w-0">
          <span class="font-medium truncate">{{ currentUser.name }}</span>
          <span class="text-xs text-dimmed truncate">{{
            currentUser.email
          }}</span>
        </div>
      </div>
    </template>

    <!-- Custom Slot Appearance (Dark | Light inline) -->
    <template #appearance>
      <div class="flex items-center justify-between w-full">
        <span class="font-medium flex items-center gap-1">
          <UIcon name="i-lucide-sun-moon text-dimmed" class="size-6" />
          Appearance
        </span>

        <!-- Toggle Switcher Dark / Light -->
        <div
          class="flex items-center gap-1 bg-muted p-0.5 rounded-md border border-default"
        >
          <UButton
            icon="i-lucide-sun"
            size="xs"
            :color="colorMode.preference === 'light' ? 'primary' : 'neutral'"
            :variant="colorMode.preference === 'light' ? 'solid' : 'ghost'"
            square
            aria-label="Light mode"
            @click.stop="colorMode.preference = 'light'"
          />
          <UButton
            icon="i-lucide-moon"
            size="xs"
            :color="colorMode.preference === 'dark' ? 'primary' : 'neutral'"
            :variant="colorMode.preference === 'dark' ? 'solid' : 'ghost'"
            square
            aria-label="Dark mode"
            @click.stop="colorMode.preference = 'dark'"
          />
        </div>
      </div>
    </template>

    <template #chip-leading="{ item }">
      <div class="inline-flex items-center justify-center shrink-0 size-5">
        <span
          class="rounded-full ring ring-bg bg-(--chip-light) dark:bg-(--chip-dark) size-2"
          :style="{
            '--chip-light': `var(--color-${(item as any).chip}-500)`,
            '--chip-dark': `var(--color-${(item as any).chip}-400)`,
          }"
        />
      </div>
    </template>
  </UDropdownMenu>
</template>
