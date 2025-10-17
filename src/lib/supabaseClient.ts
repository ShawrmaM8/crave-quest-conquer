// src/lib/supabaseClient.ts
import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL!;
const anonKey = process.env.SUPABASE_ANON_KEY!;

export const supabase = createClient(url, anonKey, {
  // recommended for realtime usage
  realtime: { params: { eventsPerSecond: 10 } }
});

