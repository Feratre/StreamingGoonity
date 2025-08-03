import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Configurazione API
  static const String baseUrl = 'https://ad549817b04d.ngrok-free.app'; // Aggiorna con il tuo URL ngrok
  static const String registerEndpoint = '/api.php?action=register';
  static const String loginEndpoint = '/api.php?action=login';
  
  // Chiavi per SharedPreferences
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _isLoggedInKey = 'is_logged_in';
  
  // Stato dell'autenticazione
  static bool _isLoggedIn = false;
  static int? _userId;
  static String? _userName;
  static String? _userEmail;
  
  // Getters
  static bool get isUserLoggedIn => _isLoggedIn;
  static int? get userId => _userId;
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  
  // Inizializza lo stato di autenticazione
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (_isLoggedIn) {
      _userId = prefs.getInt(_userIdKey);
      _userName = prefs.getString(_userNameKey);
      _userEmail = prefs.getString(_userEmailKey);
    }
  }
  
  // Controlla se l'utente è loggato
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }
  
  // Registra un nuovo utente
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final url = '$baseUrl$registerEndpoint';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'StreamingApp/1.0',
        },
        body: json.encode({
          'nome': name,
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return data;
        } catch (e) {
          return {
            'success': false,
            'message': 'Errore nel formato della risposta: $e',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Errore server: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Errore di connessione: $e',
      };
    }
  }
  
  // Effettua il login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = '$baseUrl$loginEndpoint';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'StreamingApp/1.0',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          if (data['success']) {
            // Salva i dati utente
            if (data.containsKey('user')) {
              await _saveUserData(
                data['user']['id'],
                data['user']['nome'],
                data['user']['email'],
              );
            } else {
              // Fallback se i dati utente sono incompleti
              await _saveUserData(
                0,
                email.split('@')[0],
                email,
              );
            }
          }
          
          return data;
        } catch (e) {
          return {
            'success': false,
            'message': 'Errore nel formato della risposta: $e',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Errore server: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Errore di connessione: $e',
      };
    }
  }
  
  // Salva i dati utente in SharedPreferences
  static Future<void> _saveUserData(int id, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_userIdKey, id);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setBool(_isLoggedInKey, true);
    
    _isLoggedIn = true;
    _userId = id;
    _userName = name;
    _userEmail = email;
  }
  
  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.setBool(_isLoggedInKey, false);
    
    _isLoggedIn = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
  }
}
