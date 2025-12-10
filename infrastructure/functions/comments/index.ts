import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import { validateComment, validateNickname, validateDeviceId } from '../shared/validation';
import type { Comment, ApiResponse } from '../shared/types';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const COMMENTS_TABLE = process.env.COMMENTS_TABLE!;
const POSTS_TABLE = process.env.POSTS_TABLE!;

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Comments request received:', JSON.stringify(event, null, 2));

  const method = event.httpMethod;
  const pathParams = event.pathParameters;

  try {
    const deviceId = event.headers['X-Device-ID'] || event.headers['x-device-id'];
    const postId = pathParams?.postId;

    if (!postId) {
      return errorResponse(400, 'MISSING_POST_ID', '投稿IDが必要です');
    }

    switch (method) {
      case 'GET':
        return await listComments(postId, event.queryStringParameters);

      case 'POST':
        return await createComment(postId, deviceId!, event.body);

      case 'DELETE':
        const commentId = pathParams?.commentId;
        if (!commentId) {
          return errorResponse(400, 'MISSING_COMMENT_ID', 'コメントIDが必要です');
        }
        return await deleteComment(postId, commentId, deviceId!);

      default:
        return errorResponse(405, 'METHOD_NOT_ALLOWED', 'メソッドが許可されていません');
    }
  } catch (error) {
    console.error('Comments error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', '処理中にエラーが発生しました');
  }
}

async function createComment(
  postId: string,
  deviceId: string,
  body: string | null,
): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  if (!body) {
    return errorResponse(400, 'MISSING_BODY', 'リクエストボディが必要です');
  }

  const data = JSON.parse(body);

  // コメントバリデーション
  const contentValidation = validateComment(data.content);
  if (!contentValidation.valid) {
    return errorResponse(400, 'INVALID_COMMENT', contentValidation.error!);
  }

  // ニックネームバリデーション
  const nicknameValidation = validateNickname(data.nickname);
  if (!nicknameValidation.valid) {
    return errorResponse(400, 'INVALID_NICKNAME', nicknameValidation.error!);
  }

  const now = new Date().toISOString();
  const commentId = randomUUID();

  const comment: Comment = {
    id: commentId,
    postId,
    userId: deviceId,
    content: contentValidation.sanitized,
    nickname: nicknameValidation.sanitized || undefined,
    status: 'active',
    createdAt: now,
  };

  // コメントを保存
  await docClient.send(new PutCommand({
    TableName: COMMENTS_TABLE,
    Item: comment,
  }));

  // 投稿のコメント数を増加
  await updatePostCommentCount(postId, 1);

  const response: ApiResponse<Comment> = {
    success: true,
    data: comment,
  };

  return successResponse(response, 201);
}

async function listComments(
  postId: string,
  queryParams: { [key: string]: string | undefined } | null,
): Promise<APIGatewayProxyResult> {
  const limit = Math.min(parseInt(queryParams?.limit || '50', 10), 100);
  const nextToken = queryParams?.nextToken;

  const result = await docClient.send(new QueryCommand({
    TableName: COMMENTS_TABLE,
    KeyConditionExpression: 'postId = :postId',
    FilterExpression: '#status = :status',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':postId': postId,
      ':status': 'active',
    },
    Limit: limit,
    ScanIndexForward: true, // 古い順
    ExclusiveStartKey: nextToken ? JSON.parse(Buffer.from(nextToken, 'base64').toString()) : undefined,
  }));

  const comments = (result.Items || []) as Comment[];
  const hasMore = !!result.LastEvaluatedKey;
  const newNextToken = result.LastEvaluatedKey
    ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
    : undefined;

  const response: ApiResponse<Comment[]> = {
    success: true,
    data: comments,
    pagination: {
      nextToken: newNextToken,
      hasMore,
    },
  };

  return successResponse(response);
}

async function deleteComment(
  postId: string,
  commentId: string,
  deviceId: string,
): Promise<APIGatewayProxyResult> {
  const deviceIdValidation = validateDeviceId(deviceId);
  if (!deviceIdValidation.valid) {
    return errorResponse(400, 'INVALID_DEVICE_ID', deviceIdValidation.error!);
  }

  // コメントを取得
  const result = await docClient.send(new QueryCommand({
    TableName: COMMENTS_TABLE,
    KeyConditionExpression: 'postId = :postId',
    FilterExpression: 'id = :commentId',
    ExpressionAttributeValues: {
      ':postId': postId,
      ':commentId': commentId,
    },
    Limit: 1,
  }));

  if (!result.Items || result.Items.length === 0) {
    return errorResponse(404, 'NOT_FOUND', 'コメントが見つかりません');
  }

  const comment = result.Items[0] as Comment;

  // 自分のコメントのみ削除可能
  if (comment.userId !== deviceId) {
    return errorResponse(403, 'FORBIDDEN', 'このコメントを削除する権限がありません');
  }

  // 論理削除
  await docClient.send(new UpdateCommand({
    TableName: COMMENTS_TABLE,
    Key: { postId, createdAt: comment.createdAt },
    UpdateExpression: 'SET #status = :status',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':status': 'deleted' },
  }));

  // 投稿のコメント数を減少
  await updatePostCommentCount(postId, -1);

  const response: ApiResponse<{ deleted: boolean }> = {
    success: true,
    data: { deleted: true },
  };

  return successResponse(response);
}

async function updatePostCommentCount(postId: string, delta: number): Promise<void> {
  // 投稿を取得
  const result = await docClient.send(new QueryCommand({
    TableName: POSTS_TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': postId },
    Limit: 1,
  }));

  if (!result.Items || result.Items.length === 0) {
    return;
  }

  const post = result.Items[0];

  // コメント数を更新
  await docClient.send(new UpdateCommand({
    TableName: POSTS_TABLE,
    Key: { id: postId, createdAt: post.createdAt },
    UpdateExpression: 'SET commentCount = if_not_exists(commentCount, :zero) + :delta, updatedAt = :updatedAt',
    ExpressionAttributeValues: {
      ':delta': delta,
      ':zero': 0,
      ':updatedAt': new Date().toISOString(),
    },
  })).catch(() => {
    // エラーは無視
  });
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
