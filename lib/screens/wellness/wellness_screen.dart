import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/wellness.dart';
import '../../models/wellness_insights.dart';
import '../../provider/wellness_provider.dart';
import '../../services/wellness_sync_service.dart';
import '../../ui_components/app_ui_components.dart';
import '../../widgets/wellness_charts.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final GlobalKey _timeSectionKey = GlobalKey();
  final GlobalKey _titlesSectionKey = GlobalKey();
  final GlobalKey _tasteSectionKey = GlobalKey();
  final GlobalKey _patternsSectionKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final wellness = context.watch<WellnessProvider>();
    final insights = wellness.insights;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewing Insights'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Viewing Insights options',
            onPressed: () => _showInsightsActions(wellness),
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wellness.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: wellness.canSync ? wellness.syncNow : wellness.reload,
              child: AppResponsiveContent(
                maxWidth: 920,
                padding: EdgeInsets.zero,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppUI.pagePadding(context),
                    12,
                    AppUI.pagePadding(context),
                    40,
                  ),
                  children: [
                    if (wellness.shouldOfferGuestMerge)
                      _GuestMergeCard(provider: wellness),
                    _InsightsToolbar(
                      provider: wellness,
                    ),
                    const SizedBox(height: 18),
                    if (insights.isEmpty)
                      _WellnessEmptyState(
                        hasHistory: wellness.sessions.isNotEmpty,
                      )
                    else ...[
                      _HeroCard(
                        insights: insights,
                        previous: wellness.previousInsights,
                        range: wellness.range,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _trackingSince(wellness.sessions),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _sharing
                                ? null
                                : () => _openShareRecap(
                                      insights,
                                      wellness.range,
                                    ),
                            icon: _sharing
                                ? const SizedBox.square(
                                    dimension: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(PhosphorIcons.shareNetwork(), size: 18),
                            label: const Text('Share recap'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _StatGrid(insights: insights),
                      const SizedBox(height: 20),
                      _SectionNavigator(
                        onSelected: (section) =>
                            _jumpToSection(switch (section) {
                          _InsightsSection.time => _timeSectionKey,
                          _InsightsSection.titles => _titlesSectionKey,
                          _InsightsSection.taste => _tasteSectionKey,
                          _InsightsSection.patterns => _patternsSectionKey,
                        }),
                      ),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _timeSectionKey,
                        icon: PhosphorIcons.clockCounterClockwise(),
                        eyebrow: 'TIME',
                        title: 'Your viewing rhythm',
                        description:
                            'Active playback only—pauses and buffering are excluded.',
                      ),
                      const SizedBox(height: 14),
                      _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Watch time',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                Text(
                                  _duration(insights.totalWatchedMs),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            WellnessBarChart(
                              key: const Key('wellness-time-chart'),
                              data: _barData(insights, wellness.range),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MediaBreakdown(insights: insights),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _titlesSectionKey,
                        icon: PhosphorIcons.filmSlate(),
                        eyebrow: 'TITLES',
                        title: 'What held your attention',
                        description:
                            'Completed titles, returning favorites, and recent sessions.',
                      ),
                      const SizedBox(height: 14),
                      _RankedPanel(
                        title: 'Most watched',
                        values: insights.topTitles.take(5).toList(),
                        emptyMessage:
                            'More viewing will reveal your top titles.',
                      ),
                      const SizedBox(height: 14),
                      _HistoryPanel(
                          sessions: insights.sessions.take(8).toList()),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _tasteSectionKey,
                        icon: PhosphorIcons.palette(),
                        eyebrow: 'TASTE',
                        title: 'The shape of your taste',
                        description:
                            'Built from the metadata available when you watched.',
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 680;
                          final width = wide
                              ? (constraints.maxWidth - 14) / 2
                              : constraints.maxWidth;
                          final panels = <Widget>[
                            _RankedPanel(
                              title: 'Genres',
                              values: insights.topGenres.take(5).toList(),
                              emptyMessage:
                                  'Genre insights will appear as title metadata is collected.',
                            ),
                            _RankedPanel(
                              title: 'Languages',
                              values: insights.topLanguages.take(5).toList(),
                              emptyMessage:
                                  'Language insights will appear with enriched titles.',
                            ),
                            _RankedPanel(
                              title: 'Countries',
                              values: insights.topCountries.take(5).toList(),
                              emptyMessage:
                                  'Country insights will appear with enriched titles.',
                            ),
                            _RankedPanel(
                              title: 'Release decades',
                              values: insights.topDecades.take(5).toList(),
                              emptyMessage:
                                  'Release-era insights will appear after more viewing.',
                            ),
                            _RankedPanel(
                              title: 'Stream providers',
                              values: insights.topProviders.take(5).toList(),
                              emptyMessage:
                                  'Provider insights will appear after streaming sessions.',
                            ),
                          ];
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final panel in panels)
                                SizedBox(width: width, child: panel),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _patternsSectionKey,
                        icon: PhosphorIcons.calendarDots(),
                        eyebrow: 'PATTERNS',
                        title: 'When stories fit your day',
                        description:
                            'A private view of your own routine—not a score or a warning.',
                      ),
                      const SizedBox(height: 14),
                      _Panel(
                        child: WellnessHeatmap(
                          key: const Key('wellness-pattern-heatmap'),
                          values: insights.hourOfWeekMs,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InsightStrip(insights: insights),
                      const SizedBox(height: 26),
                      _PrivacyNote(canSync: wellness.canSync),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  void _jumpToSection(GlobalKey key) {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: .08,
    );
  }

  Future<void> _handleAction(
    WellnessProvider wellness,
    _WellnessAction action,
  ) async {
    switch (action) {
      case _WellnessAction.export:
        final json = await wellness.exportJson();
        final csv = await wellness.exportCsv();
        final directory = await getTemporaryDirectory();
        final jsonFile =
            File('${directory.path}/flixquest-viewing-insights.json');
        final csvFile =
            File('${directory.path}/flixquest-viewing-insights.csv');
        await jsonFile.writeAsString(json);
        await csvFile.writeAsString(csv);
        await Share.shareXFiles(
          <XFile>[
            XFile(jsonFile.path, mimeType: 'application/json'),
            XFile(csvFile.path, mimeType: 'text/csv'),
          ],
          text: 'My private FlixQuest Viewing Insights archive',
        );
      case _WellnessAction.clear:
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear viewing history?'),
            content: Text(
              wellness.canSync
                  ? 'This removes your viewing sessions from this device and every synced device. This cannot be undone.'
                  : 'This removes the viewing sessions stored on this device. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear history'),
              ),
            ],
          ),
        );
        if (confirmed == true) await wellness.clearHistory();
    }
  }

  Future<void> _showInsightsActions(WellnessProvider wellness) async {
    final action = await showModalBottomSheet<_WellnessAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => const _InsightsActionsSheet(),
    );
    if (action != null && mounted) await _handleAction(wellness, action);
  }

  Future<void> _openShareRecap(
    WellnessInsights insights,
    WellnessRange range,
  ) async {
    setState(() => _sharing = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareRecapSheet(
        insights: insights,
        range: range,
      ),
    );
    if (mounted) setState(() => _sharing = false);
  }
}

enum _WellnessAction { export, clear }

class _InsightsActionsSheet extends StatelessWidget {
  const _InsightsActionsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PhosphorIcons.slidersHorizontal(),
                  color: colors.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your insights data',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Export a copy or manage your history.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Icon(PhosphorIcons.x()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InsightsActionTile(
            icon: PhosphorIcons.export(),
            title: 'Export my data',
            description: 'Download your sessions as JSON and CSV.',
            onTap: () => Navigator.pop(context, _WellnessAction.export),
          ),
          const SizedBox(height: 10),
          _InsightsActionTile(
            icon: PhosphorIcons.trash(),
            title: 'Clear viewing history',
            description: 'Remove all locally stored and synced sessions.',
            destructive: true,
            onTap: () => Navigator.pop(context, _WellnessAction.clear),
          ),
        ],
      ),
    );
  }
}

class _InsightsActionTile extends StatelessWidget {
  const _InsightsActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = destructive ? colors.error : colors.primary;
    return Material(
      color: destructive
          ? colors.errorContainer.withValues(alpha: .32)
          : _insightSurface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: destructive ? colors.error : null,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                PhosphorIcons.caretRight(),
                color: destructive ? colors.error : colors.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecapStyle { light, dark, lightsOut }

class _ShareRecapSheet extends StatefulWidget {
  const _ShareRecapSheet({required this.insights, required this.range});

  final WellnessInsights insights;
  final WellnessRange range;

  @override
  State<_ShareRecapSheet> createState() => _ShareRecapSheetState();
}

class _ShareRecapSheetState extends State<_ShareRecapSheet> {
  final GlobalKey _recapKey = GlobalKey();
  late _RecapStyle _style;
  bool _includeTopTitle = true;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted || _styleInitialized) return;
    final theme = Theme.of(context);
    _style = theme.brightness == Brightness.light
        ? _RecapStyle.light
        : _isLightsOut(context)
            ? _RecapStyle.lightsOut
            : _RecapStyle.dark;
    _styleInitialized = true;
  }

  bool _styleInitialized = false;

  String get _caption {
    final insights = widget.insights;
    final title = _includeTopTitle && insights.topTitles.isNotEmpty
        ? ' My most-watched title was ${insights.topTitles.first.label}.'
        : '';
    return 'My ${_rangeLabel(widget.range).toLowerCase()} on FlixQuest: '
        '${_duration(insights.totalWatchedMs)} of stories across '
        '${insights.activeDays} active ${insights.activeDays == 1 ? 'day' : 'days'}.$title';
  }

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: _caption));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied')),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _recapKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Recap preview is not ready');
      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Could not render recap image');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/flixquest-viewing-recap.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'image/png')],
        subject: 'My FlixQuest viewing recap',
        text: _caption,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the recap. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        minChildSize: .65,
        maxChildSize: .96,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share your viewing story',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a look, control the details, then share.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(PhosphorIcons.x()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'FLIXQUEST THEMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'FigtreeSB',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RecapStyleChip(
                    label: 'Light',
                    colors: const [Color(0xFFFAF9FC), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.light,
                    onTap: () => setState(() => _style = _RecapStyle.light),
                  ),
                  const SizedBox(width: 8),
                  _RecapStyleChip(
                    label: 'Dark',
                    colors: const [Color(0xFF181A1D), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.dark,
                    onTap: () => setState(() => _style = _RecapStyle.dark),
                  ),
                  const SizedBox(width: 8),
                  _RecapStyleChip(
                    label: 'Lights out',
                    colors: const [Color(0xFF000000), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.lightsOut,
                    onTap: () => setState(() => _style = _RecapStyle.lightsOut),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: RepaintBoundary(
                  key: _recapKey,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: 380,
                        height: 475,
                        child: _ShareRecapCard(
                          insights: widget.insights,
                          range: widget.range,
                          style: _style,
                          includeTopTitle: _includeTopTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: _insightSurface(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: SwitchListTile.adaptive(
                value: _includeTopTitle,
                onChanged: (value) => setState(() => _includeTopTitle = value),
                secondary: Icon(PhosphorIcons.eye()),
                title: const Text('Include my top title'),
                subtitle: const Text('Turn this off for a more private recap.'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyCaption,
                    icon: Icon(PhosphorIcons.copy(), size: 18),
                    label: const Text('Copy caption'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : _shareImage,
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(PhosphorIcons.shareNetwork(), size: 18),
                    label: Text(_sharing ? 'Creating…' : 'Share image'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapStyleChip extends StatelessWidget {
  const _RecapStyleChip({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : _insightSurface(context, raised: true),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 13, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontFamily: selected ? 'FigtreeSB' : 'Figtree',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  PhosphorIcons.checkCircle(),
                  size: 17,
                  color: scheme.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareRecapCard extends StatelessWidget {
  const _ShareRecapCard({
    required this.insights,
    required this.range,
    required this.style,
    required this.includeTopTitle,
  });

  final WellnessInsights insights;
  final WellnessRange range;
  final _RecapStyle style;
  final bool includeTopTitle;

  @override
  Widget build(BuildContext context) {
    const appAccent = Color(0xFFF57C00);
    final palette = switch (style) {
      _RecapStyle.light => (
          const Color(0xFFFAF9FC),
          const Color(0xFFF1EDF6),
          const Color(0xFFEAE3F2),
          appAccent,
          const Color(0xFF211D26),
        ),
      _RecapStyle.dark => (
          const Color(0xFF272A2E),
          const Color(0xFF181A1D),
          const Color(0xFF101113),
          appAccent,
          Colors.white,
        ),
      _RecapStyle.lightsOut => (
          Colors.black,
          const Color(0xFF080808),
          const Color(0xFF131313),
          appAccent,
          Colors.white,
        ),
    };
    final foreground = palette.$5;
    final bars = _recapBarData(insights, range);
    final maxBar =
        bars.fold<int>(0, (max, item) => item.value > max ? item.value : max);
    final topTitle = insights.topTitles.firstOrNull?.label;
    final topGenre = insights.topGenres.firstOrNull?.label;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.$1, palette.$2, palette.$3],
          stops: const [0, .55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -70,
            top: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: foreground.withValues(alpha: .09),
                  width: 44,
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: 80,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.$4.withValues(alpha: .08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'FLIXQUEST',
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'FigtreeSB',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: foreground.withValues(alpha: .13),
                        ),
                      ),
                      child: Text(
                        _rangeLabel(range).toUpperCase(),
                        style: TextStyle(
                          color: foreground,
                          fontFamily: 'FigtreeSB',
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  'MY VIEWING\nSTORY',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .7),
                    fontFamily: 'FigtreeSB',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    height: 1.12,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _duration(insights.totalWatchedMs),
                  style: TextStyle(
                    color: foreground,
                    fontFamily: 'FigtreeBlack',
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: .98,
                    fontSize: 45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'of active playback',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .76),
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (includeTopTitle && topTitle != null) ...[
                  Text(
                    'MOST WATCHED',
                    style: TextStyle(
                      color: palette.$4,
                      fontFamily: 'FigtreeSB',
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (topGenre != null)
                    Text(
                      'Top genre • $topGenre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .62),
                        fontFamily: 'Figtree',
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.completedTitles}',
                        label: 'completed',
                        foreground: foreground,
                      ),
                    ),
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.activeDays}',
                        label: 'active days',
                        foreground: foreground,
                      ),
                    ),
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.sessionCount}',
                        label: 'sessions',
                        foreground: foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 42,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bar in bars)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: maxBar == 0
                                          ? .08
                                          : .12 + .88 * (bar.value / maxBar),
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: bar.value == maxBar
                                              ? palette.$4
                                              : foreground.withValues(
                                                  alpha: .26,
                                                ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  bar.label,
                                  style: TextStyle(
                                    color: foreground.withValues(alpha: .58),
                                    fontFamily: 'Figtree',
                                    fontSize: 7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(PhosphorIcons.lockKey(),
                        color: foreground.withValues(alpha: .52), size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'Active playback only • Pauses excluded',
                      style: TextStyle(
                        color: foreground.withValues(alpha: .52),
                        fontFamily: 'Figtree',
                        fontSize: 8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat.yMMMd().format(DateTime.now()),
                      style: TextStyle(
                        color: foreground.withValues(alpha: .52),
                        fontFamily: 'Figtree',
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapMetric extends StatelessWidget {
  const _RecapMetric({
    required this.value,
    required this.label,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: foreground,
            fontFamily: 'FigtreeSB',
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: foreground.withValues(alpha: .6),
            fontFamily: 'Figtree',
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class WellnessPreviewCard extends StatelessWidget {
  const WellnessPreviewCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WellnessProvider>();
    final insights = WellnessInsights.fromSessions(
      provider.sessions,
      period: WellnessPeriod.forRange(WellnessRange.week, DateTime.now()),
    );
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .72),
            colors.tertiaryContainer.withValues(alpha: .42),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('wellness-profile-card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(PhosphorIcons.chartDonut(), color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viewing Insights',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        insights.isEmpty
                            ? 'Your private viewing insights start here'
                            : '${_duration(insights.totalWatchedMs)} this week • ${insights.completedTitles} completed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: .7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.caretRight(), size: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsToolbar extends StatelessWidget {
  const _InsightsToolbar({required this.provider});

  final WellnessProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = provider.syncService.status.value;
    final syncing = status == WellnessSyncStatus.syncing;
    final statusLabel = !provider.canSync
        ? 'On this device'
        : syncing
            ? 'Syncing…'
            : status == WellnessSyncStatus.error
                ? 'Sync paused'
                : provider.syncService.lastSynced.value == null
                    ? 'Ready to sync'
                    : 'Synced ${_relativeTime(provider.syncService.lastSynced.value!)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  provider.canSync
                      ? PhosphorIcons.cloudCheck()
                      : PhosphorIcons.deviceMobile(),
                  size: 18,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your private viewing story',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: status == WellnessSyncStatus.error
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (provider.canSync)
                IconButton.filledTonal(
                  tooltip: 'Sync now',
                  onPressed: syncing ? null : provider.syncNow,
                  icon: syncing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(PhosphorIcons.arrowsClockwise(), size: 19),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _RangePicker(
            selected: provider.range,
            onSelected: provider.setRange,
          ),
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.selected, required this.onSelected});

  final WellnessRange selected;
  final ValueChanged<WellnessRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = <WellnessRange, String>{
      WellnessRange.week: 'Week',
      WellnessRange.month: 'Month',
      WellnessRange.year: 'Year',
      WellnessRange.allTime: 'All time',
    };
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: WellnessRange.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final range = WellnessRange.values[index];
          final isSelected = selected == range;
          return ChoiceChip(
            label: Text(
              labels[range]!,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontFamily: isSelected ? 'FigtreeSB' : 'Figtree',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: _insightSurface(context, raised: true),
            selectedColor: Theme.of(context).colorScheme.primary,
            onSelected: (_) => onSelected(range),
          );
        },
      ),
    );
  }
}

enum _InsightsSection { time, titles, taste, patterns }

class _SectionNavigator extends StatelessWidget {
  const _SectionNavigator({required this.onSelected});

  final ValueChanged<_InsightsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(_InsightsSection, IconData, String)>[
      (_InsightsSection.time, PhosphorIcons.clock(), 'Time'),
      (_InsightsSection.titles, PhosphorIcons.filmSlate(), 'Titles'),
      (_InsightsSection.taste, PhosphorIcons.palette(), 'Taste'),
      (_InsightsSection.patterns, PhosphorIcons.calendarDots(), 'Patterns'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ActionChip(
            avatar: Icon(item.$2, size: 17),
            label: Text(
              item.$3,
              style: const TextStyle(
                fontFamily: 'FigtreeSB',
                fontWeight: FontWeight.w600,
              ),
            ),
            side: BorderSide.none,
            backgroundColor: _insightSurface(context, raised: true),
            onPressed: () => onSelected(item.$1),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.insights,
    required this.previous,
    required this.range,
  });

  final WellnessInsights insights;
  final WellnessInsights previous;
  final WellnessRange range;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rawGradient = <Color>[
      colors.primary,
      Color.lerp(colors.primary, colors.tertiary, .72)!,
      colors.tertiary,
    ];
    final foreground = _bestGradientForeground(rawGradient);
    final gradient = rawGradient
        .map((color) => _ensureTextContrast(color, foreground))
        .toList(growable: false);
    final foregroundIsLight = foreground.computeLuminance() > .5;
    final translucentSurface = foregroundIsLight
        ? Colors.white.withValues(alpha: .12)
        : Colors.white.withValues(alpha: .28);
    final difference = insights.totalWatchedMs - previous.totalWatchedMs;
    final comparison = range == WellnessRange.allTime
        ? 'Across ${insights.activeDays} viewing days'
        : previous.totalWatchedMs == 0
            ? 'Your story is taking shape'
            : '${_duration(difference.abs())} ${difference >= 0 ? 'more' : 'less'} than the previous ${_rangeName(range)}';
    return Container(
      key: const Key('wellness-hero-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -62,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 38,
                  color: foreground.withValues(alpha: .08),
                ),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -74,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: foreground.withValues(alpha: .055),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final headline = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: translucentSurface,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: foreground.withValues(alpha: .14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.sparkle(),
                                color: foreground,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'YOUR VIEWING STORY',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: foreground,
                                      letterSpacing: 1.05,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _duration(insights.totalWatchedMs),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.8,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'active playback this ${_rangeName(range)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground.withValues(alpha: .82),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(
                          previous.totalWatchedMs == 0
                              ? PhosphorIcons.sparkle()
                              : difference >= 0
                                  ? PhosphorIcons.trendUp()
                                  : PhosphorIcons.trendDown(),
                          color: foreground.withValues(alpha: .8),
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            comparison,
                            style: TextStyle(
                              color: foreground.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                final supporting = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroMetric(
                      value: '${insights.completedTitles}',
                      label: 'completed',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.activeDays}',
                      label: 'active days',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.sessionCount}',
                      label: 'sessions',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                  ],
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headline,
                      const SizedBox(height: 22),
                      supporting,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: headline),
                    const SizedBox(width: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: supporting,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.foreground,
    required this.surface,
  });

  final String value;
  final String label;
  final Color foreground;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground.withValues(alpha: .74),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final stats = <(IconData, String, String)>[
      (PhosphorIcons.filmSlate(), '${insights.completedMovies}', 'movies'),
      (PhosphorIcons.television(), '${insights.completedEpisodes}', 'episodes'),
      (PhosphorIcons.stack(), '${insights.uniqueSeries}', 'series'),
      (PhosphorIcons.playCircle(), '${insights.sessionCount}', 'sessions'),
      (PhosphorIcons.calendarDots(), '${insights.activeDays}', 'active days'),
      (
        PhosphorIcons.arrowCounterClockwise(),
        '${insights.rewatches}',
        'rewatches'
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final colors = Theme.of(context).colorScheme;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < stats.length; index++)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 102),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: index == 0
                        ? colors.primaryContainer.withValues(alpha: .55)
                        : _insightSurface(context),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          stats[index].$1,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats[index].$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              stats[index].$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MediaBreakdown extends StatelessWidget {
  const _MediaBreakdown({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <(String, int, Color)>[
      ('Movies', insights.movieMs, colors.primary),
      ('Episodes', insights.episodeMs, colors.tertiary),
      ('Live TV', insights.liveMs, colors.secondary),
    ];
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = WellnessDonutChart(
            values: entries.map((entry) => entry.$2).toList(),
            colors: entries.map((entry) => entry.$3).toList(),
            centerLabel: 'Playback\nmix',
          );
          final legend = Column(
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: entry.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.$1)),
                      Text(_duration(entry.$2)),
                    ],
                  ),
                ),
            ],
          );
          return constraints.maxWidth > 520
              ? Row(children: [
                  chart,
                  const SizedBox(width: 30),
                  Expanded(child: legend)
                ])
              : Column(children: [chart, const SizedBox(height: 18), legend]);
        },
      ),
    );
  }
}

class _RankedPanel extends StatelessWidget {
  const _RankedPanel({
    required this.title,
    required this.values,
    required this.emptyMessage,
  });

  final String title;
  final List<WellnessRankedValue> values;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1 : values.first.value;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          if (values.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < values.length; index++) ...[
              Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: index == 0 ? .9 : .45),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(values[index].label)),
                  Text(_duration(values[index].value)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: values[index].value / max,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
              ),
              if (index != values.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.sessions});

  final List<WellnessViewingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WellnessProvider>();
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Viewing history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${sessions.length} recent',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'Figtree',
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sessions.length; index++) ...[
          Material(
            color: index == 0
                ? colors.primaryContainer.withValues(alpha: .3)
                : _insightSurface(context),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: _HistoryRow(
                session: sessions[index],
                onDelete: () => provider.deleteSession(sessions[index].id),
              ),
            ),
          ),
          if (index != sessions.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.onDelete});

  final WellnessViewingSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (session.mediaType) {
      WellnessMediaType.movie => PhosphorIcons.filmSlate(),
      WellnessMediaType.episode => PhosphorIcons.television(),
      WellnessMediaType.live => PhosphorIcons.broadcast(),
    };
    final localStart = session.startedAtUtc
        .add(Duration(minutes: session.timezoneOffsetMinutes));
    final hasProgress =
        session.mediaType != WellnessMediaType.live && session.durationMs > 0;
    final statusColor = session.completed ? colors.primary : colors.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: .16),
                colors.tertiary.withValues(alpha: .1),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 21, color: colors.primary),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'FigtreeSB',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (session.subtitle?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  session.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _HistoryMeta(
                    icon: PhosphorIcons.calendarBlank(),
                    label: DateFormat.MMMd().add_jm().format(localStart),
                  ),
                  _HistoryMeta(
                    icon: PhosphorIcons.clock(),
                    label: _duration(session.watchedMs),
                  ),
                  _HistoryMeta(
                    icon: session.completed
                        ? PhosphorIcons.checkCircle()
                        : PhosphorIcons.playCircle(),
                    label: session.viewingStatus,
                    color: statusColor,
                  ),
                ],
              ),
              if (hasProgress) ...[
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 3,
                    backgroundColor: colors.onSurface.withValues(alpha: .07),
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove from insights',
          visualDensity: VisualDensity.compact,
          onPressed: () => _confirmDelete(context),
          icon: Icon(
            PhosphorIcons.trash(),
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this activity?'),
        content: Text(
          '${session.title} will no longer be included in your viewing insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) onDelete();
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: foreground),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontFamily: color == null ? 'Figtree' : 'FigtreeSB',
            fontSize: 11,
            fontWeight: color == null ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final peak = _peakHour(insights.hourOfWeekMs);
    final observations = <String>[
      'Your average active viewing day was ${_duration(insights.averageActiveDayMs)}.',
      if (peak != null)
        'Your most active window was ${peak.$1} around ${peak.$2}.',
      if (insights.longestSessionMs > 0)
        'Your longest viewing session was ${_duration(insights.longestSessionMs)}.',
      if (insights.topTitles.isNotEmpty)
        '${insights.topTitles.first.label} held the most viewing time.',
    ];
    return _Panel(
      child: Column(
        children: [
          for (final observation in observations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                PhosphorIcons.sparkle(),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(observation),
            ),
        ],
      ),
    );
  }
}

class _GuestMergeCard extends StatelessWidget {
  const _GuestMergeCard({required this.provider});

  final WellnessProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add this device’s guest history?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Guest viewing may belong to someone else. It will stay separate unless you choose to merge it.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: provider.mergeGuestHistory,
                  child: const Text('Merge with my account'),
                ),
                TextButton(
                  onPressed: provider.dismissGuestMerge,
                  child: const Text('Keep separate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.canSync});

  final bool canSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.lockKey(),
              size: 17,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private by design',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  canSync
                      ? 'Stored in SQLite on this device and synced to your FlixQuest account. This history is not sent to product analytics.'
                      : 'Stored only in SQLite on this device. Sign in when you want to sync it across devices.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessEmptyState extends StatelessWidget {
  const _WellnessEmptyState({required this.hasHistory});

  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .48),
            _insightSurface(context),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.tertiary],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasHistory
                  ? PhosphorIcons.calendarBlank()
                  : PhosphorIcons.chartDonut(),
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
              hasHistory
                  ? 'Nothing watched in this period'
                  : 'Your viewing story starts here',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            hasHistory
                ? 'Try another time range to revisit your earlier viewing activity.'
                : 'Watch for at least 30 seconds and FlixQuest will begin building private insights about your time, titles, taste, and patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _EmptyFeature(icon: Icons.schedule_rounded, label: 'Time'),
              _EmptyFeature(icon: Icons.movie_outlined, label: 'Titles'),
              _EmptyFeature(icon: Icons.palette_outlined, label: 'Taste'),
              _EmptyFeature(icon: Icons.grid_view_rounded, label: 'Patterns'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyFeature extends StatelessWidget {
  const _EmptyFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

bool _isLightsOut(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor.computeLuminance() < .003;

Color _insightSurface(BuildContext context, {bool raised = false}) {
  final theme = Theme.of(context);
  if (_isLightsOut(context)) {
    return Color.alphaBlend(
      Colors.white.withValues(alpha: raised ? .13 : .08),
      theme.scaffoldBackgroundColor,
    );
  }
  return raised
      ? theme.colorScheme.surfaceContainerHighest
      : theme.colorScheme.surfaceContainerLow;
}

Color _bestGradientForeground(List<Color> colors) {
  const darkInk = Color(0xFF111315);
  var darkScore = double.infinity;
  var lightScore = double.infinity;
  for (final color in colors) {
    final darkContrast = _contrastRatio(color, darkInk);
    final lightContrast = _contrastRatio(color, Colors.white);
    if (darkContrast < darkScore) darkScore = darkContrast;
    if (lightContrast < lightScore) lightScore = lightContrast;
  }
  return darkScore >= lightScore ? darkInk : Colors.white;
}

Color _ensureTextContrast(Color background, Color foreground) {
  var adjusted = background;
  final target =
      foreground.computeLuminance() > .5 ? Colors.black : Colors.white;
  for (var step = 0;
      step < 20 && _contrastRatio(adjusted, foreground) < 7;
      step++) {
    adjusted = Color.lerp(adjusted, target, .08)!;
  }
  return adjusted;
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + .05) / (darker + .05);
}

List<WellnessBarDatum> _barData(
  WellnessInsights insights,
  WellnessRange range,
) {
  final now = DateTime.now();
  switch (range) {
    case WellnessRange.week:
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      return List<WellnessBarDatum>.generate(7, (index) {
        final day = start.add(Duration(days: index));
        return WellnessBarDatum(
          label: DateFormat.E().format(day).substring(0, 1),
          value: insights.dailyWatchedMs[day] ?? 0,
        );
      });
    case WellnessRange.month:
      final count = DateTime(now.year, now.month + 1, 0).day;
      return List<WellnessBarDatum>.generate(count, (index) {
        final day = DateTime(now.year, now.month, index + 1);
        return WellnessBarDatum(
          label: '${index + 1}',
          value: insights.dailyWatchedMs[day] ?? 0,
        );
      });
    case WellnessRange.year:
      return List<WellnessBarDatum>.generate(12, (index) {
        final month = index + 1;
        final value = insights.dailyWatchedMs.entries
            .where((entry) =>
                entry.key.year == now.year && entry.key.month == month)
            .fold<int>(0, (total, entry) => total + entry.value);
        return WellnessBarDatum(
          label: DateFormat.MMM()
              .format(DateTime(now.year, month))
              .substring(0, 1),
          value: value,
        );
      });
    case WellnessRange.allTime:
      final years = insights.dailyWatchedMs.keys
          .map((day) => day.year)
          .toSet()
          .toList()
        ..sort();
      return years.map((year) {
        final value = insights.dailyWatchedMs.entries
            .where((entry) => entry.key.year == year)
            .fold<int>(0, (total, entry) => total + entry.value);
        return WellnessBarDatum(label: '$year', value: value);
      }).toList(growable: false);
  }
}

(String, String)? _peakHour(List<List<int>> grid) {
  var max = 0;
  var peakDay = 0;
  var peakHour = 0;
  for (var day = 0; day < grid.length; day++) {
    for (var hour = 0; hour < grid[day].length; hour++) {
      if (grid[day][hour] > max) {
        max = grid[day][hour];
        peakDay = day;
        peakHour = hour;
      }
    }
  }
  if (max == 0) return null;
  const days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  return (days[peakDay], DateFormat.j().format(DateTime(2024, 1, 1, peakHour)));
}

String _duration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds.abs());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _trackingSince(List<WellnessViewingSession> sessions) {
  if (sessions.isEmpty) return 'Tracking begins with your next viewing session';
  final oldest = sessions.reduce(
    (current, session) =>
        session.startedAtUtc.isBefore(current.startedAtUtc) ? session : current,
  );
  final local =
      oldest.startedAtUtc.add(Duration(minutes: oldest.timezoneOffsetMinutes));
  return 'Tracking since ${DateFormat.yMMMd().format(local)}';
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return DateFormat.MMMd().format(value);
}

String _rangeName(WellnessRange range) => switch (range) {
      WellnessRange.week => 'week',
      WellnessRange.month => 'month',
      WellnessRange.year => 'year',
      WellnessRange.allTime => 'all time',
    };

String _rangeLabel(WellnessRange range) => switch (range) {
      WellnessRange.week => 'This week',
      WellnessRange.month => 'This month',
      WellnessRange.year => 'This year',
      WellnessRange.allTime => 'All time',
    };

List<WellnessBarDatum> _recapBarData(
  WellnessInsights insights,
  WellnessRange range,
) {
  final raw = _barData(insights, range);
  if (raw.length <= 12) return raw;
  const groupCount = 7;
  final groupSize = (raw.length / groupCount).ceil();
  final grouped = <WellnessBarDatum>[];
  for (var start = 0; start < raw.length; start += groupSize) {
    final end = (start + groupSize).clamp(0, raw.length);
    final value = raw
        .sublist(start, end)
        .fold<int>(0, (total, item) => total + item.value);
    grouped.add(
      WellnessBarDatum(label: '${grouped.length + 1}', value: value),
    );
  }
  return grouped;
}
