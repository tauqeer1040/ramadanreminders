import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' deferred as lottie;

/// Lazily loads the `lottie` package (deferred import) so the ~300 KB parser
/// stays out of the initial `main.dart.js` chunk. Shows [placeholder] until
/// the library is ready.
class DeferredLottie extends StatefulWidget {
  final String asset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const DeferredLottie({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  State<DeferredLottie> createState() => _DeferredLottieState();
}

class _DeferredLottieState extends State<DeferredLottie> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await lottie.loadLibrary();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return lottie.Lottie.asset(
      widget.asset,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: widget.errorBuilder,
    );
  }
}
