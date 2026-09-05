import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/banner_ad.dart';
import '../provider/app_dependency_provider.dart';

final CacheManager _adImageCache = CacheManager(
  Config(
    'flixquest_ad_images',
    stalePeriod: const Duration(minutes: 15),
    maxNrOfCacheObjects: 24,
  ),
);

class HostedAdsBanner extends StatelessWidget {
  const HostedAdsBanner(
      {required this.ads, required this.placement, super.key});

  final List<BannerAd> ads;
  final String placement;

  @override
  Widget build(BuildContext context) {
    final validAds = ads
        .where((ad) => ad.imageUrl.isNotEmpty && ad.targetUrl.isNotEmpty)
        .toList(growable: false);
    if (validAds.isEmpty) return const SizedBox.shrink();
    final dependencies = context.watch<AppDependencyProvider>();
    final config = dependencies.bannerConfigFor(validAds.first.key);
    final shape = config.shape ?? validAds.first.shape;
    final aspectRatio = config.aspectRatio ?? validAds.first.aspectRatio;
    final ratio = shape == 'square'
        ? 1.0
        : shape == 'portrait'
            ? .75
            : shape == 'wide'
                ? 3.2
                : aspectRatio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (config.width ?? constraints.maxWidth)
                .clamp(1.0, constraints.maxWidth)
                .toDouble();
            final height =
                (config.height ?? width / ratio).clamp(72.0, 320.0).toDouble();
            return _CachedAdCarousel(
              ads: validAds,
              width: width,
              height: height,
            );
          },
        ),
      ),
    );
  }
}

class _CachedAdCarousel extends StatefulWidget {
  const _CachedAdCarousel({
    required this.ads,
    required this.width,
    required this.height,
  });

  final List<BannerAd> ads;
  final double width;
  final double height;

  @override
  State<_CachedAdCarousel> createState() => _CachedAdCarouselState();
}

class _CachedAdCarouselState extends State<_CachedAdCarousel> {
  final PageController _controller = PageController();
  Timer? _rotationTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ads.length > 1) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) return;
        _index = (_index + 1) % widget.ads.length;
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.ads.length,
        onPageChanged: (index) => _index = index,
        itemBuilder: (context, index) {
          final ad = widget.ads[index];
          return GestureDetector(
            onTap: () => unawaited(launchUrlString(ad.targetUrl)),
            child: Semantics(
              label: ad.altText.isEmpty ? ad.name : ad.altText,
              image: true,
              child: CachedNetworkImage(
                imageUrl: ad.imageUrl,
                cacheManager: _adImageCache,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RemoteHostedAdsBanner extends StatefulWidget {
  const RemoteHostedAdsBanner(
      {required this.loadAds, required this.placement, super.key});

  final Future<List<BannerAd>> Function() loadAds;
  final String placement;

  @override
  State<RemoteHostedAdsBanner> createState() => _RemoteHostedAdsBannerState();
}

class _RemoteHostedAdsBannerState extends State<RemoteHostedAdsBanner> {
  late final Future<List<BannerAd>> _adsFuture = widget.loadAds();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BannerAd>>(
      future: _adsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final dependencies = context.watch<AppDependencyProvider>();
        final ads = snapshot.data!.where((ad) {
          final backendPlacement =
              ad.placements.isEmpty || ad.placements.contains(widget.placement);
          return backendPlacement &&
              dependencies.isBannerEnabled(ad.key, widget.placement);
        }).toList(growable: false);
        return HostedAdsBanner(ads: ads, placement: widget.placement);
      },
    );
  }
}
