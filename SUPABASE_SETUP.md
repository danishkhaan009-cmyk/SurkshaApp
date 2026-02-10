# Supabase Setup Guide for SurakshaApp

This guide will walk you through setting up your Supabase database and enabling authentication for the SurakshaApp.

## Prerequisites

- Supabase account (already configured in your project)
- Project URL: `https://myxdypywnifdsaorlhsy.supabase.co`
- Anon Key: Already configured in `lib/main.dart`

## Step 1: Set Up Authentication

1. **Go to your Supabase Dashboard:**
   - Navigate to: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy

2. **Configure Authentication Settings:**
   - Go to **Authentication** → **Settings**
   - Under **Email Auth**, ensure the following are enabled:
     - ✅ Enable email signup
     - ✅ Enable email confirmations (recommended for production)
   - Set **Site URL** to your app's domain (or `http://localhost:3000` for testing)
   - Configure **Redirect URLs** if needed

3. **Email Templates (Optional but Recommended):**
   - Go to **Authentication** → **Email Templates**
   - Customize the verification email, password reset email, etc.

## Step 2: Create Database Tables

1. **Open SQL Editor:**
   - Go to **SQL Editor** in your Supabase dashboard
   - Click **New query**

2. **Run the Setup Script:**
   - Copy the contents of `supabase_setup.sql` file
   - Paste into the SQL Editor
   - Click **Run** or press `Ctrl+Enter`

This will create the following tables:
- `profiles` - User profiles (parent/child roles)
- `devices` - Child devices being monitored
- `alerts` - Monitoring alerts
- `screen_time` - Daily screen time tracking
- `locations` - Location history
- `subscriptions` - User subscription plans

## Step 3: Verify Setup

1. **Check Tables:**
   - Go to **Table Editor** in Supabase dashboard
   - You should see all the tables listed above

2. **Test Authentication:**
   - Run your Flutter app: `flutter run`
   - Try creating a new account on the Signup screen
   - Check **Authentication** → **Users** in Supabase to see the new user

3. **Verify Profile Creation:**
   - Go to **Table Editor** → **profiles**
   - Your new user should automatically have a profile entry

## Database Schema Overview

### Profiles Table
Stores user information and role (parent/child).
- `id` - References auth.users
- `email` - User email
- `full_name` - User's full name
- `role` - 'parent' or 'child'

### Devices Table
Tracks child devices linked to parent accounts.
- `id` - Unique device ID
- `user_id` - Parent user ID
- `device_name` - Name of the device
- `device_model` - Device model
- `is_active` - Device status

### Alerts Table
Stores monitoring alerts for parents.
- `id` - Alert ID
- `device_id` - Related device
- `alert_type` - Type of alert
- `severity` - low/medium/high
- `is_read` - Read status

### Screen Time Table
Tracks daily screen time usage.
- `device_id` - Related device
- `date` - Date of usage
- `total_minutes` - Total screen time
- `app_usage` - JSON data of per-app usage

### Locations Table
Stores location history.
- `device_id` - Related device
- `latitude` - GPS latitude
- `longitude` - GPS longitude
- `address` - Resolved address

### Subscriptions Table
Manages user subscription plans.
- `user_id` - User ID
- `plan_name` - free/basic/premium
- `status` - active/cancelled/expired
- `expires_at` - Expiry date

## Authentication Flow

### Sign Up Process:
1. User enters email and password
2. Supabase creates auth user
3. Trigger automatically creates profile entry
4. Confirmation email sent (if enabled)
5. User redirected to login screen

### Login Process:
1. User enters email and password
2. Supabase validates credentials
3. Session token generated
4. User redirected to select mode screen

## Row Level Security (RLS)

All tables have RLS enabled. Users can only:
- View and update their own profile
- Manage their own devices
- View alerts from their devices
- Add/view screen time for their devices
- Add/view locations for their devices
- Manage their own subscriptions

## Testing Your Setup

### Test Signup:
1. Run the app
2. Navigate to Signup screen
3. Enter a valid email and password
4. Check for success message
5. Verify user in Supabase dashboard

### Test Login:
1. Navigate to Login screen
2. Enter the credentials you just created
3. Should successfully login and navigate to select mode

### Common Issues:

**"Invalid login credentials"**
- Check if email confirmation is required
- Verify the email in Supabase dashboard

**"Email not confirmed"**
- Check your email for confirmation link
- Or disable email confirmation in Auth settings

**Database errors**
- Ensure all SQL commands ran successfully
- Check RLS policies are properly set up

## Next Steps

1. ✅ Authentication is now working
2. ✅ Database schema is set up
3. 🔲 Implement device pairing functionality
4. 🔲 Add screen time tracking
5. 🔲 Implement location tracking
6. 🔲 Create alert system
7. 🔲 Build parent dashboard

## Environment Variables

Your Supabase configuration is already set in `lib/main.dart`:
```dart
await Supabase.initialize(
  url: 'https://myxdypywnifdsaorlhsy.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
);
```

## Security Best Practices

1. **Never commit your Supabase keys to public repositories**
2. **Enable email confirmation for production**
3. **Set up proper redirect URLs**
4. **Review and test RLS policies**
5. **Enable 2FA for Supabase dashboard access**
6. **Regularly backup your database**

## Support

If you encounter any issues:
1. Check Supabase logs: **Logs** section in dashboard
2. Review auth errors: **Authentication** → **Users** → Click on user
3. Test queries: Use **SQL Editor** to test queries manually

## Useful Supabase Dashboard Links

- Authentication: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy/auth/users
- Database: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy/editor
- SQL Editor: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy/sql
- Logs: https://supabase.com/dashboard/project/myxdypywnifdsaorlhsy/logs

---

**Your authentication is now fully functional!** 🎉

Test it by running the app and creating a new account.
