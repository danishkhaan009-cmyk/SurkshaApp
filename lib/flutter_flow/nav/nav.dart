import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:without_database/services/child_mode_service.dart';
import 'package:without_database/services/self_mode_service.dart';
import 'package:without_database/main.dart';
import 'package:without_database/flutter_flow/flutter_flow_util.dart';

import 'package:without_database/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._() {
    // Listen to Supabase auth state changes to trigger router refreshes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  static AppStateNotifier? _instance;

  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  bool showSplashImage = true;

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      redirect: (context, state) async {
        final session = Supabase.instance.client.auth.currentSession;
        final loggedIn = session != null;

        final isChildMode = await ChildModeService.isChildModeActive();
        final isSelfMode = await SelfModeService.isSelfModeActive();

        // If logged in and trying to access auth pages (splash, login, signup), redirect home
        final authPaths = [
          '/',
          '/splashScreen',
          '/loginScreen',
          '/signupScreen',
          '/forgotPassword'
        ];
        if (loggedIn && authPaths.contains(state.uri.path)) {
          if (isChildMode) {
            return '/childDeviceSetup5';
          } else if (isSelfMode) {
            return '/selfMode';
          } else {
            return '/parentDashboard';
          }
        } else if (!loggedIn && !authPaths.contains(state.uri.path)) {
          return '/splashScreen';
        }
        return null;
      },
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => const SplashScreenWidget(),
        ),
        FFRoute(
          name: SplashScreenWidget.routeName,
          path: SplashScreenWidget.routePath,
          builder: (context, params) => const SplashScreenWidget(),
        ),
        FFRoute(
          name: LoginScreenWidget.routeName,
          path: LoginScreenWidget.routePath,
          builder: (context, params) => const LoginScreenWidget(),
        ),
        FFRoute(
          name: SignupScreenWidget.routeName,
          path: SignupScreenWidget.routePath,
          builder: (context, params) => const SignupScreenWidget(),
        ),
        FFRoute(
          name: ForgotPasswordWidget.routeName,
          path: ForgotPasswordWidget.routePath,
          builder: (context, params) => const ForgotPasswordWidget(),
        ),
        FFRoute(
          name: SelectModeWidget.routeName,
          path: SelectModeWidget.routePath,
          builder: (context, params) => const SelectModeWidget(),
        ),
        FFRoute(
          name: ChildDeviceSetup1Widget.routeName,
          path: ChildDeviceSetup1Widget.routePath,
          builder: (context, params) => const ChildDeviceSetup1Widget(),
        ),
        FFRoute(
          name: ChildDeviceSetup2Widget.routeName,
          path: ChildDeviceSetup2Widget.routePath,
          builder: (context, params) => const ChildDeviceSetup2Widget(),
        ),
        FFRoute(
          name: ChildDeviceSetup3Widget.routeName,
          path: ChildDeviceSetup3Widget.routePath,
          builder: (context, params) => const ChildDeviceSetup3Widget(),
        ),
        FFRoute(
          name: ChildDeviceSetup4Widget.routeName,
          path: ChildDeviceSetup4Widget.routePath,
          builder: (context, params) => const ChildDeviceSetup4Widget(),
        ),
        FFRoute(
          name: ChildDeviceSetup5Widget.routeName,
          path: ChildDeviceSetup5Widget.routePath,
          builder: (context, params) => const ChildDeviceSetup5Widget(),
        ),
        FFRoute(
          name: LinkChildDeviceWidget.routeName,
          path: LinkChildDeviceWidget.routePath,
          builder: (context, params) => const LinkChildDeviceWidget(),
        ),
        FFRoute(
          name: ChildsDeviceWidget.routeName,
          path: ChildsDeviceWidget.routePath,
          builder: (context, params) => ChildsDeviceWidget(
            deviceId: params.getParam<String>(
              'deviceId',
              ParamType.String,
            ),
            childName: params.getParam<String>(
              'childName',
              ParamType.String,
            ),
            childAge: params.getParam<int>(
              'childAge',
              ParamType.int,
            ),
          ),
        ),
        FFRoute(
          name: ParentDashboardWidget.routeName,
          path: ParentDashboardWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? const NavBarPage(initialPage: 'Parent_Dashboard')
              : const ParentDashboardWidget(),
        ),
        FFRoute(
            name: AlertWidget.routeName,
            path: AlertWidget.routePath,
            builder: (context, params) => params.isEmpty
                ? const NavBarPage(initialPage: 'Alert')
                : const NavBarPage(
                    initialPage: 'Alert',
                    page: AlertWidget(),
                  )),
        FFRoute(
            name: SubscriptionWidget.routeName,
            path: SubscriptionWidget.routePath,
            builder: (context, params) => params.isEmpty
                ? const NavBarPage(initialPage: 'Subscription')
                : const NavBarPage(
                    initialPage: 'Subscription',
                    page: SubscriptionWidget(),
                  )),
        FFRoute(
            name: SettingsWidget.routeName,
            path: SettingsWidget.routePath,
            builder: (context, params) => params.isEmpty
                ? const NavBarPage(initialPage: 'Settings')
                : const NavBarPage(
                    initialPage: 'Settings',
                    page: SettingsWidget(),
                  )),
        FFRoute(
            name: SelfModeWidget.routeName,
            path: SelfModeWidget.routePath,
            builder: (context, params) => const NavBarPage(
                  initialPage: '',
                  page: SelfModeWidget(),
                )),
        FFRoute(
          name: ChildSelectionWidget.routeName,
          path: ChildSelectionWidget.routePath,
          builder: (context, params) => const ChildSelectionWidget(),
        ),
        FFRoute(
          name: AppLockScreenWidget.routeName,
          path: AppLockScreenWidget.routePath,
          builder: (context, params) => const AppLockScreenWidget(),
        )
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
      observers: [routeObserver],
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};

  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);

  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));

  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;

  bool get hasFutures => state.allParams.entries.any(isAsyncParam);

  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    if (param is! String) {
      return param;
    }
    return deserializeParam<T>(
      param,
      type,
      isList,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() =>
      const TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);

  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
