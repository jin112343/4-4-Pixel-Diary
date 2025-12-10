import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
} from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import { validatePixels, validateTitle, validateNickname, validateDeviceId } from '../shared/validation';
import type { Post, ApiResponse } from '../shared/types';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const POSTS_TABLE = process.env.POSTS_TABLE!;

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Posts request received:', JSON.stringify(event, null, 2));

  const method = event.httpMethod;
  const pathParams = event.pathParameters;
  const resource = event.resource;

  try {
    // デバイスID取得
    const deviceId = event.headers['X-Device-ID'] || event.headers['x-device-id'];

    switch (method) {
      case 'GET':
        if (pathParams?.postId) {
          return await getPost(pathParams.postId);
        }
        return await listPosts(event.queryStringParameters);

      case 'POST':
        if (!deviceId) {
          return errorResponse(401, 'MISSING_DEVICE_ID', 'デバイスIDが必要です');
        }
        if (resource.includes('/like')) {
          if (!pathParams?.postId) {
            return errorResponse(400, 'MISSING_POST_ID', '投稿IDが必要です');
          }
          return await likePost(pathParams.postId, deviceId);
        }
        if (resource.includes('/report')) {
          if (!pathParams?.postId) {
            return errorResponse(400, 'MISSING_POST_ID', '投稿IDが必要です');
          }
          return await reportPost(pathParams.postId, deviceId, event.body);
        }
        return await createPost(deviceId, event.body);

      case 'DELETE':
        if (!deviceId) {
          return errorResponse(401, 'MISSING_DEVICE_ID', 'デバイスIDが必要です');
        }
        if (!pathParams?.postId) {
          return errorResponse(400, 'MISSING_POST_ID', '投稿IDが必要です');
        }
        if (resource.includes('/like')) {
          return await unlikePost(pathParams.postId, deviceId);
        }
        return await deletePost(pathParams.postId, deviceId);

      default:
        return errorResponse(405, 'METHOD_NOT_ALLOWED', 'メソッドが許可されていません');
    }
  } catch (error) {
    console.error('Posts error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', '処理中にエラーが発生しました');
  }
}

async function createPost(deviceId: string, body: string | null): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  if (!body) {
    return errorResponse(400, 'MISSING_BODY', 'リクエストボディが必要です');
  }

  const data = JSON.parse(body);
  const gridSize = data.gridSize || 4;

  // バリデーション
  const pixelsValidation = validatePixels(data.pixels, gridSize);
  if (!pixelsValidation.valid) {
    return errorResponse(400, 'INVALID_PIXELS', pixelsValidation.error!);
  }

  const titleValidation = validateTitle(data.title);
  if (!titleValidation.valid) {
    return errorResponse(400, 'INVALID_TITLE', titleValidation.error!);
  }

  const nicknameValidation = validateNickname(data.nickname);
  if (!nicknameValidation.valid) {
    return errorResponse(400, 'INVALID_NICKNAME', nicknameValidation.error!);
  }

  const now = new Date().toISOString();
  const postId = randomUUID();

  const post: Post = {
    id: postId,
    userId: deviceId,
    pixelArtId: data.pixelArtId || postId,
    pixels: data.pixels,
    title: titleValidation.sanitized,
    gridSize,
    nickname: nicknameValidation.sanitized || undefined,
    likeCount: 0,
    commentCount: 0,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };

  await docClient.send(new PutCommand({
    TableName: POSTS_TABLE,
    Item: post,
  }));

  const response: ApiResponse<Post> = {
    success: true,
    data: post,
  };

  return successResponse(response, 201);
}

async function getPost(postId: string): Promise<APIGatewayProxyResult> {
  // 投稿を取得（createdAtが不明なのでQueryを使用）
  const result = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': postId },
    Limit: 1,
  }));

  if (!result.Items || result.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', '投稿が見つかりません');
  }

  const post = result.Items[0] as Post;
  if (post.status !== 'active') {
    return errorResponse(404, 'NOT_FOUND', '投稿が見つかりません');
  }

  const response: ApiResponse<Post> = {
    success: true,
    data: post,
  };

  return successResponse(response);
}

async function listPosts(
  queryParams: { [key: string]: string | undefined } | null,
): Promise<APIGatewayProxyResult> {
  const tab = queryParams?.tab || 'new';
  const limit = Math.min(parseInt(queryParams?.limit || '20', 10), 50);
  const nextToken = queryParams?.nextToken;

  let indexName: string;
  let scanIndexForward: boolean;

  if (tab === 'popular') {
    indexName = 'popular-index';
    scanIndexForward = false; // いいね数の降順
  } else {
    indexName = 'timeline-index';
    scanIndexForward = false; // 新着順（降順）
  }

  const result = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    IndexName: indexName,
    KeyConditionExpression: '#status = :status',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':status': 'active' },
    Limit: limit,
    ScanIndexForward: scanIndexForward,
    ExclusiveStartKey: nextToken ? JSON.parse(Buffer.from(nextToken, 'base64').toString()) : undefined,
  }));

  const posts = (result.Items || []) as Post[];
  const hasMore = !!result.LastEvaluatedKey;
  const newNextToken = result.LastEvaluatedKey
    ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
    : undefined;

  const response: ApiResponse<Post[]> = {
    success: true,
    data: posts,
    pagination: {
      nextToken: newNextToken,
      hasMore,
    },
  };

  return successResponse(response);
}

async function likePost(postId: string, deviceId: string): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  // 投稿を取得
  const getResult = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': postId },
    Limit: 1,
  }));

  if (!getResult.Items || getResult.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', '投稿が見つかりません');
  }

  const post = getResult.Items[0] as Post;

  // いいね数を増加
  await docClient.send(new UpdateCommand({
    TableName: POSTS_TABLE,
    Key: { id: postId, createdAt: post.createdAt },
    UpdateExpression: 'SET likeCount = likeCount + :inc, updatedAt = :updatedAt',
    ExpressionAttributeValues: {
      ':inc': 1,
      ':updatedAt': new Date().toISOString(),
    },
  }));

  const response: ApiResponse<{ liked: boolean }> = {
    success: true,
    data: { liked: true },
  };

  return successResponse(response);
}

async function unlikePost(postId: string, deviceId: string): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  // 投稿を取得
  const getResult = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': postId },
    Limit: 1,
  }));

  if (!getResult.Items || getResult.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', '投稿が見つかりません');
  }

  const post = getResult.Items[0] as Post;

  // いいね数を減少（最小0）
  await docClient.send(new UpdateCommand({
    TableName: POSTS_TABLE,
    Key: { id: postId, createdAt: post.createdAt },
    UpdateExpression: 'SET likeCount = if_not_exists(likeCount, :zero) - :dec, updatedAt = :updatedAt',
    ConditionExpression: 'likeCount > :zero',
    ExpressionAttributeValues: {
      ':dec': 1,
      ':zero': 0,
      ':updatedAt': new Date().toISOString(),
    },
  })).catch(() => {
    // いいね数が0以下の場合は無視
  });

  const response: ApiResponse<{ liked: boolean }> = {
    success: true,
    data: { liked: false },
  };

  return successResponse(response);
}

async function reportPost(postId: string, deviceId: string, body: string | null): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  const data = body ? JSON.parse(body) : {};
  const reason = data.reason || 'inappropriate';

  console.log(`Post reported: ${postId} by ${deviceId}, reason: ${reason}`);

  // 通報をログに記録（実際の運用では別テーブルに保存）

  const response: ApiResponse<{ reported: boolean }> = {
    success: true,
    data: { reported: true },
  };

  return successResponse(response);
}

async function deletePost(postId: string, deviceId: string): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  // 投稿を取得
  const getResult = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': postId },
    Limit: 1,
  }));

  if (!getResult.Items || getResult.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', '投稿が見つかりません');
  }

  const post = getResult.Items[0] as Post;

  // 自分の投稿のみ削除可能
  if (post.userId !== deviceId) {
    return errorResponse(403, 'FORBIDDEN', 'この投稿を削除する権限がありません');
  }

  // 論理削除
  await docClient.send(new UpdateCommand({
    TableName: POSTS_TABLE,
    Key: { id: postId, createdAt: post.createdAt },
    UpdateExpression: 'SET #status = :status, updatedAt = :updatedAt',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':status': 'deleted',
      ':updatedAt': new Date().toISOString(),
    },
  }));

  const response: ApiResponse<{ deleted: boolean }> = {
    success: true,
    data: { deleted: true },
  };

  return successResponse(response);
}

function successResponse(body: ApiResponse, statusCode = 200): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
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
