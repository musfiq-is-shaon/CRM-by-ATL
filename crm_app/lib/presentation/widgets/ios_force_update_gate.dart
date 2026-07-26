import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/ios_force_update_service.dart';

class IosForceUpdateGate extends StatefulWidget {
  const IosForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<IosForceUpdateGate> createState() => _IosForceUpdateGateState();
}

class _IosForceUpdateGateState extends State<IosForceUpdateGate>
    with WidgetsBindingObserver {
  final IosForceUpdateService _service = IosForceUpdateService();
  bool _checking = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_dialogVisible) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _dialogVisible || !mounted) return;
    _checking = true;
    final update = await _service.check();
    _checking = false;
    if (!mounted || update == null || _dialogVisible) return;
    _dialogVisible = true;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
          title: const Text('Update Required'),
          content: Text(
            '\nA newer version (${update.storeVersion}) is available. '
            'Update CRM to continue.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final opened = await launchUrl(
                  update.storeUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && dialogContext.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the App Store. Try again.'),
                    ),
                  );
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
    _dialogVisible = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
