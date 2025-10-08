#!/bin/bash
# Quick Migration Script for Availability Persistence Fix
# Run this in your terminal to apply the database changes

echo "🚀 Applying Availability Persistence Migration..."
echo "================================================"
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "⚠️  Supabase CLI not found. Please install it or run SQL manually."
    echo ""
    echo "Install Supabase CLI:"
    echo "  npm install -g supabase"
    echo ""
    echo "OR run SQL manually in Supabase Dashboard:"
    echo "  https://app.supabase.com → SQL Editor"
    echo "  File: supabase_sql/add_availability_columns.sql"
    exit 1
fi

echo "✅ Supabase CLI found"
echo ""

# Apply migration
echo "📝 Running SQL migration..."
supabase db push --file supabase_sql/add_availability_columns.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration applied successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your Flutter app"
    echo "2. Login as a mentor"
    echo "3. Test the Availability screen"
    echo "4. Change settings and save"
    echo "5. Logout and login again"
    echo "6. Verify settings are preserved!"
else
    echo ""
    echo "❌ Migration failed. Please run SQL manually."
    echo ""
    echo "File location: supabase_sql/add_availability_columns.sql"
fi
