#!/bin/bash
set -e

echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env

if cd flutter 2>/dev/null; then
  git pull
  cd ..
else
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable
fi

flutter/bin/flutter config --enable-web
flutter/bin/flutter build web --release
