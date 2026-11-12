import 'package:flutter/material.dart';

import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/domain/models/exam.dart';

/// Tile padronizado para exibição de provas em listas.
///
/// Componente prioritário e reconhecível conforme AGENTS.md §6.
/// Usado em: Home, Explorar, Biblioteca, Perfil, Busca.
class ExamListTile extends StatelessWidget {
  const ExamListTile({
    super.key,
    required this.exam,
    this.onTap,
    this.onLongPress,
    this.onSaveToggle,
    this.saved = false,
    this.showProgress = false,
    this.progress,
    this.state = ExamTileState.idle,
    this.compact = false,
    this.heroTag,
  });

  final Exam exam;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSaveToggle;
  final bool saved;
  final bool showProgress;
  final double? progress; // 0.0 a 1.0
  final ExamTileState state;
  final bool compact;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = _ExamListTileContent(
      exam: exam,
      saved: saved,
      showProgress: showProgress,
      progress: progress,
      state: state,
      compact: compact,
      isDark: isDark,
      onSaveToggle: onSaveToggle,
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: Material(
          color: Colors.transparent,
          child: _buildTile(context, content),
        ),
      );
    }

    return _buildTile(context, content);
  }

  Widget _buildTile(BuildContext context, Widget content) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: content,
      ),
    );
  }
}

class _ExamListTileContent extends StatelessWidget {
  const _ExamListTileContent({
    required this.exam,
    required this.saved,
    required this.showProgress,
    required this.progress,
    required this.state,
    required this.compact,
    required this.isDark,
    required this.onSaveToggle,
  });

  final Exam exam;
  final bool saved;
  final bool showProgress;
  final double? progress;
  final ExamTileState state;
  final bool compact;
  final bool isDark;
  final VoidCallback? onSaveToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = compact ? AppSpacing.sm : AppSpacing.md;

    return Padding(
      padding: EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, theme),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          _buildMetadata(context, theme),
          if (showProgress && progress != null) ...[
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            _buildProgress(context, theme),
          ],
          if (state != ExamTileState.idle) ...[
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            _buildStateBadge(context, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exam.logoUrl != null && !compact) ...[
          _buildLogo(theme),
          SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildActionButtons(context, theme),
                ],
              ),
          if (exam.year != null || exam.category.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              _buildSubtitle(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
            ],
          ),
        ),
      ],
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (exam.category.isNotEmpty) parts.add(exam.category);
    if (exam.year != null) parts.add('${exam.year}');
    if (exam.board != null) parts.add(exam.board!);
    if (exam.institution != null) parts.add(exam.institution!);
    if (exam.instance != null) parts.add(exam.instance!);
    return parts.join(' · ');
  }

  Widget _buildLogo(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: exam.logoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(
                exam.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.menu_book_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            )
          : Icon(
              Icons.menu_book_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSaveToggle != null) ...[
          IconButton(
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 20,
              color: saved
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onSaveToggle,
            tooltip: saved ? 'Remover dos salvos' : 'Salvar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
        if (state == ExamTileState.inProgress) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadata(BuildContext context, ThemeData theme) {
    final metadata = <Widget>[];

    // Questões e duração
    metadata.add(_MetadataChip(
      icon: Icons.quiz_outlined,
      label: '${exam.questions.length} questões',
      compact: compact,
    ));

    if (exam.durationMinutes > 0) {
      metadata.add(_MetadataChip(
        icon: Icons.timer_outlined,
        label: '${exam.durationMinutes} min',
        compact: compact,
      ));
    }

    // Disciplinas
    if (exam.topics.isNotEmpty) {
      metadata.add(_MetadataChip(
        icon: Icons.subject_outlined,
        label: exam.topics.take(2).join(', '),
        compact: compact,
        isEllipsis: exam.topics.length > 2,
      ));
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: metadata,
    );
  }

  Widget _buildProgress(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '${(progress! * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStateBadge(BuildContext context, ThemeData theme) {
    final (label, color) = switch (state) {
      ExamTileState.inProgress => ('Em andamento', theme.colorScheme.primary),
      ExamTileState.completed => ('Concluída', EmeraldColors.primary),
      ExamTileState.saved => ('Salva', theme.colorScheme.secondary),
      _ => ('', theme.colorScheme.onSurfaceVariant),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.icon,
    required this.label,
    this.compact = false,
    this.isEllipsis = false,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool isEllipsis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              overflow: isEllipsis ? TextOverflow.ellipsis : TextOverflow.visible,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estados possíveis do tile.
enum ExamTileState {
  idle,
  inProgress,
  completed,
  saved,
}

/// Dados de tópicos para o tile.
extension ExamTopics on Exam {
  List<String> get topics {
    // Se o modelo tiver topics, usar; senão extrair das questões
    final topics = <String>{};
    for (final q in questions) {
      if (q.topic.trim().isNotEmpty) {
        topics.add(q.topic.trim());
      }
    }
    return topics.toList();
  }

  String? get logoUrl {
    // Placeholder para URL do logo/brasão
    // Em produção, viria do Storage ou CDN
    return null;
  }
}