import { useEffect, useState } from "react";
import { supabase } from "../services/supabase";
import { useAuthStore } from "../store/authStore";

export const useMembership = () => {
  const { user } = useAuthStore();
  const [isActive, setIsActive] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [subscription, setSubscription] = useState<any>(null);

  useEffect(() => {
    if (!user) {
      setIsActive(false);
      setIsLoading(false);
      return;
    }

    const checkMembership = async () => {
      try {
        const { data, error } = await supabase
          .from("subscriptions")
          .select("*")
          .eq("user_id", user.id)
          .eq("status", "active")
          .gte("end_date", new Date().toISOString())
          .single();

        if (error || !data) {
          setIsActive(false);
        } else {
          setIsActive(true);
          setSubscription(data);
        }
      } catch (err) {
        setIsActive(false);
      } finally {
        setIsLoading(false);
      }
    };

    checkMembership();
  }, [user]);

  return { isActive, isLoading, subscription };
};
