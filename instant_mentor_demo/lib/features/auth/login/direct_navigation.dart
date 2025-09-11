import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';

void directNavigateUser(BuildContext context, bool isStudent) {
  final route = isStudent ? AppRoutes.studentHome : AppRoutes.mentorHome;
  GoRouter.of(context).go(route);
}
