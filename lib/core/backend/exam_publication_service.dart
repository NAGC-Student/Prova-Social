import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'digital_exam_service.dart';
import 'exam_media_repository.dart';
import '../import/question_parser.dart';
import '../publish/exam_publication_contract.dart';

class ExamPublicationService {
  ExamPublicationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> publish({
    required String title,
    required String category,
    required String source,
    required int durationMinutes,
    required List<ImportedQuestion> questions,
    int? year,
    String? sourceUrl,
    String? board,
    String? institution,
    String? instance,
    List<ExamMediaInput> media = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre na conta para publicar.');
    }

    final normalizedSourceUrl = ExamPublicationContract.normalizeSourceUrl(
      sourceUrl,
    );
    final metadataError = ExamPublicationContract.metadataError(
      title: title,
      category: category,
      source: source,
      durationMinutes: durationMinutes,
      year: year,
      sourceUrl: normalizedSourceUrl,
      board: board,
      institution: institution,
      instance: instance,
    );
    if (metadataError != null) {
      throw FormatException(metadataError);
    }
    final questionsError = ExamPublicationContract.questionsError(
      questions,
      allowOpenEnded: false,
    );
    if (questionsError != null) {
      throw FormatException(questionsError);
    }
    final questionPayload = ExamPublicationContract.questionPayload(
      questions,
      includeOpenEnded: false,
    );
    final params = <String, dynamic>{
      'p_title': title.trim(),
      'p_category': category.trim(),
      'p_source': source.trim(),
      'p_source_type': 'community',
      'p_year': year,
      'p_duration_minutes': durationMinutes,
      'p_questions': questionPayload,
    };
    final normalizedBoard = _normalizeMetadata(board);
    final normalizedInstitution = _normalizeMetadata(institution);
    final normalizedInstance = _normalizeMetadata(instance);
    final hasIdentityMetadata =
        normalizedBoard != null ||
        normalizedInstitution != null ||
        normalizedInstance != null;
    if (media.length > 900 ||
        media.fold<int>(0, (size, entry) => size + entry.bytes.length) >
            12 * 1024 * 1024 ||
        media.any(
          (entry) =>
              entry.questionPosition < 1 ||
              entry.questionPosition > questions.length,
        )) {
      throw const FormatException('As imagens associadas excedem os limites.');
    }
    final mediaRepository = ExamMediaRepository(client: _client);
    final prepared = <PreparedExamMediaAsset>[];
    String examId;
    try {
      if (media.isEmpty) {
        if (hasIdentityMetadata) {
          examId = await _client.rpc<String>(
            'publish_exam_with_metadata',
            params: _metadataParams(
              params,
              sourceUrl: normalizedSourceUrl,
              board: normalizedBoard,
              institution: normalizedInstitution,
              instance: normalizedInstance,
              media: const [],
            ),
          );
        } else {
          examId = normalizedSourceUrl == null
              ? await _client.rpc<String>('publish_exam', params: params)
              : await _client.rpc<String>(
                  'publish_exam_with_source_url',
                  params: {...params, 'p_source_url': normalizedSourceUrl},
                );
        }
      } else {
        final manifest = <Map<String, Object?>>[];
        for (final entry in media) {
          final asset = await mediaRepository.prepareAsset(entry);
          prepared.add(asset);
          manifest.add({
            'asset_id': asset.asset['id'],
            'question_position': entry.questionPosition,
            'role': 'question_figure',
            'alt_text': entry.altText,
          });
        }
        if (hasIdentityMetadata) {
          examId = await _client.rpc<String>(
            'publish_exam_with_metadata',
            params: _metadataParams(
              params,
              sourceUrl: normalizedSourceUrl,
              board: normalizedBoard,
              institution: normalizedInstitution,
              instance: normalizedInstance,
              media: manifest,
            ),
          );
        } else {
          try {
            examId = await _client.rpc<String>(
              'publish_exam_with_media',
              params: {
                ...params,
                'p_source_url': normalizedSourceUrl,
                'p_media': manifest,
              },
            );
          } on PostgrestException catch (error) {
            if (error.code != 'PGRST202') rethrow;
            // Older projects have the safe text publication RPC but not the
            // media transaction yet. Preserve their ability to publish while
            // the additive migration is pending.
            examId = normalizedSourceUrl == null
                ? await _client.rpc<String>('publish_exam', params: params)
                : await _client.rpc<String>(
                    'publish_exam_with_source_url',
                    params: {...params, 'p_source_url': normalizedSourceUrl},
                  );
            try {
              for (final entry in media) {
                await mediaRepository.attach(examId: examId, media: entry);
              }
            } catch (_) {
              throw PublishedMediaAttachmentException(examId);
            }
          }
        }
      }
    } catch (_) {
      for (final asset in prepared.reversed) {
        try {
          await mediaRepository.discardIfUnattached(asset);
        } catch (cleanupError) {
          debugPrint(
            '[PUBLICATION_MEDIA_CLEANUP] falhou: ${cleanupError.runtimeType}',
          );
        }
      }
      rethrow;
    }

    // The relational publication is authoritative and remains usable if a
    // package cannot be created. New downloads prefer this compressed copy.
    try {
      final questionRows = List<Map<String, dynamic>>.from(
        await _client
            .from('questions')
            .select('id,position')
            .eq('exam_id', examId)
            .order('position'),
      );
      if (questionRows.length != questions.length) {
        throw const FormatException('Não foi possível indexar as questões.');
      }
      final packageQuestions = [
        for (var index = 0; index < questions.length; index++)
          {
            'id': questionRows[index]['id'],
            'position': index + 1,
            ...questionPayload[index],
          }..remove('correct_index'),
      ];
      await DigitalExamService(client: _client).upload(
        examId: examId,
        manifest: {
          'title': title.trim(),
          'category': category.trim(),
          'sourceName': source.trim(),
          'sourceType': 'community',
          'sourceUrl': normalizedSourceUrl,
          'year': year,
          'board': normalizedBoard,
          'institution': normalizedInstitution,
          'instance': normalizedInstance,
          'durationMinutes': durationMinutes,
        },
        questions: packageQuestions,
        media: media,
      );
    } catch (error) {
      debugPrint('[PUBLICATION_PACKAGE] falhou: ${error.runtimeType}');
    }
    return examId;
  }

  static String? _normalizeMetadata(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static Map<String, Object?> _metadataParams(
    Map<String, dynamic> params, {
    required String? sourceUrl,
    required String? board,
    required String? institution,
    required String? instance,
    required List<Map<String, Object?>> media,
  }) => {
    ...params,
    'p_source_url': sourceUrl,
    'p_board': board,
    'p_institution': institution,
    'p_instance': instance,
    'p_media': media,
  };
}

/// The legacy publication RPC cannot atomically create media links. This is
/// surfaced separately so the UI never suggests retrying a proof already made
/// public if one of the legacy link writes failed.
class PublishedMediaAttachmentException implements Exception {
  const PublishedMediaAttachmentException(this.examId);
  final String examId;
}
