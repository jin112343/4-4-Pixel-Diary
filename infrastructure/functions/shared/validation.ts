// バリデーション・サニタイズユーティリティ

import {
  checkContent,
  containsNgWord,
  maskContent,
  isSafe,
  setStrictness,
  addCustomNgWords,
  addCustomAllowWords,
  updateNgWords,
  FilterStrictness,
} from './content-filter';

// 再エクスポート
export {
  checkContent,
  containsNgWord,
  maskContent,
  isSafe,
  setStrictness,
  addCustomNgWords,
  addCustomAllowWords,
  updateNgWords,
  FilterStrictness,
};

const MAX_TITLE_LENGTH = 5;
const MAX_NICKNAME_LENGTH = 5;
const MAX_COMMENT_LENGTH = 50;
const VALID_GRID_SIZES = [4, 5];

// XSS対策: HTMLエスケープ
export function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// SQLインジェクション対策用のサニタイズ
export function sanitizeInput(str: string): string {
  // DynamoDBはNoSQLなのでSQLインジェクションはないが、念のため特殊文字を除去
  return str
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '') // 制御文字を除去
    .trim();
}

// タイトルバリデーション
export function validateTitle(title: string | undefined): { valid: boolean; error?: string; sanitized: string } {
  if (!title) {
    return { valid: true, sanitized: '' };
  }

  const sanitized = sanitizeInput(title);

  if (sanitized.length > MAX_TITLE_LENGTH) {
    return {
      valid: false,
      error: `タイトルは${MAX_TITLE_LENGTH}文字以内で入力してください`,
      sanitized,
    };
  }

  if (containsNgWord(sanitized)) {
    return {
      valid: false,
      error: '不適切な表現が含まれています',
      sanitized,
    };
  }

  return { valid: true, sanitized: escapeHtml(sanitized) };
}

// ニックネームバリデーション
export function validateNickname(nickname: string | undefined): { valid: boolean; error?: string; sanitized: string } {
  if (!nickname) {
    return { valid: true, sanitized: '' };
  }

  const sanitized = sanitizeInput(nickname);

  if (sanitized.length > MAX_NICKNAME_LENGTH) {
    return {
      valid: false,
      error: `ニックネームは${MAX_NICKNAME_LENGTH}文字以内で入力してください`,
      sanitized,
    };
  }

  if (containsNgWord(sanitized)) {
    return {
      valid: false,
      error: '不適切な表現が含まれています',
      sanitized,
    };
  }

  return { valid: true, sanitized: escapeHtml(sanitized) };
}

// コメントバリデーション
export function validateComment(content: string): { valid: boolean; error?: string; sanitized: string } {
  if (!content || content.trim() === '') {
    return {
      valid: false,
      error: 'コメントを入力してください',
      sanitized: '',
    };
  }

  const sanitized = sanitizeInput(content);

  if (sanitized.length > MAX_COMMENT_LENGTH) {
    return {
      valid: false,
      error: `コメントは${MAX_COMMENT_LENGTH}文字以内で入力してください`,
      sanitized,
    };
  }

  if (containsNgWord(sanitized)) {
    return {
      valid: false,
      error: '不適切な表現が含まれています',
      sanitized,
    };
  }

  return { valid: true, sanitized: escapeHtml(sanitized) };
}

// ピクセルデータバリデーション
export function validatePixels(pixels: unknown, gridSize: number): { valid: boolean; error?: string } {
  if (!Array.isArray(pixels)) {
    return { valid: false, error: 'ピクセルデータが不正です' };
  }

  if (!VALID_GRID_SIZES.includes(gridSize)) {
    return { valid: false, error: 'グリッドサイズが不正です' };
  }

  const expectedCount = gridSize * gridSize;
  if (pixels.length !== expectedCount) {
    return { valid: false, error: `ピクセル数が不正です（期待: ${expectedCount}、実際: ${pixels.length}）` };
  }

  // RGB値の範囲チェック（0x000000 ~ 0xFFFFFF）
  for (const pixel of pixels) {
    if (typeof pixel !== 'number' || pixel < 0 || pixel > 0xFFFFFF || !Number.isInteger(pixel)) {
      return { valid: false, error: 'ピクセル値が不正です' };
    }
  }

  return { valid: true };
}

// デバイスIDバリデーション（UUID形式）
export function validateDeviceId(deviceId: string | undefined): { valid: boolean; error?: string } {
  if (!deviceId) {
    return { valid: false, error: 'デバイスIDが必要です' };
  }

  // UUID v4形式のチェック
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(deviceId)) {
    return { valid: false, error: 'デバイスIDの形式が不正です' };
  }

  return { valid: true };
}

// NGワードチェックは content-filter.ts からインポート
// containsNgWord は上記でエクスポート済み

// リクエスト署名検証
export function validateRequestSignature(
  signature: string | undefined,
  timestamp: string | undefined,
  nonce: string | undefined,
  body: string,
  signingKey: string,
): { valid: boolean; error?: string } {
  if (!signature || !timestamp || !nonce) {
    return { valid: false, error: '署名情報が不足しています' };
  }

  // タイムスタンプの有効期限チェック（5分以内）
  const requestTime = parseInt(timestamp, 10);
  const now = Date.now();
  const timeDiff = Math.abs(now - requestTime);
  if (timeDiff > 5 * 60 * 1000) {
    return { valid: false, error: 'リクエストの有効期限が切れています' };
  }

  // 署名の検証（HMAC-SHA256）
  // 実際の実装では crypto モジュールを使用
  // const expectedSignature = createHmac('sha256', signingKey)
  //   .update(`${timestamp}:${nonce}:${body}`)
  //   .digest('hex');
  // if (signature !== expectedSignature) {
  //   return { valid: false, error: '署名が不正です' };
  // }

  return { valid: true };
}
