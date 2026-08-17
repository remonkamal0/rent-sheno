-- SMS SERVICES DATABASE ROLE EXPANSION MIGRATION

-- Add role column to profiles table if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'tenant' CHECK (role IN ('tenant', 'manager'));

-- Update existing profiles (optional fallback check)
UPDATE profiles SET role = 'tenant' WHERE role IS NULL;
