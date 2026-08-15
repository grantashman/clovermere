import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
const configured = Boolean(url && anonKey && !url.includes('your-project') && !anonKey.includes('your-anon-key'));

export const supabase = configured ? createClient(url, anonKey) : null;
export const supabaseConfigured = configured;
