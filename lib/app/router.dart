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
import '../features/placement/where_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'app_shell.dart';
import 'save_status.dart';

/// Ruta de primer nivel con el aviso de guardado fallido arriba.
GoRoute _route({required String path, required GoRouterWidgetBuilder builder}) => GoRoute(
      path: path,
      builder: (context, state) => SaveStatusFrame(child: builder(context, state)),
    );

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
      _route(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
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
      _route(
        path: '/measure',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return MeasureScreen(
            plantId: q['plant'],
            probeX: double.tryParse(q['x'] ?? ''),
            probeY: double.tryParse(q['y'] ?? ''),
            probeHeightCm: double.tryParse(q['z'] ?? ''),
          );
        },
      ),
      _route(
        path: '/plants/add',
        builder: (context, state) => AddPlantScreen(speciesId: state.uri.queryParameters['species']),
      ),
      _route(
        path: '/plant/:id',
        builder: (context, state) => PlantScreen(plantId: state.pathParameters['id']!),
      ),
      _route(
        path: '/room/:id',
        builder: (context, state) => RoomScreen(roomId: state.pathParameters['id']!),
      ),
      _route(
        path: '/window/:id',
        builder: (context, state) => WindowScreen(windowId: state.pathParameters['id']!),
      ),
      _route(
        path: '/consultorio',
        builder: (context, state) => ConsultorioScreen(plantId: state.uri.queryParameters['plant']),
      ),
      _route(path: '/pests', builder: (context, state) => const PestsScreen()),
      _route(
        path: '/pest/:id',
        builder: (context, state) => PestScreen(
          pestId: state.pathParameters['id']!,
          plantId: state.uri.queryParameters['plant'],
        ),
      ),
      _route(
        path: '/treatment/:id',
        builder: (context, state) => TreatmentScreen(treatmentId: state.pathParameters['id']!),
      ),
      _route(path: '/collection', builder: (context, state) => const CollectionScreen()),
      _route(
        path: '/species/:id',
        builder: (context, state) => SpeciesScreen(speciesId: state.pathParameters['id']!),
      ),
      _route(
        path: '/where',
        builder: (context, state) => WhereScreen(
          plantId: state.uri.queryParameters['plant'],
          speciesId: state.uri.queryParameters['species'],
        ),
      ),
      _route(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
}
