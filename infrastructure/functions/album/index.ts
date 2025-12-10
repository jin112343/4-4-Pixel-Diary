import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { validateDeviceId } from '../shared/validation';
import type { PixelArt, ApiResponse } from '../shared/types';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const PIXEL_ARTS_TABLE = process.env.PIXEL_ARTS_TABLE!;

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Album request received:', JSON.stringify(event, null, 2));

  const method = event.httpMethod;
  const pathParams = event.pathParameters;

  try {
    const deviceId = event.headers['X-Device-ID'] || event.headers['x-device-id'];

    const deviceIdValidation = validateDeviceId(deviceId);
    if (!deviceIdValidation.valid) {
      return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
    }

    switch (method) {
      case 'GET':
        if (pathParams?.artId) {
          return await getArt(deviceId!, pathParams.artId);
        }
        return await listAlbum(deviceId!, event.queryStringParameters);

      case 'DELETE':
        if (!pathParams?.artId) {
          return errorResponse(400, 'MISSING_ART_ID', 'ドット絵IDが必要です');
        }
        return await deleteArt(deviceId!, pathParams.artId);

      default:
        return errorResponse(405, 'METHOD_NOT_ALLOWED', 'メソッドが許可されていません');
    }
  } catch (error) {
    console.error('Album error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', '処理中にエラーが発生しました');
  }
}

async function listAlbum(
  deviceId: string,
  queryParams: { [key: string]: string | undefined } | null,
): Promise<APIGatewayProxyResult> {
  const limit = Math.min(parseInt(queryParams?.limit || '20', 10), 50);
  const sortBy = queryParams?.sortBy || 'createdAt'; // createdAt or receivedAt
  const order = queryParams?.order || 'desc';
  const nextToken = queryParams?.nextToken;

  // 自分のドット絵を取得（受信したもののみ）
  const result = await docClient.send(new QueryCommand({
    TableName: PIXEL_ARTS_TABLE,
    IndexName: 'user-index',
    KeyConditionExpression: 'userId = :userId',
    FilterExpression: '#status = :status',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':userId': deviceId,
      ':status': 'received',
    },
    Limit: limit,
    ScanIndexForward: order === 'asc',
    ExclusiveStartKey: nextToken ? JSON.parse(Buffer.from(nextToken, 'base64').toString()) : undefined,
  }));

  const arts = (result.Items || []) as PixelArt[];
  const hasMore = !!result.LastEvaluatedKey;
  const newNextToken = result.LastEvaluatedKey
    ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
    : undefined;

  const response: ApiResponse<PixelArt[]> = {
    success: true,
    data: arts,
    pagination: {
      nextToken: newNextToken,
      hasMore,
    },
  };

  return successResponse(response);
}

async function getArt(deviceId: string, artId: string): Promise<APIGatewayProxyResult> {
  // ドット絵を取得
  const result = await docClient.send(new QueryCommand({
    TableName: PIXEL_ARTS_TABLE,
    IndexName: 'user-index',
    KeyConditionExpression: 'userId = :userId',
    FilterExpression: 'id = :artId',
    ExpressionAttributeValues: {
      ':userId': deviceId,
      ':artId': artId,
    },
    Limit: 1,
  }));

  if (!result.Items || result.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', 'ドット絵が見つかりません');
  }

  const art = result.Items[0] as PixelArt;

  const response: ApiResponse<PixelArt> = {
    success: true,
    data: art,
  };

  return successResponse(response);
}

async function deleteArt(deviceId: string, artId: string): Promise<APIGatewayProxyResult> {
  // ドット絵を取得
  const result = await docClient.send(new QueryCommand({
    TableName: PIXEL_ARTS_TABLE,
    IndexName: 'user-index',
    KeyConditionExpression: 'userId = :userId',
    FilterExpression: 'id = :artId',
    ExpressionAttributeValues: {
      ':userId': deviceId,
      ':artId': artId,
    },
    Limit: 1,
  }));

  if (!result.Items || result.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', 'ドット絵が見つかりません');
  }

  const art = result.Items[0] as PixelArt;

  // 論理削除（ステータスを変更）
  await docClient.send(new UpdateCommand({
    TableName: PIXEL_ARTS_TABLE,
    Key: { id: artId, createdAt: art.createdAt },
    UpdateExpression: 'SET #status = :status',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':status': 'deleted' },
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
