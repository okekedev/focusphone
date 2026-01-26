"use client";

import { MsalProvider } from "@azure/msal-react";
import { adminMsalInstance } from "@/lib/msal";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <MsalProvider instance={adminMsalInstance}>
      {children}
    </MsalProvider>
  );
}
