const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api";

export interface Device {
  id: string;
  udid: string;
  name: string;
  model: string;
  osVersion: string;
  status: string;
  profileId: string | null;
  lastCheckin: string | null;
  batteryLevel: number | null;
  latitude: number | null;
  longitude: number | null;
  locationUpdatedAt: string | null;
}

export interface Profile {
  id: string;
  name: string;
  description: string;
  allowPhone: boolean;
  allowMessages: boolean;
  allowContacts: boolean;
  allowCamera: boolean;
  allowPhotos: boolean;
  deviceCount: number;
}

export interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  provider?: string;
  phoneVerified?: boolean;
  createdAt: string | null;
}

export interface EnrollmentToken {
  token: string;
  expiresAt: string;
  enrollmentURL: string;
  qrCodeURL: string;
}

class APIClient {
  private token: string | null = null;
  private provider: string = "microsoft";

  setToken(token: string) {
    this.token = token;
  }

  setProvider(provider: string) {
    this.provider = provider;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    };

    if (this.token) {
      (headers as Record<string, string>)["Authorization"] = `Bearer ${this.token}`;
      (headers as Record<string, string>)["X-Auth-Provider"] = this.provider;
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.detail || `Request failed: ${response.status}`);
    }

    return response.json();
  }

  // Auth
  async getMe(): Promise<{ user: User }> {
    return this.request("/auth/me");
  }

  // Devices
  async getDevices(): Promise<Device[]> {
    return this.request("/devices");
  }

  async getDevice(id: string): Promise<Device> {
    return this.request(`/devices/${id}`);
  }

  async unenrollDevice(id: string): Promise<void> {
    return this.request(`/devices/${id}/unenroll`, { method: "POST" });
  }

  async deleteDevice(id: string): Promise<void> {
    return this.request(`/devices/${id}`, { method: "DELETE" });
  }

  // Profiles
  async getProfiles(): Promise<Profile[]> {
    return this.request("/profiles");
  }

  async createProfile(profile: Omit<Profile, "id" | "deviceCount">): Promise<Profile> {
    return this.request("/profiles", {
      method: "POST",
      body: JSON.stringify(profile),
    });
  }

  async assignProfile(profileId: string, deviceId: string): Promise<void> {
    return this.request(`/profiles/${profileId}/assign`, {
      method: "POST",
      body: JSON.stringify({ deviceId }),
    });
  }

  async deleteProfile(id: string): Promise<void> {
    return this.request(`/profiles/${id}`, { method: "DELETE" });
  }

  // Enrollment
  async createEnrollmentToken(): Promise<EnrollmentToken> {
    return this.request("/enrollment/token", { method: "POST" });
  }

  // Users
  async getUsers(): Promise<User[]> {
    return this.request("/users");
  }

  async deleteUser(id: string): Promise<void> {
    return this.request(`/users/${id}`, { method: "DELETE" });
  }

  async makeAdmin(userId: string): Promise<void> {
    return this.request(`/auth/make-admin/${userId}`, { method: "POST" });
  }
}

export const api = new APIClient();
