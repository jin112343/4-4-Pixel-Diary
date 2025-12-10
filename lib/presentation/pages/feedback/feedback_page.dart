import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/logger.dart';

/// お問い合わせ・改善意見画面
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  FeedbackType _selectedType = FeedbackType.bug;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お問い合わせ・改善意見'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 種類選択
              const Text(
                '種類',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<FeedbackType>(
                segments: const [
                  ButtonSegment(
                    value: FeedbackType.bug,
                    label: Text('バグ報告'),
                    icon: Icon(Icons.bug_report),
                  ),
                  ButtonSegment(
                    value: FeedbackType.improvement,
                    label: Text('改善提案'),
                    icon: Icon(Icons.lightbulb_outline),
                  ),
                  ButtonSegment(
                    value: FeedbackType.other,
                    label: Text('その他'),
                    icon: Icon(Icons.help_outline),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<FeedbackType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 件名
              const Text(
                '件名',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '簡潔にお書きください',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '件名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 内容
              const Text(
                '内容',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  hintText: '詳しくお書きください',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                maxLength: 1000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '内容を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 注意事項
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ご注意',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• メールアプリが起動します\n'
                      '• 個人を特定できる情報は記載しないでください\n'
                      '• 返信をお約束するものではありません',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 送信ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendFeedback,
                  icon: const Icon(Icons.send),
                  label: const Text('メールアプリで送信'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final typeLabel = _selectedType.label;
    final subject = '[$typeLabel] ${_titleController.text.trim()}';
    final body = _bodyController.text.trim();

    final emailUri = Uri(
      scheme: 'mailto',
      path: 'mizoijin@icloud.com',
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          _showErrorDialog('メールアプリを起動できませんでした');
        }
      }
    } catch (e, stackTrace) {
      logger.e('Failed to launch email', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showErrorDialog('エラーが発生しました');
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}

/// フィードバック種類
enum FeedbackType {
  bug('バグ報告'),
  improvement('改善提案'),
  other('その他');

  const FeedbackType(this.label);
  final String label;
}
