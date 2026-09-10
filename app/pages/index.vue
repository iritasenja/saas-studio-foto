<script setup lang="ts">
// const user = useSupabaseUser()
</script>

<template>
  <div class="min-h-screen flex flex-col justify-between p-6">
    <!-- Header Navigation -->
    <header class="max-w-6xl w-full mx-auto flex justify-between items-center py-4">
      <div class="flex items-center gap-2 font-bold text-xl text-primary">
        <UIcon name="i-lucide-camera" class="w-6 h-6" />
        <span>Asisten Studio Foto</span>
      </div>
      <div class="flex gap-3">
        <UButton to="/gate/login" color="neutral" variant="ghost">Masuk</UButton>
        <UButton to="/gate/register" color="primary">Daftar Gratis</UButton>
      </div>
    </header>

    <!-- Hero Content -->
    <main class="max-w-3xl mx-auto text-center my-auto py-16">
      <UBadge color="primary" variant="soft" class="mb-4">SaaS Manajemen Studio Foto</UBadge>
      <h1 class="text-4xl sm:text-6xl font-extrabold tracking-tight mb-6">
        Kelola Booking & Studio Foto Tanpa Ribet
      </h1>
      <p class="text-lg text-slate-400 mb-8">
        Atur reservasi, alokasi printer & kamera, jadwal tim, dan cetak invoice dalam satu platform terintegrasi.
      </p>
      <div class="flex justify-center gap-4">
        <UButton to="/gate/register" size="xl" color="primary" icon="i-lucide-arrow-right">
          Daftar Sekarang
        </UButton>
        <UButton to="/gate/login" size="xl" color="primary" icon="i-lucide-arrow-right">
          Login
        </UButton>
      </div>
    </main>

    <!-- Footer -->
    <footer class="text-center text-sm text-slate-500 py-4">
      &copy; {{ new Date().getFullYear() }} Asisten Studio Foto. All rights reserved.
    </footer>
  </div>
</template>
