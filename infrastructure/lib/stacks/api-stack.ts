import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';
import * as path from 'path';

export interface ApiStackProps extends cdk.StackProps {
  prefix: string;
  pixelArtsTable: dynamodb.Table;
  postsTable: dynamodb.Table;
  commentsTable: dynamodb.Table;
  usersTable: dynamodb.Table;
  appConfigTable: dynamodb.Table;
  assetsBucket: s3.Bucket;
}

export class ApiStack extends cdk.Stack {
  public readonly api: apigateway.RestApi;
  public readonly lambdaFunctions: NodejsFunction[];

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);

    const {
      prefix,
      pixelArtsTable,
      postsTable,
      commentsTable,
      usersTable,
      appConfigTable,
      assetsBucket,
    } = props;

    this.lambdaFunctions = [];

    // 共通のLambda実行ロール
    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // DynamoDB権限を追加
    pixelArtsTable.grantReadWriteData(lambdaRole);
    postsTable.grantReadWriteData(lambdaRole);
    commentsTable.grantReadWriteData(lambdaRole);
    usersTable.grantReadWriteData(lambdaRole);
    appConfigTable.grantReadWriteData(lambdaRole);
    assetsBucket.grantReadWrite(lambdaRole);

    // Comprehend/Rekognition権限を追加
    lambdaRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'comprehend:DetectSentiment',
        'comprehend:DetectDominantLanguage',
        'rekognition:DetectModerationLabels',
      ],
      resources: ['*'],
    }));

    // 共通の環境変数
    const commonEnv = {
      PIXEL_ARTS_TABLE: pixelArtsTable.tableName,
      POSTS_TABLE: postsTable.tableName,
      COMMENTS_TABLE: commentsTable.tableName,
      USERS_TABLE: usersTable.tableName,
      APP_CONFIG_TABLE: appConfigTable.tableName,
      ASSETS_BUCKET: assetsBucket.bucketName,
      NODE_OPTIONS: '--enable-source-maps',
    };

    // Lambda関数の作成（NodejsFunctionでTypeScriptを自動バンドル）
    const createLambda = (name: string): NodejsFunction => {
      const fn = new NodejsFunction(this, `${name}Function`, {
        functionName: `${prefix}-${name}`,
        runtime: lambda.Runtime.NODEJS_20_X,
        entry: path.join(__dirname, '../../functions', name, 'index.ts'),
        handler: 'handler',
        role: lambdaRole,
        environment: commonEnv,
        timeout: cdk.Duration.seconds(30),
        memorySize: 256,
        logRetention: logs.RetentionDays.ONE_MONTH,
        tracing: lambda.Tracing.ACTIVE,
        bundling: {
          minify: true,
          sourceMap: true,
          externalModules: ['@aws-sdk/*'],
        },
      });
      this.lambdaFunctions.push(fn);
      return fn;
    };

    // 各Lambda関数
    const exchangeFunction = createLambda('exchange');
    const postsFunction = createLambda('posts');
    const commentsFunction = createLambda('comments');
    const albumFunction = createLambda('album');
    const configFunction = createLambda('config');
    const moderationFunction = createLambda('moderation');

    // Seed関数（管理者専用）
    const seedFunction = new NodejsFunction(this, 'SeedFunction', {
      functionName: `${prefix}-seed`,
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: path.join(__dirname, '../../functions', 'seed', 'index.ts'),
      handler: 'handler',
      role: lambdaRole,
      environment: {
        ...commonEnv,
        ADMIN_API_KEY: process.env.ADMIN_API_KEY || 'pixeldiary-admin-secret-key',
      },
      timeout: cdk.Duration.seconds(60),
      memorySize: 512,
      logRetention: logs.RetentionDays.ONE_MONTH,
      bundling: {
        minify: true,
        sourceMap: true,
        externalModules: ['@aws-sdk/*'],
      },
    });
    this.lambdaFunctions.push(seedFunction);

    // API Gateway
    this.api = new apigateway.RestApi(this, 'PixelDiaryApi', {
      restApiName: `${prefix}-api`,
      description: '4x4 Pixel Diary API',
      deployOptions: {
        stageName: 'v1',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
        throttlingBurstLimit: 200,
        throttlingRateLimit: 100,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: [
          'Content-Type',
          'X-Amz-Date',
          'Authorization',
          'X-Api-Key',
          'X-Device-ID',
          'X-Timestamp',
          'X-Nonce',
          'X-Signature',
          'X-Request-Time',
        ],
      },
    });

    // リクエストバリデータ
    const requestValidator = new apigateway.RequestValidator(this, 'RequestValidator', {
      restApi: this.api,
      requestValidatorName: 'validate-body-and-params',
      validateRequestBody: true,
      validateRequestParameters: true,
    });

    // APIリソースとメソッド

    // /pixelart/exchange
    const pixelartResource = this.api.root.addResource('pixelart');
    const exchangeResource = pixelartResource.addResource('exchange');
    exchangeResource.addMethod('POST', new apigateway.LambdaIntegration(exchangeFunction), {
      requestValidator,
    });

    // /posts
    const postsResource = this.api.root.addResource('posts');
    postsResource.addMethod('GET', new apigateway.LambdaIntegration(postsFunction));
    postsResource.addMethod('POST', new apigateway.LambdaIntegration(postsFunction), {
      requestValidator,
    });

    // /posts/{postId}
    const postIdResource = postsResource.addResource('{postId}');
    postIdResource.addMethod('GET', new apigateway.LambdaIntegration(postsFunction));
    postIdResource.addMethod('DELETE', new apigateway.LambdaIntegration(postsFunction));

    // /posts/{postId}/like
    const likeResource = postIdResource.addResource('like');
    likeResource.addMethod('POST', new apigateway.LambdaIntegration(postsFunction));
    likeResource.addMethod('DELETE', new apigateway.LambdaIntegration(postsFunction));

    // /posts/{postId}/report
    const reportResource = postIdResource.addResource('report');
    reportResource.addMethod('POST', new apigateway.LambdaIntegration(postsFunction), {
      requestValidator,
    });

    // /posts/{postId}/comments
    const commentsResource = postIdResource.addResource('comments');
    commentsResource.addMethod('GET', new apigateway.LambdaIntegration(commentsFunction));
    commentsResource.addMethod('POST', new apigateway.LambdaIntegration(commentsFunction), {
      requestValidator,
    });

    // /posts/{postId}/comments/{commentId}
    const commentIdResource = commentsResource.addResource('{commentId}');
    commentIdResource.addMethod('DELETE', new apigateway.LambdaIntegration(commentsFunction));

    // /album
    const albumResource = this.api.root.addResource('album');
    albumResource.addMethod('GET', new apigateway.LambdaIntegration(albumFunction));

    // /album/{artId}
    const artIdResource = albumResource.addResource('{artId}');
    artIdResource.addMethod('GET', new apigateway.LambdaIntegration(albumFunction));
    artIdResource.addMethod('DELETE', new apigateway.LambdaIntegration(albumFunction));

    // /config/app - 強制アップデート・メンテナンス設定
    const configResource = this.api.root.addResource('config');
    const appConfigResource = configResource.addResource('app');
    appConfigResource.addMethod('GET', new apigateway.LambdaIntegration(configFunction));

    // /moderation/check - コンテンツモデレーション（内部用）
    const moderationResource = this.api.root.addResource('moderation');
    const checkResource = moderationResource.addResource('check');
    checkResource.addMethod('POST', new apigateway.LambdaIntegration(moderationFunction), {
      requestValidator,
    });

    // /admin/seed - サンプルデータ投入（管理者専用）
    const adminResource = this.api.root.addResource('admin');
    const seedResource = adminResource.addResource('seed');
    seedResource.addMethod('POST', new apigateway.LambdaIntegration(seedFunction), {
      requestValidator,
    });

    // 使用プラン（レート制限）
    const usagePlan = this.api.addUsagePlan('UsagePlan', {
      name: `${prefix}-usage-plan`,
      description: 'Usage plan for Pixel Diary API',
      throttle: {
        rateLimit: 100,
        burstLimit: 200,
      },
      quota: {
        limit: 10000,
        period: apigateway.Period.DAY,
      },
    });

    usagePlan.addApiStage({
      stage: this.api.deploymentStage,
    });

    // 出力
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: this.api.url,
      exportName: `${prefix}-api-url`,
    });

    new cdk.CfnOutput(this, 'ApiId', {
      value: this.api.restApiId,
      exportName: `${prefix}-api-id`,
    });
  }
}
