import 'package:flutter/material.dart';

import '../api/discovery_api.dart';
import '../api/http_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';
import '../discovery/discovery_controller.dart';
import '../models/intent_tag.dart';
import '../theme/beef_colors.dart';
import '../widgets/discovery_filters.dart';
import '../widgets/grid_tile.dart';
import 'profile_screen.dart';

/// The proximity grid — the heart of BEEF. Fetches `GET /api/grid` (Bearer
/// auth via the shared [ApiClient]), renders original BEEF tiles in a 2-up
/// grid with bucketed distance labels, intent-tag filter chips, "A Plate of
/// Mates" friends lane, "The Menu" interest chips, pull-to-refresh, infinite
/// scroll, and empty/error states.
///
/// Privacy: distances render verbatim as server bucket labels ("<1 mi",
/// "nearby", …) — the client never sees or shows coordinates.
class GridScreen extends StatefulWidget {
  const GridScreen({super.key});

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  DiscoveryController? _controller;
  final ScrollController _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      // Reuse the session's token store (refresh-on-401 included) — no new
      // auth, just a second thin client over the same keystore.
      final AuthController auth = AuthScope.read(context);
      final ApiClient client = ApiClient(
        baseUrl: ApiConfig.baseUrl,
        tokenStore: auth.tokenStore,
      );
      _controller = DiscoveryController(api: DiscoveryApi(client))
        ..addListener(_onChanged)
        ..refresh();
      _scroll.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final DiscoveryController? controller = _controller;
    if (controller == null) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 320) {
      controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DiscoveryController? controller = _controller;
    if (controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('THE GRID'),
        actions: <Widget>[
          if (controller.hasActiveFilters)
            TextButton(
              onPressed: controller.clearAllFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: BeefColors.lime,
          onRefresh: controller.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: DiscoveryFilters(
                    selectedIntent: controller.intent,
                    matesOnly: controller.matesOnly,
                    selectedInterests: controller.selectedInterests,
                    onIntent: (IntentTag? tag) =>
                        controller.setIntent(tag),
                    onMates: controller.setMatesOnly,
                    onInterest: controller.toggleInterest,
                  ),
                ),
              ),
              _Body(controller: controller, scroll: _scroll),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.scroll});

  final DiscoveryController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case DiscoveryStatus.idle:
      case DiscoveryStatus.loading:
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _LoadingState(),
        );
      case DiscoveryStatus.error:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(
            message: controller.error,
            onRetry: controller.refresh,
          ),
        );
      case DiscoveryStatus.empty:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            filtered: controller.hasActiveFilters,
            onClear: controller.clearAllFilters,
          ),
        );
      case DiscoveryStatus.loaded:
        if (controller.items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              filtered: controller.hasActiveFilters,
              onClear: controller.clearAllFilters,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                if (index >= controller.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: BeefColors.lime,
                      ),
                    ),
                  );
                }
                final item = controller.items[index];
                return GridTile(
                  profile: item,
                  onTap: () => _openProfile(context, item.userId),
                );
              },
              childCount: controller.items.length +
                  (controller.hasMore ? 1 : 0),
            ),
          ),
        );
    }
  }

  void _openProfile(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProfileScreen(userId: userId),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircularProgressIndicator(color: BeefColors.lime),
          const SizedBox(height: 16),
          Text(
            'Firing up the grill…',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BeefColors.cream.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: BeefColors.sizzle,
            ),
            const SizedBox(height: 16),
            Text(
              'The grill went cold.',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Could not load the grid. Give it another go.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BeefColors.cream.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onClear});

  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.set_meal_outlined,
              size: 56,
              color: BeefColors.sizzle,
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No cuts match that craving.' : 'Nobody on the grill yet.',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Loosen a filter or two — your next favourite is out there.'
                  : 'Be the first sizzle in your area. Check back soon.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BeefColors.cream.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (filtered) ...<Widget>[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
