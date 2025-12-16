import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  ComprehendClient,
  DetectSentimentCommand,
  DetectDominantLanguageCommand,
} from '@aws-sdk/client-comprehend';
import {
  RekognitionClient,
  DetectModerationLabelsCommand,
} from '@aws-sdk/client-rekognition';
import { containsNgWord } from '../shared/validation';
import type { ModerationResult, ApiResponse } from '../shared/types';

const comprehendClient = new ComprehendClient({});
const rekognitionClient = new RekognitionClient({});

// 不適切コンテンツのしきい値
const MODERATION_CONFIDENCE_THRESHOLD = 80;
const NEGATIVE_SENTIMENT_THRESHOLD = 0.8;

interface ModerationRequest {
  text?: string;
  imageBase64?: string;
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Moderation request received');

  try {
    if (!event.body) {
      return errorResponse(400, 'MISSING_BODY', 'リクエストボディが必要です');
    }

    const body: ModerationRequest = JSON.parse(event.body);
    const flags: string[] = [];
    let sentiment: ModerationResult['sentiment'];

    // テキストモデレーション
    if (body.text) {
      const textResult = await moderateText(body.text);
      flags.push(...textResult.flags);
      sentiment = textResult.sentiment;
    }

    // 画像モデレーション（Base64）
    if (body.imageBase64) {
      const imageResult = await moderateImage(body.imageBase64);
      flags.push(...imageResult.flags);
    }

    const isApproved = flags.length === 0;

    const result: ModerationResult = {
      isApproved,
      flags,
      sentiment,
    };

    const response: ApiResponse<ModerationResult> = {
      success: true,
      data: result,
    };

    return successResponse(response);
  } catch (error) {
    console.error('Moderation error:', error);
    return errorResponse(500, 'INTERNAL_ERROR', 'モデレーション処理中にエラーが発生しました');
  }
}

async function moderateText(text: string): Promise<{ flags: string[]; sentiment?: ModerationResult['sentiment'] }> {
  const flags: string[] = [];

  // 1. NGワードチェック（ローカル）
  if (containsNgWord(text)) {
    flags.push('ng_word');
  }

  // 2. 言語検出
  let languageCode = 'ja';
  try {
    const langResult = await comprehendClient.send(new DetectDominantLanguageCommand({
      Text: text,
    }));

    if (langResult.Languages && langResult.Languages.length > 0) {
      languageCode = langResult.Languages[0].LanguageCode || 'ja';
    }
  } catch (error) {
    console.warn('Language detection failed:', error);
  }

  // 3. 感情分析（日本語または英語のみ）
  let sentiment: ModerationResult['sentiment'];
  if (['ja', 'en'].includes(languageCode)) {
    try {
      const sentimentResult = await comprehendClient.send(new DetectSentimentCommand({
        Text: text,
        LanguageCode: languageCode as 'ja' | 'en',
      }));

      sentiment = {
        sentiment: sentimentResult.Sentiment || 'NEUTRAL',
        scores: {
          positive: sentimentResult.SentimentScore?.Positive || 0,
          negative: sentimentResult.SentimentScore?.Negative || 0,
          neutral: sentimentResult.SentimentScore?.Neutral || 0,
          mixed: sentimentResult.SentimentScore?.Mixed || 0,
        },
      };

      // 極端にネガティブな場合はフラグ
      if (
        sentiment.sentiment === 'NEGATIVE' &&
        sentiment.scores.negative > NEGATIVE_SENTIMENT_THRESHOLD
      ) {
        flags.push('negative_sentiment');
      }
    } catch (error) {
      console.warn('Sentiment analysis failed:', error);
    }
  }

  return { flags, sentiment };
}

async function moderateImage(imageBase64: string): Promise<{ flags: string[] }> {
  const flags: string[] = [];

  try {
    // Base64をバイナリに変換
    const imageBytes = Buffer.from(imageBase64, 'base64');

    // Rekognitionでモデレーション
    const result = await rekognitionClient.send(new DetectModerationLabelsCommand({
      Image: {
        Bytes: imageBytes,
      },
      MinConfidence: MODERATION_CONFIDENCE_THRESHOLD,
    }));

    if (result.ModerationLabels && result.ModerationLabels.length > 0) {
      for (const label of result.ModerationLabels) {
        if (label.Confidence && label.Confidence >= MODERATION_CONFIDENCE_THRESHOLD) {
          flags.push(`image_${label.Name?.toLowerCase().replace(/\s+/g, '_')}`);
        }
      }
    }
  } catch (error) {
    console.warn('Image moderation failed:', error);
    // 画像モデレーションの失敗は致命的ではないのでスキップ
  }

  return { flags };
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
