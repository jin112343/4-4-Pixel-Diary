// 共通型定義

export interface PixelArt {
  id: string;
  userId: string;
  pixels: number[];  // RGB値の配列 (16個または25個)
  title: string;     // 最大5文字
  gridSize: number;  // 4 or 5
  status: 'pending' | 'exchanged' | 'received';
  source: 'local' | 'server' | 'bluetooth';
  createdAt: string;
  exchangedAt?: string;
  receivedFromUserId?: string;
}

export interface Post {
  id: string;
  userId: string;
  pixelArtId: string;
  pixels: number[];
  title: string;
  gridSize: number;
  nickname?: string;
  likeCount: number;
  commentCount: number;
  status: 'active' | 'hidden' | 'deleted';
  createdAt: string;
  updatedAt: string;
}

export interface Comment {
  id: string;
  postId: string;
  userId: string;
  content: string;    // 最大50文字
  nickname?: string;
  status: 'active' | 'deleted';
  createdAt: string;
}

export interface User {
  deviceId: string;
  nickname?: string;  // 最大5文字
  createdAt: string;
  lastActiveAt: string;
  settings: UserSettings;
}

export interface UserSettings {
  notificationsEnabled: boolean;
  bluetoothAutoMode: boolean;
  themeMode: 'light' | 'dark' | 'system';
}

export interface AppVersionConfig {
  configType: 'app_version';
  minVersion: string;
  latestVersion: string;
  forceUpdate: boolean;
  storeUrl: {
    ios: string;
    android: string;
  };
  updatedAt: string;
}

export interface MaintenanceConfig {
  configType: 'maintenance';
  enabled: boolean;
  message: string;
  estimatedEndTime?: string;
  updatedAt: string;
}

export type AppConfig = AppVersionConfig | MaintenanceConfig;

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
  pagination?: {
    nextToken?: string;
    hasMore: boolean;
  };
}

export interface ModerationResult {
  isApproved: boolean;
  flags: string[];
  sentiment?: {
    sentiment: string;
    scores: Record<string, number>;
  };
}
