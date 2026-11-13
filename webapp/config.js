// Supabase-Zugang fuer das Web-Portal (dieselben Werte wie config/backend.cfg im Spiel).
// Der anon-Key ist fuer Browser gedacht; geschuetzt wird alles durch die RLS-Regeln in supabase_schema.sql.
// NIEMALS den service_role-Key eintragen!
// Der Workflow .github/workflows/pages.yml ersetzt diese Datei beim Veroeffentlichen mit den GitHub-Secrets.
window.GOLF_CONFIG = {
  supabaseUrl: "https://DEIN-PROJEKT.supabase.co",
  anonKey: "DEIN_ANON_PUBLIC_KEY"
};
