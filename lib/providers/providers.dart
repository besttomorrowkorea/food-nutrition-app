import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/nutrition_result.dart';
import '../repositories/nutrition_repository.dart';
import '../services/nutrition_service.dart';
import '../services/chat_service.dart';

// ─── Firebase Auth ───────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

// ─── Repository ──────────────────────────────────────────────────

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => FirestoreNutritionRepository(),
);

// ─── Services ────────────────────────────────────────────────────

final nutritionServiceProvider = Provider<NutritionService>(
  (ref) => NutritionService(),
);

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(),
);

// ─── 영양 분석 상태 ───────────────────────────────────────────────

enum AnalysisStatus { idle, analyzing, success, error }

class AnalysisState {
  final AnalysisStatus status;
  final NutritionResult? result;
  final String? errorMessage;
  final bool isRetryable;

  const AnalysisState({
    this.status = AnalysisStatus.idle,
    this.result,
    this.errorMessage,
    this.isRetryable = false,
  });

  AnalysisState copyWith({
    AnalysisStatus? status,
    NutritionResult? result,
    String? errorMessage,
    bool? isRetryable,
  }) =>
      AnalysisState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        isRetryable: isRetryable ?? this.isRetryable,
      );
}

class AnalysisNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => const AnalysisState();

  Future<void> analyze(XFile imageFile) async {
    // 더블탭 방지: 이미 분석 중이면 무시
    if (state.status == AnalysisStatus.analyzing) return;

    state = state.copyWith(
      status: AnalysisStatus.analyzing,
      errorMessage: null,
    );

    try {
      final service = ref.read(nutritionServiceProvider);
      final result = await service.analyzeFood(File(imageFile.path));
      state = state.copyWith(
        status: AnalysisStatus.success,
        result: result,
      );
    } on FoodNotRecognizedException catch (e) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: e.message,
        isRetryable: false,
      );
    } catch (e) {
      final msg = e.toString();
      final isRetryable = msg.contains('timeout') ||
          msg.contains('DEADLINE_EXCEEDED') ||
          msg.contains('resource-exhausted');
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: _userFriendlyError(msg),
        isRetryable: isRetryable,
      );
    }
  }

  void reset() => state = const AnalysisState();

  String _userFriendlyError(String raw) {
    if (raw.contains('unauthenticated')) return '로그인이 필요합니다.';
    if (raw.contains('resource-exhausted')) return '일일 분석 한도에 도달했습니다. 내일 다시 시도해주세요.';
    if (raw.contains('timeout') || raw.contains('DEADLINE_EXCEEDED')) {
      return '분석 시간이 초과되었습니다. 다시 시도해주세요.';
    }
    return '분석에 실패했습니다. 다시 시도해주세요.';
  }
}

final analysisProvider = NotifierProvider<AnalysisNotifier, AnalysisState>(
  AnalysisNotifier.new,
);

// ─── 채팅 상태 ────────────────────────────────────────────────────

class ChatMessage {
  final String role; // user / assistant
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  Future<void> sendMessage(String message, {Map<String, dynamic>? context}) async {
    if (state.isLoading) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      errorMessage: null,
    );

    try {
      final service = ref.read(chatServiceProvider);
      final history = state.messages
          .take(state.messages.length - 1) // 방금 추가한 메시지 제외
          .map((m) => m.toJson())
          .toList();

      final reply = await service.chat(
        message: message,
        context: {
          ...?context,
          'chatHistory': history,
        },
      );

      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'AI 응답에 실패했습니다. 다시 시도해주세요.',
      );
    }
  }

  void clearHistory() => state = const ChatState();
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
