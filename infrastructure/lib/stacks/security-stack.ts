import * as cdk from 'aws-cdk-lib';
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

export interface SecurityStackProps extends cdk.StackProps {
  prefix: string;
  api: apigateway.RestApi;
}

export class SecurityStack extends cdk.Stack {
  public readonly webAcl: wafv2.CfnWebACL;
  public readonly apiSecrets: secretsmanager.Secret;

  constructor(scope: Construct, id: string, props: SecurityStackProps) {
    super(scope, id, props);

    const { prefix, api } = props;

    // Secrets Manager - API秘密情報
    this.apiSecrets = new secretsmanager.Secret(this, 'ApiSecrets', {
      secretName: `${prefix}/api-secrets`,
      description: 'API secrets for Pixel Diary',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({
          signingKey: '',
          adminApiKey: '',
        }),
        generateStringKey: 'generatedKey',
        excludeCharacters: '/@"\\',
        passwordLength: 64,
      },
    });

    // WAF Web ACL
    this.webAcl = new wafv2.CfnWebACL(this, 'WebAcl', {
      name: `${prefix}-web-acl`,
      scope: 'REGIONAL',
      defaultAction: { allow: {} },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: `${prefix}-web-acl`,
        sampledRequestsEnabled: true,
      },
      rules: [
        // AWS マネージドルール - 共通ルールセット
        {
          name: 'AWS-AWSManagedRulesCommonRuleSet',
          priority: 1,
          overrideAction: { none: {} },
          statement: {
            managedRuleGroupStatement: {
              vendorName: 'AWS',
              name: 'AWSManagedRulesCommonRuleSet',
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'AWS-AWSManagedRulesCommonRuleSet',
            sampledRequestsEnabled: true,
          },
        },
        // SQLインジェクション対策
        {
          name: 'AWS-AWSManagedRulesSQLiRuleSet',
          priority: 2,
          overrideAction: { none: {} },
          statement: {
            managedRuleGroupStatement: {
              vendorName: 'AWS',
              name: 'AWSManagedRulesSQLiRuleSet',
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'AWS-AWSManagedRulesSQLiRuleSet',
            sampledRequestsEnabled: true,
          },
        },
        // 既知の不正入力対策
        {
          name: 'AWS-AWSManagedRulesKnownBadInputsRuleSet',
          priority: 3,
          overrideAction: { none: {} },
          statement: {
            managedRuleGroupStatement: {
              vendorName: 'AWS',
              name: 'AWSManagedRulesKnownBadInputsRuleSet',
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'AWS-AWSManagedRulesKnownBadInputsRuleSet',
            sampledRequestsEnabled: true,
          },
        },
        // Bot対策（開発環境ではカウントのみ）
        {
          name: 'AWS-AWSManagedRulesBotControlRuleSet',
          priority: 4,
          overrideAction: { count: {} }, // 開発用：ブロックせずログのみ
          statement: {
            managedRuleGroupStatement: {
              vendorName: 'AWS',
              name: 'AWSManagedRulesBotControlRuleSet',
              managedRuleGroupConfigs: [
                {
                  awsManagedRulesBotControlRuleSet: {
                    inspectionLevel: 'COMMON',
                  },
                },
              ],
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'AWS-AWSManagedRulesBotControlRuleSet',
            sampledRequestsEnabled: true,
          },
        },
        // レート制限ルール（IP単位）
        {
          name: 'RateLimitRule',
          priority: 5,
          action: { block: {} },
          statement: {
            rateBasedStatement: {
              limit: 1000, // 5分間で1000リクエスト
              aggregateKeyType: 'IP',
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'RateLimitRule',
            sampledRequestsEnabled: true,
          },
        },
        // リクエストサイズ制限
        {
          name: 'RequestSizeLimit',
          priority: 6,
          action: { block: {} },
          statement: {
            sizeConstraintStatement: {
              fieldToMatch: { body: { oversizeHandling: 'MATCH' } },
              comparisonOperator: 'GT',
              size: 10240, // 10KB
              textTransformations: [{ priority: 0, type: 'NONE' }],
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: 'RequestSizeLimit',
            sampledRequestsEnabled: true,
          },
        },
        // 日本以外からのアクセスをブロック（オプション）
        // 必要に応じてコメントを外す
        // {
        //   name: 'GeoBlockRule',
        //   priority: 7,
        //   action: { block: {} },
        //   statement: {
        //     notStatement: {
        //       statement: {
        //         geoMatchStatement: {
        //           countryCodes: ['JP'],
        //         },
        //       },
        //     },
        //   },
        //   visibilityConfig: {
        //     cloudWatchMetricsEnabled: true,
        //     metricName: 'GeoBlockRule',
        //     sampledRequestsEnabled: true,
        //   },
        // },
      ],
    });

    // WAFをAPI Gatewayに関連付け
    new wafv2.CfnWebACLAssociation(this, 'WebAclAssociation', {
      resourceArn: `arn:aws:apigateway:${this.region}::/restapis/${api.restApiId}/stages/${api.deploymentStage.stageName}`,
      webAclArn: this.webAcl.attrArn,
    });

    // 出力
    new cdk.CfnOutput(this, 'WebAclArn', {
      value: this.webAcl.attrArn,
      exportName: `${prefix}-web-acl-arn`,
    });

    new cdk.CfnOutput(this, 'ApiSecretsArn', {
      value: this.apiSecrets.secretArn,
      exportName: `${prefix}-api-secrets-arn`,
    });
  }
}
