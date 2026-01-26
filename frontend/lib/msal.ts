import { Configuration, PublicClientApplication } from "@azure/msal-browser";

// Parent Portal MSAL configuration (multi-tenant + personal accounts)
export const msalConfig: Configuration = {
  auth: {
    clientId: process.env.NEXT_PUBLIC_AZURE_CLIENT_ID || "",
    authority: "https://login.microsoftonline.com/common", // Multi-tenant
    redirectUri: typeof window !== "undefined" ? window.location.origin : "",
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

// Admin Portal MSAL configuration (single-tenant, your org only)
export const adminMsalConfig: Configuration = {
  auth: {
    clientId: process.env.NEXT_PUBLIC_ADMIN_AZURE_CLIENT_ID || "",
    authority: `https://login.microsoftonline.com/${process.env.NEXT_PUBLIC_ADMIN_AZURE_TENANT_ID}`,
    redirectUri: typeof window !== "undefined" ? window.location.origin : "",
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

// Scopes for the access token
export const loginRequest = {
  scopes: ["User.Read", "openid", "profile", "email"],
};

// MSAL instances
export const msalInstance = new PublicClientApplication(msalConfig);
export const adminMsalInstance = new PublicClientApplication(adminMsalConfig);
