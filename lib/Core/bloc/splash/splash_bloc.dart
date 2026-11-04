import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';


part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final SharedPreferences prefs;

  SplashBloc({required this.prefs}) : super(SplashInitial()) {
    on<CheckAuthStatus>(_checkAuthStatus);
  }

  Future<void> _checkAuthStatus(
    CheckAuthStatus event,
    Emitter<SplashState> emit,
  ) async {
    try {
      emit(SplashLoading());
      
      
      await Future.delayed(const Duration(seconds: 2));
      
      final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isFirstTime) {
        await prefs.setBool('isFirstTime', false);
        emit(SplashFirstTime());
      } else if (isLoggedIn) {
        emit(SplashAuthenticated());
      } else {
        emit(SplashUnauthenticated());
      }
    } catch (e) {
      emit(SplashError(message: 'Failed to check auth status: $e'));
    }
  }
}