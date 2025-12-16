import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import { validatePixels, validateTitle, validateDeviceId } from '../shared/validation';
import type { PixelArt, ApiResponse } from '../shared/types';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const PIXEL_ARTS_TABLE = process.env.PIXEL_ARTS_TABLE!;

interface ExchangeRequest {
  pixels: number[];
  title?: string;
  gridSize?: number;
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Exchange request received:', JSON.stringify(event, null, 2));

  try {
    // デバイスID取得
    const deviceId = event.headers['X-Device-ID'] || event.headers['x-device-id'];
    const deviceIdValidation = validateDeviceId(deviceId);
    if (!deviceIdValidation.valid) {
      return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
    }

    // リクエストボディのパース
    if (!event.body) {
      return errorResponse(400, 'MISSING_BODY', 'リクエストボディが必要です');
    }

    const body: ExchangeRequest = JSON.parse(event.body);
    const gridSize = body.gridSize || 4;

    // ピクセルデータバリデーション
    const pixelsValidation = validatePixels(body.pixels, gridSize);
    if (!pixelsValidation.valid) {
      return errorResponse(400, 'INVALID_PIXELS', pixelsValidation.error!);
    }

    // タイトルバリデーション
    const titleValidation = validateTitle(body.title);
    if (!titleValidation.valid) {
      return errorResponse(400, 'INVALID_TITLE', titleValidation.error!);
    }

    const now = new Date().toISOString();
    const myArtId = randomUUID();

    // 自分のドット絵を保存
    const myArt: PixelArt = {
      id: myArtId,
      userId: deviceId!,
      pixels: body.pixels,
      title: titleValidation.sanitized,
      gridSize,
      status: 'pending',
      source: 'local',
      createdAt: now,
    };

    await docClient.send(new PutCommand({
      TableName: PIXEL_ARTS_TABLE,
      Item: myArt,
    }));

    // 交換相手を探す（ランダムマッチング）
    const matchResult = await findMatchingArt(deviceId!, myArtId);

    if (matchResult) {
      // マッチング成功: 両者のステータスを更新
      await Promise.all([
        // 自分のドット絵を交換済みに
        docClient.send(new UpdateCommand({
          TableName: PIXEL_ARTS_TABLE,
          Key: { id: myArtId, createdAt: now },
          UpdateExpression: 'SET #status = :status, exchangedAt = :exchangedAt',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: {
            ':status': 'exchanged',
            ':exchangedAt': now,
          },
        })),
        // 相手のドット絵を交換済みに
        docClient.send(new UpdateCommand({
          TableName: PIXEL_ARTS_TABLE,
          Key: { id: matchResult.id, createdAt: matchResult.createdAt },
          UpdateExpression: 'SET #status = :status, exchangedAt = :exchangedAt',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: {
            ':status': 'exchanged',
            ':exchangedAt': now,
          },
        })),
      ]);

      // 受け取ったドット絵を自分のアルバムに追加
      const receivedArt: PixelArt = {
        id: randomUUID(),
        userId: deviceId!,
        pixels: matchResult.pixels,
        title: matchResult.title,
        gridSize: matchResult.gridSize,
        status: 'received',
        source: 'server',
        createdAt: now,
        receivedFromUserId: matchResult.userId,
      };

      await docClient.send(new PutCommand({
        TableName: PIXEL_ARTS_TABLE,
        Item: receivedArt,
      }));

      // 相手にも自分のドット絵を追加
      const sentArt: PixelArt = {
        id: randomUUID(),
        userId: matchResult.userId,
        pixels: body.pixels,
        title: titleValidation.sanitized,
        gridSize,
        status: 'received',
        source: 'server',
        createdAt: now,
        receivedFromUserId: deviceId,
      };

      await docClient.send(new PutCommand({
        TableName: PIXEL_ARTS_TABLE,
        Item: sentArt,
      }));

      const response: ApiResponse<{ received: PixelArt; sent: PixelArt }> = {
        success: true,
        data: {
          received: receivedArt,
          sent: myArt,
        },
      };

      return successResponse(response);
    } else {
      // マッチング待ち
      const response: ApiResponse<{ status: string; artId: string }> = {
        success: true,
        data: {
          status: 'pending',
          artId: myArtId,
        },
      };

      return successResponse(response);
    }
  } catch (error) {
    console.error('Exchange error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', '交換処理中にエラーが発生しました');
  }
}

async function findMatchingArt(excludeUserId: string, excludeArtId: string): Promise<PixelArt | null> {
  // ペンディング状態のドット絵を検索（自分以外）
  const result = await docClient.send(new QueryCommand({
    TableName: PIXEL_ARTS_TABLE,
    IndexName: 'exchange-index',
    KeyConditionExpression: '#status = :status',
    FilterExpression: 'userId <> :userId AND id <> :artId',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':status': 'pending',
      ':userId': excludeUserId,
      ':artId': excludeArtId,
    },
    Limit: 10, // 最大10件取得してランダムに選ぶ
  }));

  if (!result.Items || result.Items.length === 0) {
    return null;
  }

  // ランダムに1件選択
  const randomIndex = Math.floor(Math.random() * result.Items.length);
  return result.Items[randomIndex] as PixelArt;
}

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Device-ID, Authorization, X-Timestamp, X-Nonce, X-Signature, X-Request-Time',
};

function successResponse(body: ApiResponse): APIGatewayProxyResult {
  return {
    statusCode: 200,
    headers: CORS_HEADERS,
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
    headers: CORS_HEADERS,
    body: JSON.stringify(body),
  };
}
