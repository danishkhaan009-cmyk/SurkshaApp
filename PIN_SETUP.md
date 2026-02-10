# PIN Change Feature Setup

## Database Migration Required

To enable the PIN change feature, you need to add a `pin` column to the `profiles` table in Supabase.

### Steps:

1. **Go to your Supabase Dashboard:**
   - Navigate to: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy

2. **Open SQL Editor:**
   - Click on **SQL Editor** in the left sidebar
   - Click **New query**

3. **Run the Migration:**
   - Copy and paste the following SQL:

```sql
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS pin TEXT;

COMMENT ON COLUMN public.profiles.pin IS '4-digit security PIN for app access';
```

4. **Execute the Query:**
   - Click **Run** or press `Ctrl+Enter`
   - You should see "Success. No rows returned"

5. **Verify:**
   - Go to **Table Editor** → **profiles**
   - You should now see the `pin` column in the table

## Using the PIN Change Feature

Once the database is updated:

1. **Navigate to Settings:**
   - Go to the Settings screen in your app
   - Look for "Change PIN" option under the Account section

2. **Change Your PIN:**
   - Click on "Change PIN"
   - Enter your current PIN (leave blank if you haven't set one yet)
   - Enter your new 4-digit PIN
   - Confirm your new PIN
   - Click "Update PIN"

3. **PIN Validation:**
   - PIN must be exactly 4 digits
   - New PIN must match the confirmation
   - New PIN must be different from current PIN

## Features

✅ Secure 4-digit PIN storage in Supabase
✅ Current PIN verification before update
✅ PIN confirmation to prevent typos
✅ Input validation (4 digits only)
✅ Success/error feedback with SnackBars
✅ Loading state during update
✅ Clean Material Design dialog

## Security Notes

- PINs are stored in plain text in the `profiles` table
- For production, consider hashing PINs before storage
- Only the authenticated user can update their own PIN (RLS enabled)
- Current PIN verification prevents unauthorized changes
