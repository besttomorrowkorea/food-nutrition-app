import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    ref.read(chatProvider.notifier).sendMessage(text);

    // 스크롤 아래로
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 건강 코치'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(chatProvider.notifier).clearHistory(),
              icon: const Icon(Icons.refresh),
              tooltip: '대화 초기화',
            ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: chat.messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(chat),
          ),

          // 에러 메시지
          if (chat.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Text(
                chat.errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),

          // 입력 영역
          _buildInputArea(chat.isLoading),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              '운동이나 영양에 대해\n무엇이든 물어보세요!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('팔 운동 루틴 짜줘'),
                _buildSuggestionChip('다이어트 식단 추천해줘'),
                _buildSuggestionChip('하체 운동 루틴 알려줘'),
                _buildSuggestionChip('단백질 많은 음식 뭐야?'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 13)),
      backgroundColor: Colors.green.shade50,
      side: BorderSide(color: Colors.green.shade200),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageList(ChatState chat) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 로딩 인디케이터 (마지막)
        if (index == chat.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('AI가 답변을 작성하고 있습니다...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final msg = chat.messages[index];
        final isUser = msg.role == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? Colors.green.shade600 : Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: SelectableText(
              msg.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 8, 8,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '운동이나 영양에 대해 물어보세요...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: isLoading ? null : _sendMessage,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
