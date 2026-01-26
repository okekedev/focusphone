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
  LayoutDashboard,
  Battery,
  MapPin,
  UserPlus,
  AlertTriangle,
  ChevronRight,
} from "lucide-react";

const DEV_MODE = process.env.NEXT_PUBLIC_DEV_MODE === "true";

// Design System Colors (matching ParentApp)
const colors = {
  primary: "#6366F1",
  primaryLight: "#818CF8",
  secondary: "#14B8A6",
  accent: "#F59E0B",
  success: "#10B981",
  warning: "#F59E0B",
  error: "#EF4444",
  background: "#F8FAFC",
  surface: "#FFFFFF",
  textPrimary: "#0F172A",
  textSecondary: "#64748B",
  textTertiary: "#94A3B8",
  border: "#E2E8F0",
};

export default function AdminPortal() {
  if (DEV_MODE) {
    return (
      <main className="min-h-screen bg-[#F8FAFC]">
        <AdminDashboard devMode />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#F8FAFC]">
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
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 bg-[#F8FAFC]">
        <div className="absolute top-[-200px] left-[-100px] w-[400px] h-[400px] bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-[-100px] right-[-50px] w-[300px] h-[300px] bg-teal-500/10 rounded-full blur-3xl" />
        <div className="absolute top-[200px] right-[100px] w-[200px] h-[200px] bg-amber-500/5 rounded-full blur-2xl" />
      </div>

      <div className="relative z-10 text-center bg-white p-12 rounded-3xl shadow-xl shadow-black/5 max-w-md border border-slate-100">
        <div className="mb-8">
          {/* Logo */}
          <div className="w-24 h-24 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-3xl flex items-center justify-center mx-auto mb-6 shadow-lg shadow-indigo-500/30">
            <Smartphone className="w-12 h-12 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-slate-900">FocusPhone</h1>
          <p className="text-slate-500 mt-2">Admin Dashboard</p>
        </div>

        {/* Features */}
        <div className="space-y-3 mb-8 text-left">
          <FeatureItem icon={<Users className="w-4 h-4" />} text="Manage all parent accounts" />
          <FeatureItem icon={<Smartphone className="w-4 h-4" />} text="Monitor enrolled devices" />
          <FeatureItem icon={<Shield className="w-4 h-4" />} text="Configure restriction profiles" />
        </div>

        <button
          onClick={handleLogin}
          className="w-full bg-gradient-to-r from-indigo-500 to-indigo-600 text-white px-8 py-4 rounded-xl font-semibold hover:from-indigo-600 hover:to-indigo-700 transition shadow-lg shadow-indigo-500/25 flex items-center justify-center gap-3"
        >
          <svg className="w-5 h-5" viewBox="0 0 21 21" fill="currentColor">
            <rect x="1" y="1" width="9" height="9" />
            <rect x="11" y="1" width="9" height="9" />
            <rect x="1" y="11" width="9" height="9" />
            <rect x="11" y="11" width="9" height="9" />
          </svg>
          Sign in with Microsoft
        </button>

        <p className="text-sm text-slate-400 mt-6">
          Authorized administrators only
        </p>
      </div>
    </div>
  );
}

function FeatureItem({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <div className="flex items-center gap-3 text-slate-600">
      <div className="w-8 h-8 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-500">
        {icon}
      </div>
      <span className="text-sm">{text}</span>
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
    { id: "overview", label: "Overview", icon: <LayoutDashboard className="w-4 h-4" /> },
    { id: "parents", label: "Parents", icon: <Users className="w-4 h-4" /> },
    { id: "devices", label: "Devices", icon: <Smartphone className="w-4 h-4" /> },
    { id: "profiles", label: "Profiles", icon: <Shield className="w-4 h-4" /> },
  ];

  const parentUsers = users.filter(u => u.role !== "admin");

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <Smartphone className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-slate-900">FocusPhone</h1>
              <p className="text-xs text-slate-500">Admin Dashboard</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {/* User info */}
            <div className="flex items-center gap-3 px-4 py-2 bg-slate-50 rounded-xl">
              <div className="w-8 h-8 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-lg flex items-center justify-center text-white text-sm font-semibold">
                {currentUser?.name?.charAt(0) || "A"}
              </div>
              <div className="text-sm">
                <p className="font-medium text-slate-900">{currentUser?.name || "Admin"}</p>
                <p className="text-slate-500 text-xs">{currentUser?.email}</p>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="text-slate-400 hover:text-slate-600 p-2 rounded-lg hover:bg-slate-100 transition"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="max-w-7xl mx-auto px-6">
          <div className="flex gap-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as typeof activeTab)}
                className={`flex items-center gap-2 px-4 py-3 font-medium text-sm transition border-b-2 ${
                  activeTab === tab.id
                    ? "border-indigo-500 text-indigo-600"
                    : "border-transparent text-slate-500 hover:text-slate-700"
                }`}
              >
                {tab.icon}
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </header>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        {loading ? (
          <div className="flex flex-col items-center justify-center py-20">
            <div className="relative">
              <div className="w-16 h-16 border-4 border-indigo-100 rounded-full" />
              <div className="absolute inset-0 w-16 h-16 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            </div>
            <p className="text-slate-500 mt-4">Loading...</p>
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
  const onlineCount = devices.filter(d => {
    if (!d.lastCheckin) return false;
    const lastCheckin = new Date(d.lastCheckin);
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    return lastCheckin > fiveMinutesAgo;
  }).length;

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Dashboard Overview</h2>
        <p className="text-slate-500">Monitor your FocusPhone deployment</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatCard
          title="Total Parents"
          value={users.length}
          icon={<Users className="w-6 h-6" />}
          color="indigo"
          subtitle={`${users.length} registered`}
        />
        <StatCard
          title="Total Devices"
          value={devices.length}
          icon={<Smartphone className="w-6 h-6" />}
          color="teal"
          subtitle={`${onlineCount} online now`}
        />
        <StatCard
          title="Managed"
          value={managedCount}
          icon={<CheckCircle className="w-6 h-6" />}
          color="emerald"
          subtitle="Active policies"
        />
        <StatCard
          title="Profiles"
          value={profiles.length}
          icon={<Shield className="w-6 h-6" />}
          color="purple"
          subtitle="Restriction sets"
        />
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Parents */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm">
          <div className="p-6 border-b border-slate-100">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-slate-900">Recent Parents</h3>
              <span className="text-xs text-slate-400">{users.length} total</span>
            </div>
          </div>
          <div className="p-2">
            {users.length === 0 ? (
              <EmptyState icon={<Users />} message="No parents registered yet" />
            ) : (
              <div className="divide-y divide-slate-50">
                {users.slice(0, 5).map((user) => (
                  <div key={user.id} className="flex items-center justify-between p-4 hover:bg-slate-50 rounded-xl transition">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-xl flex items-center justify-center text-white font-semibold">
                        {user.name?.charAt(0) || "?"}
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">{user.name}</p>
                        <p className="text-sm text-slate-500">{user.email}</p>
                      </div>
                    </div>
                    <span className="text-xs bg-slate-100 text-slate-600 px-2 py-1 rounded-lg capitalize">
                      {user.provider || "N/A"}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Recent Devices */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm">
          <div className="p-6 border-b border-slate-100">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-slate-900">Recent Devices</h3>
              <span className="text-xs text-slate-400">{devices.length} total</span>
            </div>
          </div>
          <div className="p-2">
            {devices.length === 0 ? (
              <EmptyState icon={<Smartphone />} message="No devices enrolled yet" />
            ) : (
              <div className="divide-y divide-slate-50">
                {devices.slice(0, 5).map((device) => (
                  <div key={device.id} className="flex items-center justify-between p-4 hover:bg-slate-50 rounded-xl transition">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-slate-100 rounded-xl flex items-center justify-center">
                        <Smartphone className="w-5 h-5 text-slate-500" />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">{device.name}</p>
                        <p className="text-sm text-slate-500">{device.model}</p>
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
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Parent Accounts</h2>
        <p className="text-slate-500">Manage registered parent users</p>
      </div>

      {users.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-16 text-center">
          <div className="w-20 h-20 bg-indigo-50 rounded-full flex items-center justify-center mx-auto mb-4">
            <Users className="w-10 h-10 text-indigo-500" />
          </div>
          <h3 className="text-lg font-semibold text-slate-900 mb-2">No parents yet</h3>
          <p className="text-slate-500">Parents will appear here when they sign up through the app</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <table className="w-full">
            <thead className="bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Parent</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Provider</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Verified</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Joined</th>
                <th className="px-6 py-4"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-slate-50 transition">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-xl flex items-center justify-center text-white font-semibold">
                        {user.name?.charAt(0) || "?"}
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">{user.name}</p>
                        <p className="text-sm text-slate-500">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-xs bg-slate-100 px-3 py-1 rounded-lg capitalize font-medium text-slate-600">
                      {user.provider || "unknown"}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    {user.phoneVerified ? (
                      <span className="inline-flex items-center gap-1 text-emerald-600">
                        <CheckCircle className="w-4 h-4" />
                        <span className="text-sm">Yes</span>
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-slate-400">
                        <XCircle className="w-4 h-4" />
                        <span className="text-sm">No</span>
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-slate-500 text-sm">
                    {user.createdAt ? new Date(user.createdAt).toLocaleDateString() : "-"}
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleMakeAdmin(user.id)}
                        disabled={promoting === user.id}
                        className="text-indigo-500 hover:text-indigo-700 p-2 rounded-lg hover:bg-indigo-50 transition"
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
                        className="text-red-500 hover:text-red-700 p-2 rounded-lg hover:bg-red-50 transition"
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
      <div>
        <h2 className="text-2xl font-bold text-slate-900">All Devices</h2>
        <p className="text-slate-500">View and manage enrolled devices</p>
      </div>

      {devices.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-16 text-center">
          <div className="w-20 h-20 bg-indigo-50 rounded-full flex items-center justify-center mx-auto mb-4">
            <Smartphone className="w-10 h-10 text-indigo-500" />
          </div>
          <h3 className="text-lg font-semibold text-slate-900 mb-2">No devices enrolled</h3>
          <p className="text-slate-500">Devices will appear here when parents enroll them</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <table className="w-full">
            <thead className="bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Device</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Status</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Battery</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Location</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Profile</th>
                <th className="text-left px-6 py-4 font-medium text-slate-600 text-sm">Last Seen</th>
                <th className="px-6 py-4"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {devices.map((device) => {
                const profile = profiles.find(p => p.id === device.profileId);
                const hasLocation = device.latitude !== null && device.longitude !== null;
                return (
                  <tr key={device.id} className="hover:bg-slate-50 transition">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 bg-gradient-to-br from-slate-100 to-slate-200 rounded-xl flex items-center justify-center">
                          <Smartphone className="w-6 h-6 text-slate-500" />
                        </div>
                        <div>
                          <p className="font-medium text-slate-900">{device.name}</p>
                          <p className="text-sm text-slate-500">{device.model} · iOS {device.osVersion}</p>
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
                            device.batteryLevel > 50 ? "text-emerald-500" :
                            device.batteryLevel > 20 ? "text-amber-500" : "text-red-500"
                          }`} />
                          <span className="text-sm font-medium">{Math.round(device.batteryLevel)}%</span>
                        </div>
                      ) : (
                        <span className="text-slate-400 text-sm">--</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {hasLocation ? (
                        <a
                          href={`https://maps.google.com/?q=${device.latitude},${device.longitude}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-indigo-600 hover:text-indigo-800 text-sm font-medium"
                        >
                          <MapPin className="w-4 h-4" />
                          View
                        </a>
                      ) : (
                        <span className="text-slate-400 text-sm">--</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {profile ? (
                        <span className="text-sm font-medium text-slate-700">{profile.name}</span>
                      ) : (
                        <span className="text-slate-400 text-sm">None</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-slate-500 text-sm">
                      {device.lastCheckin ? new Date(device.lastCheckin).toLocaleString() : "Never"}
                    </td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => handleDelete(device.id)}
                        disabled={deleting === device.id}
                        className="text-red-500 hover:text-red-700 p-2 rounded-lg hover:bg-red-50 transition"
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
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Restriction Profiles</h2>
        <p className="text-slate-500">Pre-configured app restriction sets</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {profiles.map((profile) => (
          <div key={profile.id} className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 hover:shadow-md transition">
            <div className="flex items-start justify-between mb-4">
              <div className="w-14 h-14 bg-gradient-to-br from-purple-500 to-purple-600 rounded-2xl flex items-center justify-center shadow-lg shadow-purple-500/20">
                <Shield className="w-7 h-7 text-white" />
              </div>
              <span className="text-sm text-slate-500 bg-slate-100 px-3 py-1 rounded-lg">
                {profile.deviceCount} devices
              </span>
            </div>
            <h3 className="text-lg font-bold text-slate-900 mb-2">{profile.name}</h3>
            <p className="text-sm text-slate-500 mb-4">{profile.description}</p>
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

function StatCard({ title, value, icon, color, subtitle }: { title: string; value: number; icon: React.ReactNode; color: string; subtitle?: string }) {
  const colorClasses: Record<string, { bg: string; icon: string; shadow: string }> = {
    indigo: { bg: "from-indigo-500 to-indigo-600", icon: "text-indigo-500", shadow: "shadow-indigo-500/20" },
    teal: { bg: "from-teal-500 to-teal-600", icon: "text-teal-500", shadow: "shadow-teal-500/20" },
    emerald: { bg: "from-emerald-500 to-emerald-600", icon: "text-emerald-500", shadow: "shadow-emerald-500/20" },
    purple: { bg: "from-purple-500 to-purple-600", icon: "text-purple-500", shadow: "shadow-purple-500/20" },
  };

  const { bg, shadow } = colorClasses[color] || colorClasses.indigo;

  return (
    <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
      <div className={`w-14 h-14 bg-gradient-to-br ${bg} rounded-2xl flex items-center justify-center mb-4 shadow-lg ${shadow}`}>
        <span className="text-white">{icon}</span>
      </div>
      <p className="text-3xl font-bold text-slate-900">{value}</p>
      <p className="text-slate-900 font-medium">{title}</p>
      {subtitle && <p className="text-sm text-slate-400 mt-1">{subtitle}</p>}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const config: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
    managed: { bg: "bg-emerald-50", text: "text-emerald-700", icon: <CheckCircle className="w-3 h-3" /> },
    enrolled: { bg: "bg-indigo-50", text: "text-indigo-700", icon: <Clock className="w-3 h-3" /> },
    pending: { bg: "bg-amber-50", text: "text-amber-700", icon: <Clock className="w-3 h-3" /> },
    removed: { bg: "bg-slate-100", text: "text-slate-600", icon: <XCircle className="w-3 h-3" /> },
  };

  const { bg, text, icon } = config[status] || config.pending;

  return (
    <span className={`inline-flex items-center gap-1.5 text-xs font-medium px-3 py-1.5 rounded-lg ${bg} ${text}`}>
      {icon}
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}

function AppBadge({ label, active = false }: { label: string; active?: boolean }) {
  return (
    <span className={`text-xs font-medium px-3 py-1.5 rounded-lg ${
      active ? "bg-emerald-50 text-emerald-700" : "bg-slate-100 text-slate-400 line-through"
    }`}>
      {label}
    </span>
  );
}

function EmptyState({ icon, message }: { icon: React.ReactNode; message: string }) {
  return (
    <div className="py-12 text-center">
      <div className="w-12 h-12 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-3 text-slate-400">
        {icon}
      </div>
      <p className="text-slate-500 text-sm">{message}</p>
    </div>
  );
}
