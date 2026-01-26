"use client";

import { MsalProvider } from "@azure/msal-react";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { msalInstance } from "@/lib/msal";
import "./globals.css";

const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || "";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50 min-h-screen">
        <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
          <MsalProvider instance={msalInstance}>{children}</MsalProvider>
        </GoogleOAuthProvider>
      </body>
    </html>
  );
}
