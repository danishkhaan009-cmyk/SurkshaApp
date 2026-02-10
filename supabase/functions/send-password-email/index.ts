// Supabase Edge Function: send-password-email
// Sends a password reset email with the new auto-generated password

import "@supabase/functions-js/edge-runtime.d.ts"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

// CORS headers for browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, password } = await req.json();

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: "email and password are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send email via Resend API
    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "Suraksha <noreply@getsuraksha.online>",
        to: [email],
        subject: "Suraksha - Your New Password",
        html: `
          <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: #f8f9fa; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 24px;">
              <div style="display: inline-block; background: #4B39EF; color: white; padding: 12px 24px; border-radius: 8px; font-size: 22px; font-weight: bold;">
                Suraksha
              </div>
            </div>
            <div style="background: white; padding: 28px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06);">
              <h2 style="color: #333; margin: 0 0 16px 0; font-size: 20px;">Password Reset</h2>
              <p style="color: #555; margin: 0 0 20px 0; line-height: 1.6;">
                Your password has been reset. Here is your new temporary password:
              </p>
              <div style="background: #f0eeff; border: 2px dashed #4B39EF; border-radius: 8px; padding: 16px; text-align: center; margin: 0 0 20px 0;">
                <span style="font-size: 28px; font-weight: bold; letter-spacing: 4px; color: #4B39EF; font-family: monospace;">
                  ${password}
                </span>
              </div>
              <p style="color: #555; margin: 0 0 8px 0; line-height: 1.6;">
                Please log in with this password and consider changing it in your settings.
              </p>
              <p style="color: #999; font-size: 12px; margin: 20px 0 0 0;">
                If you did not request a password reset, please ignore this email or contact support.
              </p>
            </div>
            <p style="color: #aaa; font-size: 11px; text-align: center; margin: 16px 0 0 0;">
              &copy; ${new Date().getFullYear()} Suraksha. All rights reserved.
            </p>
          </div>
        `,
      }),
    });

    const emailData = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error("Resend error:", emailData);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: emailData }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "Email sent successfully" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/send-password-email' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
