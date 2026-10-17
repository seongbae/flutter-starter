import 'package:flutter/material.dart';
import '../board_theme.dart';

/// Opens a bottom sheet over the whole app, bottom nav included, so the
/// Android back button closes the sheet rather than the app. The root
/// navigator sits outside the board shell's theme, so it's reapplied here.
Future<T?> showBoardSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Theme(data: BoardTheme.data, child: builder(context)),
  );
}
