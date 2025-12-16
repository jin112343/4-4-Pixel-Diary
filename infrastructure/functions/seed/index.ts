import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, BatchWriteCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import type { PixelArt, Post, ApiResponse } from '../shared/types';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const PIXEL_ARTS_TABLE = process.env.PIXEL_ARTS_TABLE!;
const POSTS_TABLE = process.env.POSTS_TABLE!;

// サンプルのドット絵パターン（4x4 = 16ピクセル、各ピクセルはRGB値）
const SAMPLE_PIXEL_PATTERNS = [
  // ハート
  [0xFFFFFF, 0xFF5555, 0xFF5555, 0xFFFFFF, 0xFF5555, 0xFF0000, 0xFF0000, 0xFF5555, 0xFF5555, 0xFF0000, 0xFF0000, 0xFF5555, 0xFFFFFF, 0xFF5555, 0xFF5555, 0xFFFFFF],
  // 星
  [0x000033, 0x000033, 0xFFFF00, 0x000033, 0x000033, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0x000033, 0xFFFF00, 0xFFFF00, 0x000033],
  // 太陽
  [0x87CEEB, 0xFFD700, 0xFFD700, 0x87CEEB, 0xFFD700, 0xFFA500, 0xFFA500, 0xFFD700, 0xFFD700, 0xFFA500, 0xFFA500, 0xFFD700, 0x87CEEB, 0xFFD700, 0xFFD700, 0x87CEEB],
  // 月
  [0x191970, 0x191970, 0xF0E68C, 0x191970, 0x191970, 0xF0E68C, 0xFFFFE0, 0x191970, 0x191970, 0xF0E68C, 0xF0E68C, 0x191970, 0x191970, 0x191970, 0xF0E68C, 0x191970],
  // 花
  [0x90EE90, 0xFF69B4, 0xFF69B4, 0x90EE90, 0xFF69B4, 0xFFFF00, 0xFFFF00, 0xFF69B4, 0xFF69B4, 0xFFFF00, 0xFFFF00, 0xFF69B4, 0x90EE90, 0xFF69B4, 0xFF69B4, 0x90EE90],
  // 虹
  [0xFF0000, 0xFF7F00, 0xFFFF00, 0x00FF00, 0xFF0000, 0xFF7F00, 0xFFFF00, 0x00FF00, 0x0000FF, 0x4B0082, 0x8F00FF, 0xFFFFFF, 0x0000FF, 0x4B0082, 0x8F00FF, 0xFFFFFF],
  // 雲
  [0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0x87CEEB],
  // りんご
  [0xFFFFFF, 0x228B22, 0x228B22, 0xFFFFFF, 0xFFFFFF, 0xFF0000, 0xFF0000, 0xFFFFFF, 0xFF0000, 0xFF0000, 0xFF0000, 0xFF0000, 0xFFFFFF, 0xFF0000, 0xFF0000, 0xFFFFFF],
  // スマイル
  [0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0x000000, 0x000000, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0xFFFF00, 0x000000, 0x000000, 0xFFFF00],
  // 家
  [0x87CEEB, 0x8B4513, 0x8B4513, 0x87CEEB, 0x8B4513, 0xDEB887, 0xDEB887, 0x8B4513, 0xDEB887, 0xDEB887, 0x8B4513, 0xDEB887, 0xDEB887, 0xDEB887, 0xDEB887, 0xDEB887],
  // 木
  [0x87CEEB, 0x228B22, 0x228B22, 0x87CEEB, 0x228B22, 0x228B22, 0x228B22, 0x228B22, 0x87CEEB, 0x8B4513, 0x8B4513, 0x87CEEB, 0x87CEEB, 0x8B4513, 0x8B4513, 0x87CEEB],
  // 波
  [0x87CEEB, 0x87CEEB, 0x87CEEB, 0x87CEEB, 0x1E90FF, 0x00BFFF, 0x00BFFF, 0x1E90FF, 0x00BFFF, 0x1E90FF, 0x1E90FF, 0x00BFFF, 0x0000CD, 0x0000CD, 0x0000CD, 0x0000CD],
  // 猫
  [0xFFA500, 0xFFFFFF, 0xFFFFFF, 0xFFA500, 0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, 0xFFFFFF, 0xFF69B4, 0xFF69B4, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
  // 犬
  [0x8B4513, 0x8B4513, 0x8B4513, 0x8B4513, 0x8B4513, 0x000000, 0x000000, 0x8B4513, 0x8B4513, 0xFF69B4, 0xFF69B4, 0x8B4513, 0x8B4513, 0x8B4513, 0x8B4513, 0x8B4513],
  // ケーキ
  [0xFFFFFF, 0xFF69B4, 0xFF69B4, 0xFFFFFF, 0xDEB887, 0xDEB887, 0xDEB887, 0xDEB887, 0xDEB887, 0xFFFFFF, 0xFFFFFF, 0xDEB887, 0x8B4513, 0x8B4513, 0x8B4513, 0x8B4513],
  // 音符
  [0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, 0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, 0xFFFFFF, 0x000000, 0xFFFFFF, 0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, 0xFFFFFF],
  // ゲームパッド
  [0x333333, 0x333333, 0x333333, 0x333333, 0x333333, 0xFF0000, 0x00FF00, 0x333333, 0x333333, 0x0000FF, 0xFFFF00, 0x333333, 0x333333, 0x333333, 0x333333, 0x333333],
  // コーヒー
  [0xFFFFFF, 0x8B4513, 0x8B4513, 0xFFFFFF, 0xFFFFFF, 0x8B4513, 0x8B4513, 0x8B4513, 0xFFFFFF, 0x8B4513, 0x8B4513, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
  // 傘
  [0x87CEEB, 0xFF0000, 0xFF0000, 0x87CEEB, 0xFF0000, 0xFF0000, 0xFF0000, 0xFF0000, 0x87CEEB, 0x8B4513, 0x8B4513, 0x87CEEB, 0x87CEEB, 0x8B4513, 0x87CEEB, 0x87CEEB],
  // 雪だるま
  [0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0x87CEEB, 0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, 0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0x87CEEB, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
];

// サンプルのタイトル
const SAMPLE_TITLES = [
  'すき', 'きぶん', 'たのし', 'げんき', 'ねむい',
  'おなか', 'さむい', 'あつい', 'かわい', 'きれい',
  'ゆめ', 'ほし', 'つき', 'はな', 'うみ',
  'やま', 'そら', 'にじ', 'もり', 'いえ',
];

// サンプルのニックネーム
const SAMPLE_NICKNAMES = [
  'ゆうき', 'さくら', 'はると', 'ひなた', 'そうた',
  'あおい', 'りく', 'めい', 'こはる', 'ゆい',
  'れん', 'みお', 'かいと', 'ほのか', 'たける',
  'あかり', 'しょう', 'ひまり', 'だいき', 'ゆな',
];

// ランダムなユーザーID生成
function generateUserId(): string {
  return `sample-user-${randomUUID().substring(0, 8)}`;
}

// 過去のランダムな日時を生成
function generatePastDate(daysAgo: number): string {
  const now = new Date();
  const pastDate = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
  // ランダムな時間を追加
  pastDate.setHours(Math.floor(Math.random() * 24));
  pastDate.setMinutes(Math.floor(Math.random() * 60));
  return pastDate.toISOString();
}

// 交換待ちサンプルデータの生成
function generatePendingExchangeData(count: number): PixelArt[] {
  const items: PixelArt[] = [];

  for (let i = 0; i < count; i++) {
    const patternIndex = i % SAMPLE_PIXEL_PATTERNS.length;
    const titleIndex = i % SAMPLE_TITLES.length;
    const daysAgo = Math.floor(Math.random() * 7); // 過去1週間以内

    items.push({
      id: randomUUID(),
      userId: generateUserId(),
      pixels: SAMPLE_PIXEL_PATTERNS[patternIndex],
      title: SAMPLE_TITLES[titleIndex],
      gridSize: 4,
      status: 'pending',
      source: 'local',
      createdAt: generatePastDate(daysAgo),
    });
  }

  return items;
}

// タイムライン投稿サンプルデータの生成
function generateTimelinePostData(count: number): Post[] {
  const items: Post[] = [];

  for (let i = 0; i < count; i++) {
    const patternIndex = i % SAMPLE_PIXEL_PATTERNS.length;
    const titleIndex = i % SAMPLE_TITLES.length;
    const nicknameIndex = i % SAMPLE_NICKNAMES.length;
    const daysAgo = Math.floor(Math.random() * 14); // 過去2週間以内
    const createdAt = generatePastDate(daysAgo);

    items.push({
      id: randomUUID(),
      userId: generateUserId(),
      pixelArtId: randomUUID(),
      pixels: SAMPLE_PIXEL_PATTERNS[patternIndex],
      title: SAMPLE_TITLES[titleIndex],
      gridSize: 4,
      nickname: SAMPLE_NICKNAMES[nicknameIndex],
      likeCount: Math.floor(Math.random() * 50), // 0-49いいね
      commentCount: 0,
      status: 'active',
      createdAt,
      updatedAt: createdAt,
    });
  }

  return items;
}

// バッチ書き込み（DynamoDBは25件ずつ）
async function batchWrite(tableName: string, items: Record<string, unknown>[]): Promise<void> {
  const batchSize = 25;

  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const putRequests = batch.map((item) => ({
      PutRequest: { Item: item },
    }));

    await docClient.send(new BatchWriteCommand({
      RequestItems: {
        [tableName]: putRequests,
      },
    }));

    console.log(`Wrote ${batch.length} items to ${tableName}`);
  }
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Seed request received:', JSON.stringify(event, null, 2));

  try {
    // 管理者チェック（シンプルなAPIキー認証）
    const adminKey = event.headers['X-Admin-Key'] || event.headers['x-admin-key'];
    if (adminKey !== process.env.ADMIN_API_KEY) {
      return errorResponse(403, 'FORBIDDEN', '管理者権限が必要です');
    }

    const body = event.body ? JSON.parse(event.body) : {};
    const exchangeCount = body.exchangeCount || 20;
    const postCount = body.postCount || 20;

    // 交換待ちデータの生成と保存
    console.log(`Generating ${exchangeCount} pending exchange items...`);
    const exchangeItems = generatePendingExchangeData(exchangeCount);
    await batchWrite(PIXEL_ARTS_TABLE, exchangeItems as unknown as Record<string, unknown>[]);

    // タイムライン投稿データの生成と保存
    console.log(`Generating ${postCount} timeline posts...`);
    const postItems = generateTimelinePostData(postCount);
    await batchWrite(POSTS_TABLE, postItems as unknown as Record<string, unknown>[]);

    const response: ApiResponse<{ exchangeCount: number; postCount: number }> = {
      success: true,
      data: {
        exchangeCount: exchangeItems.length,
        postCount: postItems.length,
      },
    };

    console.log('Seed completed successfully');
    return successResponse(response);
  } catch (error) {
    console.error('Seed error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', 'シードデータの作成中にエラーが発生しました');
  }
}

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Device-ID, X-Admin-Key, Authorization, X-Timestamp, X-Nonce, X-Signature, X-Request-Time',
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
