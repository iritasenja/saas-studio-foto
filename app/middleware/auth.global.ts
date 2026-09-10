// app/middleware/auth.global.ts

export default defineNuxtRouteMiddleware(async (to) => {
  const supabase = useSupabaseClient()

  const publicRoutes = [
    '/',
    '/gate/login',
    '/gate/register'
  ]

  const isPublicRoute = publicRoutes.includes(to.path)

  // Route public tidak perlu authentication
  if (isPublicRoute) {
    return
  }

  // Ambil user langsung dari Supabase
  const {
    data: { user }
  } = await supabase.auth.getUser()

  // Semua route selain public membutuhkan login
  if (!user) {
    return navigateTo('/gate/login')
  }
})
