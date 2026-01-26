"use client";

import { useEffect, useState } from "react";
import {
  useMsal,
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
} from "@azure/msal-react";
import { loginRequest } from "@/lib/msal";
import { api, Device, Profile, User } from "@/lib/api";
import {
  Smartphone,
  Shield,
  Users,
  QrCode,
  LogOut,
  RefreshCw,
  Trash2,
  CheckCircle,
  XCircle,
  Clock,
  Plus,
  X,
  Building2,
  Battery,
  MapPin,
  UserPlus,
  AlertTriangle,
} from "lucide-react";

const DEV_MODE = process.env.NEXT_PUBLIC_DEV_MODE === "true";

export default function AdminPortal() {
  if (DEV_MODE) {
    return (
      <main>
        <AdminDashboard devMode />
      </main>
    );
  }

  return (
    <main>
      <AuthenticatedTemplate>
        <AdminDashboard />
      </AuthenticatedTemplate>
      <UnauthenticatedTemplate>
        <AdminLoginPage />
      </UnauthenticatedTemplate>
    </main>
  );
}

function AdminLoginPage() {
  const { instance } = useMsal();

  const handleLogin = () => {
    instance.loginPopup(loginRequest);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-800 to-slate-900">
      <div className="text-center bg-white p-12 rounded-2xl shadow-xl max-w-md">
        <div className="mb-8">
          <div className="w-20 h-20 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <Building2 className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900">FocusPhone</h1>
          <p className="text-gray-600 mt-2">Master Admin Portal</p>
        </div>
        <button
          onClick={handleLogin}
          className="bg-slate-800 text-white px-8 py-3 rounded-lg font-medium hover:bg-slate-700 transition flex items-center gap-2 mx-auto"
        >
          <svg className="w-5 h-5" viewBox="0 0 21 21" fill="currentColor">
            <rect x="1" y="1" width="9" height="9" />
            <rect x="11" y="1" width="9" height="9" />
            <rect x="1" y="11" width="9" height="9" />
            <rect x="11" y="11" width="9" height="9" />
          </svg>
          Sign in with Microsoft
        </button>
        <p className="text-sm text-gray-400 mt-6">
          This portal is for system administrators only
        </p>
      </div>
    </div>
  );
}

function AdminDashboard({ devMode = false }: { devMode?: boolean }) {
  const msal = useMsal();
  const { instance, accounts } = devMode ? { instance: null, accounts: [] } : msal;
  const [activeTab, setActiveTab] = useState<"overview" | "parents" | "devices" | "profiles">("overview");
  const [devices, setDevices] = useState<Device[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState<User | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  const getToken = async () => {
    api.setProvider("microsoft-admin");
    if (devMode) {
      api.setToken("dev-token");
      return "dev-token";
    }
    try {
      const tokenResponse = await instance!.acquireTokenSilent({
        scopes: ["User.Read"],
        account: accounts[0],
      });
      api.setToken(tokenResponse.accessToken);
      return tokenResponse.accessToken;
    } catch {
      api.setToken("");
      return "";
    }
  };

  const loadData = async () => {
    setLoading(true);
    try {
      await getToken();
      const [me, devicesData, profilesData, usersData] = await Promise.all([
        api.getMe(),
        api.getDevices(),
        api.getProfiles(),
        api.getUsers(),
      ]);
      setCurrentUser(me.user);
      setDevices(devicesData);
      setProfiles(profilesData);
      setUsers(usersData);
    } catch (error) {
      console.error("Failed to load data:", error);
    }
    setLoading(false);
  };

  const handleLogout = () => {
    if (devMode) {
      window.location.reload();
      return;
    }
    instance?.logoutPopup();
  };

  const tabs = [
    { id: "overview", label: "Overview", icon: <Building2 className="w-4 h-4" /> },
    { id: "parents", label: "Parents", icon: <Users className="w-4 h-4" /> },
    { id: "devices", label: "All Devices", icon: <Smartphone className="w-4 h-4" /> },
    { id: "profiles", label: "Profiles", icon: <Shield className="w-4 h-4" /> },
  ];

  // Filter parent users (non-admin)
  const parentUsers = users.filter(u => u.role !== "admin");

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header */}
      <header className="bg-slate-800 text-white sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-white/10 rounded-lg flex items-center justify-center">
              <Building2 className="w-4 h-4" />
            </div>
            <div>
              <h1 className="text-lg font-bold">FocusPhone Admin</h1>
              <p className="text-xs text-slate-400">Master Control Panel</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-sm text-slate-300">
              {currentUser?.name || currentUser?.email}
            </span>
            <button
              onClick={handleLogout}
              className="text-slate-400 hover:text-white p-2 rounded-lg hover:bg-white/10"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav className="bg-slate-700">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex gap-1 overflow-x-auto">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as typeof activeTab)}
                className={`flex items-center gap-2 px-4 py-3 font-medium whitespace-nowrap transition border-b-2 ${
                  activeTab === tab.id
                    ? "border-white text-white"
                    : "border-transparent text-slate-400 hover:text-white"
                }`}
              >
                {tab.icon}
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 py-6">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <RefreshCw className="w-8 h-8 animate-spin text-slate-600" />
          </div>
        ) : (
          <>
            {activeTab === "overview" && (
              <AdminOverview devices={devices} profiles={profiles} users={parentUsers} />
            )}
            {activeTab === "parents" && (
              <ParentsPanel users={parentUsers} onRefresh={loadData} />
            )}
            {activeTab === "devices" && (
              <AllDevicesPanel devices={devices} profiles={profiles} users={users} onRefresh={loadData} />
            )}
            {activeTab === "profiles" && (
              <ProfilesPanel profiles={profiles} />
            )}
          </>
        )}
      </div>
    </div>
  );
}

function AdminOverview({ devices, profiles, users }: { devices: Device[]; profiles: Profile[]; users: User[] }) {
  const managedCount = devices.filter(d => d.status === "managed").length;

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">System Overview</h2>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatCard title="Total Parents" value={users.length} icon={<Users className="w-6 h-6" />} color="blue" />
        <StatCard title="Total Devices" value={devices.length} icon={<Smartphone className="w-6 h-6" />} color="green" />
        <StatCard title="Managed" value={managedCount} icon={<CheckCircle className="w-6 h-6" />} color="emerald" />
        <StatCard title="Profiles" value={profiles.length} icon={<Shield className="w-6 h-6" />} color="purple" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl border p-6">
          <h3 className="text-lg font-semibold mb-4">Recent Parents</h3>
          {users.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No parents registered yet</p>
          ) : (
            <div className="space-y-3">
              {users.slice(0, 5).map((user) => (
                <div key={user.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div>
                    <p className="font-medium">{user.name}</p>
                    <p className="text-sm text-gray-500">{user.email}</p>
                  </div>
                  <span className="text-xs bg-gray-200 px-2 py-1 rounded">{user.provider || "N/A"}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-white rounded-xl border p-6">
          <h3 className="text-lg font-semibold mb-4">Recent Devices</h3>
          {devices.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No devices enrolled yet</p>
          ) : (
            <div className="space-y-3">
              {devices.slice(0, 5).map((device) => (
                <div key={device.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <Smartphone className="w-5 h-5 text-gray-400" />
                    <div>
                      <p className="font-medium">{device.name}</p>
                      <p className="text-sm text-gray-500">{device.model}</p>
                    </div>
                  </div>
                  <StatusBadge status={device.status} />
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function ParentsPanel({ users, onRefresh }: { users: User[]; onRefresh: () => void }) {
  const [promoting, setPromoting] = useState<string | null>(null);

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this parent?")) return;
    try {
      await api.deleteUser(id);
      onRefresh();
    } catch (error) {
      alert("Failed to delete user");
    }
  };

  const handleMakeAdmin = async (userId: string) => {
    if (!confirm("Are you sure you want to make this user an admin?")) return;
    setPromoting(userId);
    try {
      await api.makeAdmin(userId);
      onRefresh();
    } catch (error) {
      alert("Failed to promote user");
    }
    setPromoting(null);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">Parent Accounts</h2>

      {users.length === 0 ? (
        <div className="bg-white rounded-xl border p-12 text-center">
          <Users className="w-16 h-16 mx-auto mb-4 text-gray-300" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No parents yet</h3>
          <p className="text-gray-500">Parents will appear here when they sign up</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Parent</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Provider</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Phone Verified</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Joined</th>
                <th className="px-6 py-4"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div>
                      <p className="font-medium text-gray-900">{user.name}</p>
                      <p className="text-sm text-gray-500">{user.email}</p>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-xs bg-gray-100 px-2 py-1 rounded capitalize">
                      {user.provider || "unknown"}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    {user.phoneVerified ? (
                      <CheckCircle className="w-5 h-5 text-green-500" />
                    ) : (
                      <XCircle className="w-5 h-5 text-gray-300" />
                    )}
                  </td>
                  <td className="px-6 py-4 text-gray-500 text-sm">
                    {user.createdAt ? new Date(user.createdAt).toLocaleDateString() : "-"}
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => handleMakeAdmin(user.id)}
                        disabled={promoting === user.id}
                        className="text-indigo-500 hover:text-indigo-700 p-2 rounded-lg hover:bg-indigo-50"
                        title="Make Admin"
                      >
                        {promoting === user.id ? (
                          <RefreshCw className="w-4 h-4 animate-spin" />
                        ) : (
                          <UserPlus className="w-4 h-4" />
                        )}
                      </button>
                      <button
                        onClick={() => handleDelete(user.id)}
                        className="text-red-500 hover:text-red-700 p-2 rounded-lg hover:bg-red-50"
                        title="Delete User"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function AllDevicesPanel({ devices, profiles, users, onRefresh }: { devices: Device[]; profiles: Profile[]; users: User[]; onRefresh: () => void }) {
  const [deleting, setDeleting] = useState<string | null>(null);

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this device?")) return;
    setDeleting(id);
    try {
      await api.deleteDevice(id);
      onRefresh();
    } catch (error) {
      alert("Failed to delete device");
    }
    setDeleting(null);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">All Devices</h2>

      {devices.length === 0 ? (
        <div className="bg-white rounded-xl border p-12 text-center">
          <Smartphone className="w-16 h-16 mx-auto mb-4 text-gray-300" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No devices enrolled</h3>
          <p className="text-gray-500">Devices will appear here when parents enroll them</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Device</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Status</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Battery</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Location</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Profile</th>
                <th className="text-left px-6 py-4 font-medium text-gray-600">Last Check-in</th>
                <th className="px-6 py-4"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {devices.map((device) => {
                const profile = profiles.find(p => p.id === device.profileId);
                const hasLocation = device.latitude !== null && device.longitude !== null;
                return (
                  <tr key={device.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                          <Smartphone className="w-5 h-5 text-gray-500" />
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">{device.name}</p>
                          <p className="text-sm text-gray-500">{device.model} - iOS {device.osVersion}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <StatusBadge status={device.status} />
                    </td>
                    <td className="px-6 py-4">
                      {device.batteryLevel !== null ? (
                        <div className="flex items-center gap-2">
                          <Battery className={`w-4 h-4 ${
                            device.batteryLevel > 50 ? "text-green-500" :
                            device.batteryLevel > 20 ? "text-yellow-500" : "text-red-500"
                          }`} />
                          <span className="text-sm">{Math.round(device.batteryLevel)}%</span>
                        </div>
                      ) : (
                        <span className="text-gray-400 text-sm">--</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {hasLocation ? (
                        <a
                          href={`https://maps.google.com/?q=${device.latitude},${device.longitude}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1 text-blue-600 hover:text-blue-800 text-sm"
                        >
                          <MapPin className="w-4 h-4" />
                          View
                        </a>
                      ) : (
                        <span className="text-gray-400 text-sm">--</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-600">
                      {profile?.name || "None"}
                    </td>
                    <td className="px-6 py-4 text-gray-500 text-sm">
                      {device.lastCheckin ? new Date(device.lastCheckin).toLocaleString() : "Never"}
                    </td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => handleDelete(device.id)}
                        disabled={deleting === device.id}
                        className="text-red-500 hover:text-red-700 p-2 rounded-lg hover:bg-red-50"
                      >
                        {deleting === device.id ? (
                          <RefreshCw className="w-4 h-4 animate-spin" />
                        ) : (
                          <Trash2 className="w-4 h-4" />
                        )}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function ProfilesPanel({ profiles }: { profiles: Profile[] }) {
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">Restriction Profiles</h2>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {profiles.map((profile) => (
          <div key={profile.id} className="bg-white rounded-xl border p-6">
            <div className="flex items-start justify-between mb-4">
              <div className="w-12 h-12 bg-purple-50 rounded-lg flex items-center justify-center">
                <Shield className="w-6 h-6 text-purple-600" />
              </div>
              <span className="text-sm text-gray-500">{profile.deviceCount} devices</span>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">{profile.name}</h3>
            <p className="text-sm text-gray-600 mb-4">{profile.description}</p>
            <div className="flex flex-wrap gap-2">
              {profile.allowPhone && <AppBadge label="Phone" active />}
              {profile.allowMessages && <AppBadge label="Messages" active />}
              {profile.allowContacts && <AppBadge label="Contacts" active />}
              {profile.allowCamera && <AppBadge label="Camera" active />}
              {profile.allowPhotos && <AppBadge label="Photos" active />}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, color }: { title: string; value: number; icon: React.ReactNode; color: string }) {
  const colors: Record<string, string> = {
    blue: "bg-blue-50 text-blue-600",
    green: "bg-green-50 text-green-600",
    emerald: "bg-emerald-50 text-emerald-600",
    purple: "bg-purple-50 text-purple-600",
  };

  return (
    <div className="bg-white rounded-xl border p-6">
      <div className={`w-12 h-12 rounded-lg ${colors[color]} flex items-center justify-center mb-4`}>
        {icon}
      </div>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
      <p className="text-gray-500">{title}</p>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const config: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
    managed: { bg: "bg-green-100", text: "text-green-800", icon: <CheckCircle className="w-3 h-3" /> },
    enrolled: { bg: "bg-blue-100", text: "text-blue-800", icon: <Clock className="w-3 h-3" /> },
    pending: { bg: "bg-yellow-100", text: "text-yellow-800", icon: <Clock className="w-3 h-3" /> },
    removed: { bg: "bg-gray-100", text: "text-gray-800", icon: <XCircle className="w-3 h-3" /> },
  };

  const { bg, text, icon } = config[status] || config.pending;

  return (
    <span className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded ${bg} ${text}`}>
      {icon}
      {status}
    </span>
  );
}

function AppBadge({ label, active = false }: { label: string; active?: boolean }) {
  return (
    <span className={`text-xs px-2 py-1 rounded ${
      active ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-400 line-through"
    }`}>
      {label}
    </span>
  );
}
