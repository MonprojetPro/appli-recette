@echo off
echo === Flutter Web avec Hot Restart (tapez 'r' pour reload, 'R' pour restart) ===
flutter run -d chrome --web-port=8080 --web-hostname=localhost --target=lib/main_development.dart --dart-define=SUPABASE_URL=https://dfwokjnkhcuyvsabgals.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRmd29ram5raGN1eXZzYWJnYWxzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMjE2NjksImV4cCI6MjA4Njg5NzY2OX0.HcVUOlI9H0D_nqh9qONah_RVjhAfX3DmKlZQVZx4R7s
