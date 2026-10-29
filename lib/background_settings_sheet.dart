import 'package:flutter/material.dart';
import 'app_strings.dart';
import 'app_themes.dart';
import 'theme_controller.dart';
import 'seasonal_background.dart';

String themeName(AppThemeDefinition theme) =>
    AppStrings.isKo ? theme.nameKo : theme.nameEn;

class ThemeSettingsSheet extends StatefulWidget {
  const ThemeSettingsSheet({super.key, required this.controller});
  final ThemeController controller;
  @override
  State<ThemeSettingsSheet> createState() => _ThemeSettingsSheetState();
}

class _ThemeSettingsSheetState extends State<ThemeSettingsSheet> {
  String? _error;
  Future<void> _select(ThemeSelection selection) async {
    setState(() => _error = null);
    try {
      await widget.controller.select(selection);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.backgroundSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final selection = controller.selection;
      // Captured modal themes must also update immediately while this sheet is open.
      return Theme(
        data: controller.current.buildTheme(),
        child: Builder(
          builder: (context) {
            final colors = Theme.of(context).colorScheme;
            return Material(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.backgroundSettings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        key: const ValueKey('theme-automatic'),
                        selected: selection.automatic,
                        enabled: !controller.saving,
                        leading: Icon(
                          selection.automatic
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(AppStrings.themeAutomatic),
                        subtitle: Text(
                          AppStrings.backgroundCurrent(
                            themeName(
                              AppThemes.byId(controller.currentSeasonId),
                            ),
                          ),
                        ),
                        onTap: () =>
                            _select(ThemeSelection(motion: selection.motion)),
                      ),
                      for (final group
                          in AppThemes.all.map((t) => t.group).toSet()) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            group == 'season'
                                ? AppStrings.themeSeasonGroup
                                : AppStrings.themeOtherGroup,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth >= 330 &&
                                    MediaQuery.textScalerOf(context).scale(14) <
                                        23
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final theme in AppThemes.all.where(
                                  (t) => t.group == group,
                                ))
                                  SizedBox(
                                    width: width,
                                    child: _tile(
                                      context,
                                      theme,
                                      !selection.automatic &&
                                          selection.themeId == theme.id,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(AppStrings.backgroundMotion),
                        value: selection.motion,
                        onChanged:
                            controller.saving ||
                                !controller.current.background.animated
                            ? null
                            : (value) => _select(
                                ThemeSelection(
                                  automatic: selection.automatic,
                                  themeId: selection.themeId,
                                  motion: value,
                                ),
                              ),
                      ),
                      if (MediaQuery.of(context).disableAnimations)
                        Text(AppStrings.backgroundReducedMotion),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                          semanticsLabel: _error,
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppStrings.backgroundClose),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
  Widget _tile(BuildContext context, AppThemeDefinition theme, bool selected) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: themeName(theme),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme-${theme.id}'),
          onTap: widget.controller.saving
              ? null
              : () => _select(
                  ThemeSelection(
                    automatic: false,
                    themeId: theme.id,
                    motion: widget.controller.selection.motion,
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    height: 58,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ThemeBackground(
                        design: theme.background,
                        motion: false,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 12,
                            color: theme.chrome,
                            alignment: Alignment.center,
                            child: Container(
                              width: 36,
                              height: 5,
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(themeName(theme))),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
