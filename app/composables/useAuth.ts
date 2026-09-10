export const useAuth = () => {
  const supabase = useSupabaseClient()
  const { clearProfile } = useCurrentUser()
  const { clearTenant } = useTenant()

  const user = useSupabaseUser()

  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function register(
    name: string,
    email: string,
    password: string
  ) {
    isLoading.value = true
    error.value = null

    try {
      const { data, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            name
          }
        }
      })

      if (authError) {
        throw authError
      }

      return data
    } catch (err) {
      error.value = err instanceof Error
        ? err.message
        : 'Terjadi kesalahan saat melakukan registrasi.'

      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function login(email: string, password: string) {
    isLoading.value = true
    error.value = null

    try {
      const { data, error: authError } =
        await supabase.auth.signInWithPassword({
          email,
          password
        })

      if (authError) {
        throw authError
      }

      return data
    } catch (err) {
      error.value = err instanceof Error
        ? err.message
        : 'Email atau password tidak valid.'

      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function logout() {
    isLoading.value = true
    error.value = null

    try {
      const { error: authError } = await supabase.auth.signOut()

      if (authError) throw authError

      // Bersihkan state lokal
      clearProfile()
      clearTenant()
    } catch (err) {
      error.value = err instanceof Error
        ? err.message
        : 'Gagal keluar dari aplikasi.'
      throw err
    } finally {
      isLoading.value = false
    }
  }

  return {
    user,
    isLoading,
    error,
    register,
    login,
    logout
  }
}