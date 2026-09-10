import type { Database } from "~/types/database.types";

type ProfileRow = Database["public"]["Tables"]["profiles"]["Row"];

export type UserProfile = Pick<
  ProfileRow,
  "id" | "full_name" | "avatar_url" | "phone"
>;

export const useCurrentUser = () => {
  const supabase = useSupabaseClient<Database>();
  const user = useSupabaseUser();

  // Shared state terisolasi SSR
  const profile = useState<UserProfile | null>(
    "current-user-profile",
    () => null,
  );

  const isLoading = useState<boolean>("profile-loading", () => false);

  const error = useState<string | null>("profile-error", () => null);

  async function loadProfile() {
    if (!user.value?.id) {
      profile.value = null;
      return null;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const { data, error: profileError } = await supabase
        .from("profiles")
        .select("id, full_name, avatar_url, phone")
        .eq("id", user.value.id)
        .maybeSingle();

      if (profileError) {
        throw profileError;
      }

      profile.value = data;
      return profile.value;
    } catch (err) {
      console.error("Load profile error:", err);

      error.value =
        err instanceof Error ? err.message : "Gagal memuat profile.";
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  const name = computed(() => {
    return (
      profile.value?.full_name ||
      user.value?.user_metadata?.name ||
      user.value?.email ||
      "User"
    );
  });

  const userEmail = computed(() => {
    return user.value?.email ?? "";
  });

  const avatarUrl = computed(() => {
    return profile.value?.avatar_url ?? null;
  });

  function clearProfile() {
    profile.value = null;
    error.value = null;
  }

  return {
    user,
    profile,
    name,
    userEmail,
    avatarUrl,
    isLoading,
    error,
    loadProfile,
    clearProfile,
  };
};
