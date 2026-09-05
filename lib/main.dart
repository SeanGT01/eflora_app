import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/address_provider.dart';
import 'providers/category_provider.dart';
import 'providers/rider_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/main_shell.dart';
import 'screens/rider/rider_shell.dart';
import 'services/app_quality.dart';
import 'services/presence_service.dart';
import 'theme/app_background.dart';
import 'theme/app_theme.dart';
import 'utils/responsive.dart';
import 'widgets/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppQuality.instance.init();
  await initializeImageCache();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const EFlowersApp());
}

Future<void> initializeImageCache() async {
  CachedNetworkImage.logLevel = CacheManagerLogLevel.none;
  // Wiping the whole cache on every cold start hurts low-end devices.
  if (AppQuality.instance.isRich) {
    await CachedNetworkImage.evictFromCache('all');
  }
}

class EFlowersApp extends StatelessWidget {
  const EFlowersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => addressProvider),
        ChangeNotifierProvider(create: (_) => categoryProvider),
        ChangeNotifierProvider(create: (_) => RiderProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'E-FLORA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        builder: (context, child) {
          return AppToastHost(
            key: AppToastHost.overlayKey,
            child: MediaQuery(
              data: clampAppTextScaler(MediaQuery.of(context)),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await auth.tryAutoLogin();

    // Active-session Online presence while the app is in the foreground.
    PresenceService.instance.attach(auth);
    
    // Setup Address Service interceptors with JWT token (if logged in)
    await setupAddressServiceInterceptors();
    
    // Load main categories (independent of auth status)
    await context.read<CategoryProvider>().loadMainCategories();
    
    if (auth.isLoggedIn) {
      // Cart API is customer-only — skip for riders/sellers/admins.
      if (auth.user?.role == 'customer' || auth.user?.role == null) {
        await context.read<CartProvider>().load();
      } else {
        context.read<CartProvider>().reset();
      }
      context.read<ChatProvider>().startPolling();
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    PresenceService.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.glassBorder, width: 2),
                    boxShadow: AppShadows.petal,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'E-FLORA',
                  style: AppTheme.theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'FLOWERS FOR EVERY MOMENT',
                  style: AppTheme.theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.dustyRose,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 26, height: 26,
                  child: CircularProgressIndicator(
                    color: AppColors.roseCta,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildHomeForRole(context);
  }
}

Widget _buildHomeForRole(BuildContext context) {
  final auth = context.watch<AuthProvider>();
  final chat = context.read<ChatProvider>();

  if (auth.isLoggedIn) {
    chat.startPolling();
  } else {
    chat.reset();
  }

  if (auth.isLoggedIn && auth.user?.role == 'rider') {
    return const RiderShell();
  }
  return const MainShell();
}