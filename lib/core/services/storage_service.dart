import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api/supabase_client.dart';

class StorageService {
  StorageService();

  Future<String> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=150';
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final fileExtension = file.path.split('.').last;
        final path = '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        
        await client.storage.from('avatars').upload(path, file);
        final publicUrl = client.storage.from('avatars').getPublicUrl(path);
        return publicUrl;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<String> uploadMaintenanceAttachment({
    required File file,
    required String requestId,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      // Return a simulated path or asset
      return 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?auto=format&fit=crop&q=80&w=400';
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final fileExtension = file.path.split('.').last;
        final path = '$requestId/attachment-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        await client.storage.from('maintenance-attachments').upload(path, file);
        final publicUrl = client.storage.from('maintenance-attachments').getPublicUrl(path);
        return publicUrl;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<String> uploadInsuranceDocument({
    required File file,
    required String userId,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return 'https://example.com/insurance/policy-doc.pdf';
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final fileExtension = file.path.split('.').last;
        final path = '$userId/policy-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        await client.storage.from('insurance-documents').upload(path, file);
        final publicUrl = client.storage.from('insurance-documents').getPublicUrl(path);
        return publicUrl;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
