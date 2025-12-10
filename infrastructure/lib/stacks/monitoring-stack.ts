import * as cdk from 'aws-cdk-lib';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as cloudwatchActions from 'aws-cdk-lib/aws-cloudwatch-actions';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as snsSubscriptions from 'aws-cdk-lib/aws-sns-subscriptions';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as events from 'aws-cdk-lib/aws-events';
import * as eventsTargets from 'aws-cdk-lib/aws-events-targets';
import { Construct } from 'constructs';

export interface MonitoringStackProps extends cdk.StackProps {
  prefix: string;
  api: apigateway.RestApi;
  lambdaFunctions: lambda.Function[];
}

export class MonitoringStack extends cdk.Stack {
  public readonly alertTopic: sns.Topic;
  public readonly dashboard: cloudwatch.Dashboard;

  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id, props);

    const { prefix, api, lambdaFunctions } = props;

    // SNSトピック（アラート通知用）
    this.alertTopic = new sns.Topic(this, 'AlertTopic', {
      topicName: `${prefix}-alerts`,
      displayName: 'Pixel Diary Alerts',
    });

    // メール通知を追加する場合はここでサブスクリプションを追加
    // this.alertTopic.addSubscription(
    //   new snsSubscriptions.EmailSubscription('your-email@example.com')
    // );

    // CloudWatchダッシュボード
    this.dashboard = new cloudwatch.Dashboard(this, 'Dashboard', {
      dashboardName: `${prefix}-dashboard`,
    });

    // API Gatewayメトリクス
    const apiLatencyMetric = new cloudwatch.Metric({
      namespace: 'AWS/ApiGateway',
      metricName: 'Latency',
      dimensionsMap: {
        ApiName: api.restApiName,
      },
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
    });

    const api4xxErrorMetric = new cloudwatch.Metric({
      namespace: 'AWS/ApiGateway',
      metricName: '4XXError',
      dimensionsMap: {
        ApiName: api.restApiName,
      },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
    });

    const api5xxErrorMetric = new cloudwatch.Metric({
      namespace: 'AWS/ApiGateway',
      metricName: '5XXError',
      dimensionsMap: {
        ApiName: api.restApiName,
      },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
    });

    const apiCountMetric = new cloudwatch.Metric({
      namespace: 'AWS/ApiGateway',
      metricName: 'Count',
      dimensionsMap: {
        ApiName: api.restApiName,
      },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
    });

    // API Gatewayウィジェット
    this.dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'API Gateway - リクエスト数',
        left: [apiCountMetric],
        width: 12,
      }),
      new cloudwatch.GraphWidget({
        title: 'API Gateway - レイテンシ',
        left: [apiLatencyMetric],
        width: 12,
      }),
    );

    this.dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'API Gateway - 4xx エラー',
        left: [api4xxErrorMetric],
        width: 12,
      }),
      new cloudwatch.GraphWidget({
        title: 'API Gateway - 5xx エラー',
        left: [api5xxErrorMetric],
        width: 12,
      }),
    );

    // Lambda関数メトリクス
    const lambdaMetrics: cloudwatch.Metric[] = [];
    const lambdaErrorMetrics: cloudwatch.Metric[] = [];

    lambdaFunctions.forEach((fn) => {
      lambdaMetrics.push(
        new cloudwatch.Metric({
          namespace: 'AWS/Lambda',
          metricName: 'Invocations',
          dimensionsMap: {
            FunctionName: fn.functionName,
          },
          statistic: 'Sum',
          period: cdk.Duration.minutes(1),
        }),
      );

      lambdaErrorMetrics.push(
        new cloudwatch.Metric({
          namespace: 'AWS/Lambda',
          metricName: 'Errors',
          dimensionsMap: {
            FunctionName: fn.functionName,
          },
          statistic: 'Sum',
          period: cdk.Duration.minutes(1),
        }),
      );
    });

    this.dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Lambda - 呼び出し数',
        left: lambdaMetrics,
        width: 12,
      }),
      new cloudwatch.GraphWidget({
        title: 'Lambda - エラー数',
        left: lambdaErrorMetrics,
        width: 12,
      }),
    );

    // アラーム: 5xxエラー率が高い
    const highErrorRateAlarm = new cloudwatch.Alarm(this, 'HighErrorRateAlarm', {
      alarmName: `${prefix}-high-5xx-error-rate`,
      alarmDescription: 'API Gateway 5xx error rate is high',
      metric: api5xxErrorMetric,
      threshold: 10,
      evaluationPeriods: 2,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    highErrorRateAlarm.addAlarmAction(new cloudwatchActions.SnsAction(this.alertTopic));

    // アラーム: レイテンシが高い
    const highLatencyAlarm = new cloudwatch.Alarm(this, 'HighLatencyAlarm', {
      alarmName: `${prefix}-high-latency`,
      alarmDescription: 'API Gateway latency is high',
      metric: apiLatencyMetric,
      threshold: 5000, // 5秒
      evaluationPeriods: 3,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    highLatencyAlarm.addAlarmAction(new cloudwatchActions.SnsAction(this.alertTopic));

    // Lambda関数ごとのエラーアラーム
    lambdaFunctions.forEach((fn) => {
      const alarm = new cloudwatch.Alarm(this, `${fn.node.id}ErrorAlarm`, {
        alarmName: `${prefix}-${fn.functionName}-errors`,
        alarmDescription: `Lambda function ${fn.functionName} has errors`,
        metric: new cloudwatch.Metric({
          namespace: 'AWS/Lambda',
          metricName: 'Errors',
          dimensionsMap: {
            FunctionName: fn.functionName,
          },
          statistic: 'Sum',
          period: cdk.Duration.minutes(5),
        }),
        threshold: 5,
        evaluationPeriods: 1,
        comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      });
      alarm.addAlarmAction(new cloudwatchActions.SnsAction(this.alertTopic));
    });

    // セキュリティイベント監視（EventBridge）
    // GuardDutyの検出結果を監視
    new events.Rule(this, 'GuardDutyFindingsRule', {
      ruleName: `${prefix}-guardduty-findings`,
      description: 'Capture GuardDuty findings',
      eventPattern: {
        source: ['aws.guardduty'],
        detailType: ['GuardDuty Finding'],
      },
      targets: [new eventsTargets.SnsTopic(this.alertTopic)],
    });

    // CloudTrail異常アクティビティ監視
    new events.Rule(this, 'CloudTrailAnomalyRule', {
      ruleName: `${prefix}-cloudtrail-anomaly`,
      description: 'Capture CloudTrail anomalies',
      eventPattern: {
        source: ['aws.securityhub'],
        detailType: ['Security Hub Findings - Imported'],
        detail: {
          findings: {
            Severity: {
              Label: ['HIGH', 'CRITICAL'],
            },
          },
        },
      },
      targets: [new eventsTargets.SnsTopic(this.alertTopic)],
    });

    // メトリクスフィルター: API Gateway アクセスログからの不正アクセス検出
    const apiLogGroup = new logs.LogGroup(this, 'ApiAccessLogGroup', {
      logGroupName: `/aws/apigateway/${prefix}-access-logs`,
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // 401/403エラーのメトリクスフィルター
    new logs.MetricFilter(this, 'UnauthorizedAccessFilter', {
      logGroup: apiLogGroup,
      filterPattern: logs.FilterPattern.literal('[timestamp, requestId, ip, caller, user, requestTime, httpMethod, resourcePath, protocol, status=401 || status=403, responseLength, responseTime]'),
      metricNamespace: `${prefix}/Security`,
      metricName: 'UnauthorizedAccess',
      metricValue: '1',
    });

    // 出力
    new cdk.CfnOutput(this, 'AlertTopicArn', {
      value: this.alertTopic.topicArn,
      exportName: `${prefix}-alert-topic-arn`,
    });

    new cdk.CfnOutput(this, 'DashboardUrl', {
      value: `https://${this.region}.console.aws.amazon.com/cloudwatch/home?region=${this.region}#dashboards:name=${this.dashboard.dashboardName}`,
      exportName: `${prefix}-dashboard-url`,
    });
  }
}
