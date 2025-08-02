import 'package:collider_loading/config.dart';
import 'package:collider_loading/core/data/constants.dart';
import 'package:collider_loading/core/data/dio_client.dart';
import 'package:collider_loading/core/domain/repository/api_repository.dart';
import 'package:collider_loading/core/domain/repository/theme_repository.dart';
import 'package:collider_loading/core/presentation/navigation/router_configuration.dart';
import 'package:collider_loading/feature/animation/domain/cubit/loading_screen_cubit.dart';
import 'package:collider_loading/feature/home/data/repository/home_page_repository.dart';
import 'package:collider_loading/feature/home/data/repository/home_page_repository_impl.dart';
import 'package:collider_loading/feature/home/domain/cubit/home_page_cubit.dart';
import 'package:collider_loading/feature/main_page_container/domain/cubit/main_page_cubit.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;
Future<void> initDI() async {
  await _registerApiClient();
  await _registerUtils();
  _registerCubits();
}

Future<void> _registerApiClient() async {
  String? flavorFromEnv;

  flavorFromEnv = const String.fromEnvironment('FLUTTER_APP_FLAVOR');
  final appFlavor = flavorFromEnv != '' ? flavorFromEnv : 'prod';

  getIt.registerLazySingleton<Dio>(
    () => DioClient.getDioClient(Config.baseUrl(appFlavor), headerParams),
  );
}

Future<void> _registerUtils() async {
  getIt
    ..registerSingleton<ThemeRepository>(ThemeRepository())
    ..registerSingleton<RouterConfiguration>(RouterConfiguration())
    ..registerLazySingleton<BaseApiRepository>(() => BaseApiRepository(getIt<Dio>()))
    ..registerLazySingleton<HomePageRepository>(() => HomePageRepositoryImpl(getIt<BaseApiRepository>()));
}

void _registerCubits() {
  getIt
    ..registerLazySingleton<LoadingScreenCubit>(() => LoadingScreenCubit())
    ..registerLazySingleton<HomePageCubit>(() => HomePageCubit(getIt<HomePageRepository>()))
    ..registerLazySingleton<MainPageCubit>(() => MainPageCubit());
}
