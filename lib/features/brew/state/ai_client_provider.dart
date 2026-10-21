import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/ai_client.dart';
import '../../auth/state/auth_providers.dart';

final aiClientProvider = Provider<AiClient>((ref) {
  final client = AiClient(sessionStorage: ref.watch(sessionStorageProvider));
  ref.onDispose(client.close);
  return client;
});
