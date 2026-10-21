import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/state_views.dart';
import '../../data/repositories/feedback_repo.dart';
import '../auth/state/session_controller.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _suggestion = TextEditingController();
  final _impression = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _validation;
  List<Map<String, Object?>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _suggestion.dispose();
    _impression.dispose();
    super.dispose();
  }

  String? get _userId =>
      ref.read(sessionControllerProvider).asData?.value.userId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final rows = await (await ref.read(
        feedbackRepositoryProvider.future,
      )).history(userId);
      if (mounted) {
        setState(() {
          _history = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Riwayat saran dan kesan gagal dimuat.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_saving) return;
    if (_suggestion.text.trim().isEmpty && _impression.text.trim().isEmpty) {
      setState(() => _validation = 'Isi minimal satu kolom.');
      return;
    }
    setState(() {
      _saving = true;
      _validation = null;
    });
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final repository = await ref.read(feedbackRepositoryProvider.future);
      await repository.save(
        userId: userId,
        suggestion: _suggestion.text,
        impression: _impression.text,
      );
      final rows = await repository.history(userId);
      if (!mounted) return;
      _suggestion.clear();
      _impression.clear();
      setState(() => _history = rows);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saran dan kesan tersimpan.')),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _validation = 'Saran dan kesan gagal disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView(message: 'Memuat saran dan kesan...');
    }
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: AppInsets.screen,
        children: [
          Text(
            'Saran & Kesan',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text('Untuk mata kuliah Pemrograman Aplikasi Mobile.'),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _suggestion,
                  label: 'Saran',
                  maxLines: 4,
                  maxLength: FeedbackRepository.maxLength,
                ),
                const SizedBox(height: AppSpacing.s12),
                AppTextField(
                  controller: _impression,
                  label: 'Kesan',
                  maxLines: 4,
                  maxLength: FeedbackRepository.maxLength,
                ),
                if (_validation != null)
                  Text(
                    _validation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s8),
                AppButton(
                  label: 'Kirim',
                  isLoading: _saving,
                  onPressed: _saving ? null : _send,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Text(
            'Riwayat kiriman',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_history.isEmpty)
            const EmptyView(message: 'Belum ada saran atau kesan yang dikirim.')
          else
            for (final item in _history) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(context, item['created_at'] as String),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (item['suggestion'] != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text('Saran: ${item['suggestion']}'),
                    ],
                    if (item['impression'] != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text('Kesan: ${item['impression']}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
        ],
      ),
    );
  }

  String _date(BuildContext context, String utc) {
    final local = DateTime.tryParse(utc)?.toLocal();
    return local == null
        ? 'Tanggal tidak tersedia'
        : MaterialLocalizations.of(context).formatMediumDate(local);
  }
}
