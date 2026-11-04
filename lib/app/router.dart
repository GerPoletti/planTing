import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../features/consultorio/consultorio_screen.dart';
import '../features/consultorio/pests_screen.dart';
import '../features/consultorio/treatment_screen.dart';
import '../features/discover/collection_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/discover/species_screen.dart';
import '../features/garden/add_plant_screen.dart';
import '../features/garden/garden_screen.dart';
import '../features/garden/plant_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/room_screen.dart';
import '../features/home/window_screen.dart';
import '../features/measure/measure_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'app_shell.dart';

/// Rutas de la app. Mientras no se termine el primer uso, todo lleva al onboarding.
GoRouter buildRouter(AppStore store) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: store,
    redirect: (context, state) {
      final done = store.settings.onboardingDone;
      final here = state.matchedLocation;
      if (!done && here != '/onboarding') return '/onboarding';
      if (done && here == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/garden', builder: (context, state) => const GardenScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/discover', builder: (context, state) => const DiscoverScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/measure',
        builder: (context, state) => MeasureScreen(plantId: state.uri.queryParameters['plant']),
      ),
      GoRoute(
        path: '/plants/add',
        builder: (context, state) => AddPlantScreen(speciesId: state.uri.queryParameters['species']),
      ),
      GoRoute(
        path: '/plant/:id',
        builder: (context, state) => PlantScreen(plantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (context, state) => RoomScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/window/:id',
        builder: (context, state) => WindowScreen(windowId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/consultorio',
        builder: (context, state) => ConsultorioScreen(plantId: state.uri.queryParameters['plant']),
      ),
      GoRoute(path: '/pests', builder: (context, state) => const PestsScreen()),
      GoRoute(
        path: '/pest/:id',
        builder: (context, state) => PestScreen(
          pestId: state.pathParameters['id']!,
          plantId: state.uri.queryParameters['plant'],
        ),
      ),
      GoRoute(
        path: '/treatment/:id',
        builder: (context, state) => TreatmentScreen(treatmentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/collection', builder: (context, state) => const CollectionScreen()),
      GoRoute(
        path: '/species/:id',
        builder: (context, state) => SpeciesScreen(speciesId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
}
