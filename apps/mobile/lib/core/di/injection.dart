import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/domain/usecases/logout.dart';
import '../../features/auth/domain/usecases/register.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/conversation/data/repositories/conversation_repository_impl.dart';
import '../../features/conversation/domain/repositories/conversation_repository.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../network/socket_client.dart';
import '../database/local_chat_database.dart';
import '../monetization/message_access_service.dart';
import '../storage/local_storage.dart';
import '../storage/shared_prefs_storage.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  getIt.registerSingleton<SharedPreferences>(prefs);
  final messageAccessService = MessageAccessService(prefs)..initialize();
  getIt.registerSingleton<MessageAccessService>(messageAccessService);
  getIt.registerLazySingleton<LocalStorage>(() => SharedPrefsStorage(prefs));

  getIt.registerLazySingleton<DioClient>(() => DioClient(prefs));
  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfo(InternetConnection()),
  );
  getIt.registerLazySingleton<SocketClient>(SocketClient.new);
  final chatDatabase = LocalChatDatabase();
  await chatDatabase.initialize();
  getIt.registerSingleton<LocalChatDatabase>(chatDatabase);

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<DioClient>()),
  );
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(prefs),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<AuthRemoteDataSource>(),
      getIt<AuthLocalDataSource>(),
      getIt<SocketClient>(),
    ),
  );

  getIt.registerLazySingleton<Login>(() => Login(getIt<AuthRepository>()));
  getIt.registerLazySingleton<Register>(
    () => Register(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<Logout>(() => Logout(getIt<AuthRepository>()));
  getIt.registerLazySingleton<GetCurrentUser>(
    () => GetCurrentUser(getIt<AuthRepository>()),
  );

  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      login: getIt<Login>(),
      register: getIt<Register>(),
      logout: getIt<Logout>(),
      getCurrentUser: getIt<GetCurrentUser>(),
    ),
  );

  getIt.registerLazySingleton<ConversationRepository>(
    () => ConversationRepositoryImpl(
      getIt<DioClient>(),
      getIt<SocketClient>(),
      getIt<LocalChatDatabase>(),
    ),
  );

  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      getIt<DioClient>(),
      getIt<SocketClient>(),
      prefs,
      getIt<LocalChatDatabase>(),
    ),
  );
}
