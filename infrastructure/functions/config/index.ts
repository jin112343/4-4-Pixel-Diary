import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  BatchGetCommand,
} from '@aws-sdk/lib-dynamodb';
import type { AppVersionConfig, MaintenanceConfig, ApiResponse } from '../shared/types.js';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const APP_CONFIG_TABLE = process.env.APP_CONFIG_TABLE!;

interface AppConfigResponse {
  version: {
    minVersion: string;
    latestVersion: string;
    forceUpdate: boolean;
    storeUrl: {
      ios: string;
      android: string;
    };
  };
  maintenance: {
    enabled: boolean;
    message: string;
    estimatedEndTime?: string;
  };
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Config request received:', JSON.stringify(event, null, 2));

  try {
    // クライアントのバージョン情報を取得（オプション）
    const clientVersion = event.headers['X-App-Version'] || event.headers['x-app-version'];
    const platform = event.headers['X-Platform'] || event.headers['x-platform']; // ios or android

    // 設定を取得
    const result = await docClient.send(new BatchGetCommand({
      RequestItems: {
        [APP_CONFIG_TABLE]: {
          Keys: [
            { configType: 'app_version' },
            { configType: 'maintenance' },
          ],
        },
      },
    }));

    const items = result.Responses?.[APP_CONFIG_TABLE] || [];

    // デフォルト値
    let versionConfig: AppVersionConfig = {
      configType: 'app_version',
      minVersion: '1.0.0',
      latestVersion: '1.0.0',
      forceUpdate: false,
      storeUrl: {
        ios: '',
        android: '',
      },
      updatedAt: new Date().toISOString(),
    };

    let maintenanceConfig: MaintenanceConfig = {
      configType: 'maintenance',
      enabled: false,
      message: '',
      updatedAt: new Date().toISOString(),
    };

    // 取得した設定をマージ
    for (const item of items) {
      if (item.configType === 'app_version') {
        versionConfig = item as AppVersionConfig;
      } else if (item.configType === 'maintenance') {
        maintenanceConfig = item as MaintenanceConfig;
      }
    }

    // 強制アップデートが必要かチェック
    let requiresUpdate = false;
    if (clientVersion && versionConfig.forceUpdate) {
      requiresUpdate = compareVersions(clientVersion, versionConfig.minVersion) < 0;
    }

    const responseData: AppConfigResponse = {
      version: {
        minVersion: versionConfig.minVersion,
        latestVersion: versionConfig.latestVersion,
        forceUpdate: requiresUpdate,
        storeUrl: versionConfig.storeUrl,
      },
      maintenance: {
        enabled: maintenanceConfig.enabled,
        message: maintenanceConfig.message,
        estimatedEndTime: maintenanceConfig.estimatedEndTime,
      },
    };

    const response: ApiResponse<AppConfigResponse> = {
      success: true,
      data: responseData,
    };

    // メンテナンス中の場合は503を返す（オプション）
    if (maintenanceConfig.enabled) {
      return {
        statusCode: 503,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Retry-After': '3600', // 1時間後にリトライを推奨
        },
        body: JSON.stringify(response),
      };
    }

    // 強制アップデートが必要な場合は426を返す
    if (requiresUpdate) {
      return {
        statusCode: 426,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(response),
      };
    }

    return successResponse(response);
  } catch (error) {
    console.error('Config error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', '設定の取得中にエラーが発生しました');
  }
}

// バージョン比較関数
// v1 < v2 なら負数、v1 > v2 なら正数、等しいなら0
function compareVersions(v1: string, v2: string): number {
  const parts1 = v1.split('.').map(Number);
  const parts2 = v2.split('.').map(Number);

  const maxLength = Math.max(parts1.length, parts2.length);

  for (let i = 0; i < maxLength; i++) {
    const num1 = parts1[i] || 0;
    const num2 = parts2[i] || 0;

    if (num1 < num2) return -1;
    if (num1 > num2) return 1;
  }

  return 0;
}

function successResponse(body: ApiResponse): APIGatewayProxyResult {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'max-age=60', // 1分キャッシュ
    },
    body: JSON.stringify(body),
  };
}

function errorResponse(statusCode: number, code: string, message: string): APIGatewayProxyResult {
  const body: ApiResponse = {
    success: false,
    error: { code, message },
  };

  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}
