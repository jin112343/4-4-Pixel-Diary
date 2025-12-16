#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { DatabaseStack } from '../lib/stacks/database-stack';
import { StorageStack } from '../lib/stacks/storage-stack';
import { ApiStack } from '../lib/stacks/api-stack';
import { SecurityStack } from '../lib/stacks/security-stack';
import { MonitoringStack } from '../lib/stacks/monitoring-stack';

const app = new cdk.App();

// 環境設定（本番環境のみ）
const environment = 'prod';
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: 'ap-northeast-1',
};
const prefix = `pixeldiary-${environment}`;

// タグ設定
const tags = {
  Project: 'PixelDiary',
  Environment: environment,
  ManagedBy: 'CDK',
};

// データベーススタック
const databaseStack = new DatabaseStack(app, `${prefix}-database`, {
  env,
  prefix,
  tags,
});

// ストレージスタック
const storageStack = new StorageStack(app, `${prefix}-storage`, {
  env,
  prefix,
  tags,
});

// APIスタック
const apiStack = new ApiStack(app, `${prefix}-api`, {
  env,
  prefix,
  tags,
  pixelArtsTable: databaseStack.pixelArtsTable,
  postsTable: databaseStack.postsTable,
  commentsTable: databaseStack.commentsTable,
  usersTable: databaseStack.usersTable,
  appConfigTable: databaseStack.appConfigTable,
  assetsBucket: storageStack.assetsBucket,
});

// セキュリティスタック
const securityStack = new SecurityStack(app, `${prefix}-security`, {
  env,
  prefix,
  tags,
  api: apiStack.api,
});

// 監視スタック
const monitoringStack = new MonitoringStack(app, `${prefix}-monitoring`, {
  env,
  prefix,
  tags,
  api: apiStack.api,
  lambdaFunctions: apiStack.lambdaFunctions,
});

// 依存関係
apiStack.addDependency(databaseStack);
apiStack.addDependency(storageStack);
securityStack.addDependency(apiStack);
monitoringStack.addDependency(apiStack);
