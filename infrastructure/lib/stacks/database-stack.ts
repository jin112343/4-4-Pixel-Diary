import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import { Construct } from 'constructs';

export interface DatabaseStackProps extends cdk.StackProps {
  prefix: string;
}

export class DatabaseStack extends cdk.Stack {
  public readonly pixelArtsTable: dynamodb.Table;
  public readonly postsTable: dynamodb.Table;
  public readonly commentsTable: dynamodb.Table;
  public readonly usersTable: dynamodb.Table;
  public readonly appConfigTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    const { prefix } = props;

    // ピクセルアートテーブル
    this.pixelArtsTable = new dynamodb.Table(this, 'PixelArtsTable', {
      tableName: `${prefix}-pixel-arts`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // 交換用GSI（ランダムマッチング用）
    this.pixelArtsTable.addGlobalSecondaryIndex({
      indexName: 'exchange-index',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // ユーザー別GSI
    this.pixelArtsTable.addGlobalSecondaryIndex({
      indexName: 'user-index',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // 投稿テーブル
    this.postsTable = new dynamodb.Table(this, 'PostsTable', {
      tableName: `${prefix}-posts`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // タイムライン用GSI（新着順）
    this.postsTable.addGlobalSecondaryIndex({
      indexName: 'timeline-index',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // おすすめ用GSI（いいね数順）
    this.postsTable.addGlobalSecondaryIndex({
      indexName: 'popular-index',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'likeCount', type: dynamodb.AttributeType.NUMBER },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // コメントテーブル
    this.commentsTable = new dynamodb.Table(this, 'CommentsTable', {
      tableName: `${prefix}-comments`,
      partitionKey: { name: 'postId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // ユーザーテーブル（匿名ユーザー）
    this.usersTable = new dynamodb.Table(this, 'UsersTable', {
      tableName: `${prefix}-users`,
      partitionKey: { name: 'deviceId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // アプリ設定テーブル（強制アップデート・メンテナンスモード）
    this.appConfigTable = new dynamodb.Table(this, 'AppConfigTable', {
      tableName: `${prefix}-app-config`,
      partitionKey: { name: 'configType', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // 出力
    new cdk.CfnOutput(this, 'PixelArtsTableName', {
      value: this.pixelArtsTable.tableName,
      exportName: `${prefix}-pixel-arts-table-name`,
    });

    new cdk.CfnOutput(this, 'PostsTableName', {
      value: this.postsTable.tableName,
      exportName: `${prefix}-posts-table-name`,
    });

    new cdk.CfnOutput(this, 'CommentsTableName', {
      value: this.commentsTable.tableName,
      exportName: `${prefix}-comments-table-name`,
    });

    new cdk.CfnOutput(this, 'UsersTableName', {
      value: this.usersTable.tableName,
      exportName: `${prefix}-users-table-name`,
    });

    new cdk.CfnOutput(this, 'AppConfigTableName', {
      value: this.appConfigTable.tableName,
      exportName: `${prefix}-app-config-table-name`,
    });
  }
}
