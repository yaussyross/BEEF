import 'package:flutter/material.dart';

import '../api/http_client.dart';
import '../api/ratings_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';
import '../models/rating.dart';
import '../theme/beef_colors.dart';

/// Eligibility is always fetched from the server; there is no client countdown.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.userId, this.api});
  final String userId;
  final RatingsApi? api;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  RatingsApi? _api;
  ApiClient? _ownedClient;
  RatingEligibility? _eligibility;
  int? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _confirmation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    if (widget.api != null) {
      _api = widget.api;
    } else {
      _ownedClient = ApiClient(
        baseUrl: ApiConfig.baseUrl,
        tokenStore: AuthScope.read(context).tokenStore,
      );
      _api = RatingsApi(_ownedClient!);
    }
    _load();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api!.eligibility(widget.userId);
      if (!mounted) return;
      setState(() {
        _eligibility = result;
        _selected = result.myRating;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _eligibility = null;
        _error = error is ApiException
            ? error.message : 'Could not check rating eligibility. Try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _selected == null || _eligibility?.eligible != true) return;
    setState(() { _saving = true; _error = null; _confirmation = null; });
    try {
      final saved = await _api!.save(widget.userId, _selected!);
      if (!mounted) return;
      setState(() {
        _eligibility = RatingEligibility(eligible: true, myRating: saved);
        _selected = saved;
        _confirmation = 'Your rating was saved.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message : 'Could not confirm your rating. Try again.';
        if (error is ApiException &&
            (error.statusCode == 403 || error.statusCode == 404)) {
          _eligibility = null;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligibility?.eligible == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Rate this Guy')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null)
                    Semantics(liveRegion: true, child: Text(_error!)),
                  if (_confirmation != null)
                    Semantics(liveRegion: true, child: Text(_confirmation!)),
                  if (!eligible) ...[
                    if (_eligibility != null) const Text(
                      'Ratings unlock after you have both sent messages across '
                      'at least five minutes. Leaving chat open does not count.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text('Check again')),
                  ] else ...[
                    const Text('Choose 1–5 stars. You can update your rating later.'),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (var stars = 1; stars <= 5; stars++)
                          Semantics(
                            selected: _selected == stars,
                            child: IconButton(
                              tooltip: '$stars ${stars == 1 ? 'star' : 'stars'}',
                              onPressed: _saving ? null : () => setState(() {
                                _selected = stars;
                                _confirmation = null;
                              }),
                              icon: Icon(
                                stars <= (_selected ?? 0) ? Icons.star : Icons.star_border,
                                color: BeefColors.lime,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving || _selected == null ? null : _save,
                      child: Text(_saving ? 'Saving…' :
                        _eligibility?.myRating == null ? 'Save rating' : 'Update rating'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
