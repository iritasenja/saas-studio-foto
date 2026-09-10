// app/middleware/tenant.global.ts

export default defineNuxtRouteMiddleware(async (to) => {
  const { tenants, tenant, loadTenants } = useTenant();

  const supabase = useSupabaseClient();

  // auth.global.ts sudah menangani authentication.
  // Di sini kita tetap pastikan user memang login.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return;
  }

  const isOnboardingRoute = to.path.startsWith("/gate/onboarding");

  // Pastikan tenant sudah dimuat
  if (tenants.value.length === 0) {
    await loadTenants();
  }

  // User belum mempunyai studio
  if (tenants.value.length === 0) {
    // Sudah berada di onboarding → biarkan
    if (isOnboardingRoute) {
      return;
    }

    // Belum onboarding → arahkan ke onboarding
    return navigateTo("/gate/onboarding");
  }

  // User mempunyai studio tetapi tenant aktif belum ada
  if (!tenant.value) {
    await loadTenants();
  }

  // Jika tetap tidak ada tenant aktif
  if (!tenant.value) {
    if (isOnboardingRoute) {
      return;
    }

    return navigateTo("/gate/onboarding");
  }

  // User sudah mempunyai tenant,
  // tetapi mencoba membuka onboarding.
  // if (isOnboardingRoute) {
  //   return navigateTo('/dashboard')
  // }
});
