-- SMS SERVICES DATABASE ADD RECEIPT URL TO PAYMENTS MIGRATION

-- Add receipt_url column to payments table
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS receipt_url TEXT;
