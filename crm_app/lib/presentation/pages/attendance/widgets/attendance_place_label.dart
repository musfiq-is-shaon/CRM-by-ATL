import 'package:flutter/material.dart';
import '../../../../core/services/location_service.dart';

/// Shows [text] as-is when it is not a coordinate pair; otherwise reverse-geocodes once.
class AttendancePlaceLabel extends StatefulWidget {
  const AttendancePlaceLabel({
    super.key,
    required this.text,
    required this.textStyle,
    this.loadingStyle,
  });

  final String text;
  final TextStyle textStyle;
  final TextStyle? loadingStyle;

  @override
  State<AttendancePlaceLabel> createState() => _AttendancePlaceLabelState();
}

class _AttendancePlaceLabelState extends State<AttendancePlaceLabel> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant AttendancePlaceLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(() {
        _future = _resolve();
      });
    }
  }

  Future<String> _resolve() {
    if (!LocationService.looksLikeCoordinatesString(widget.text)) {
      return Future.value(widget.text);
    }
    return LocationService.placeLabelFromCoordinateString(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    if (!LocationService.looksLikeCoordinatesString(widget.text)) {
      return Text(
        widget.text,
        style: widget.textStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final loading = widget.loadingStyle ??
        widget.textStyle.copyWith(
          fontWeight: FontWeight.w500,
          color: widget.textStyle.color?.withOpacity(0.55),
        );
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Text(
            'Resolving address…',
            style: loading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          snap.data ?? 'Location recorded',
          style: widget.textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
