import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async'; // Aggiunto per il Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'services/version_checker.dart';

// Modello per i dati del catalogo
class CatalogItem {
  final int id;
  final String title;
  final String? posterPath;
  final String? overview;
  final String? releaseDate;
  final double? voteAverage;
  final String mediaType;
  final List<String> genres;
  final int? runtime; // Durata in minuti

  CatalogItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.overview,
    this.releaseDate,
    this.voteAverage,
    required this.mediaType,
    this.genres = const [],
    this.runtime,
  });

  factory CatalogItem.fromTmdbJson(Map<String, dynamic> json, String mediaType, List<Map<int, String>> genreMaps) {
    // Estrai gli ID dei generi e convertili in nomi
    List<String> genreNames = [];
    
    // Controlla se ci sono generi diretti o genre_ids
    if (json['genres'] != null && json['genres'] is List) {
      // Per risposte dettagliate che hanno l'array genres
      for (var genre in json['genres']) {
        if (genre['name'] != null) {
          genreNames.add(genre['name']);
        }
      }
    } else if (json['genre_ids'] != null && json['genre_ids'] is List) {
      // Per risposte di ricerca che hanno solo gli ID
      List<int> genreIds = List<int>.from(json['genre_ids']);
      // Cerca i nomi dei generi usando le mappe
      for (var genreId in genreIds) {
        for (var genreMap in genreMaps) {
          if (genreMap.containsKey(genreId)) {
            genreNames.add(genreMap[genreId]!);
            break;
          }
        }
      }
    }
    
    return CatalogItem(
      id: json['id'],
      title: json['title'] ?? json['name'] ?? 'Senza titolo',
      posterPath: json['poster_path'],
      overview: json['overview'],
      releaseDate: json['release_date'] ?? json['first_air_date'],
      voteAverage: json['vote_average']?.toDouble(),
      mediaType: mediaType,
      genres: genreNames,
      runtime: json['runtime'],
    );
  }

  // Utility per formattare il runtime in ore e minuti
  String? formattedRuntime() {
    if (runtime == null) return null;
    
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }
}

class AuthService {
  // Impostazioni server - CAMBIA QUESTO con l'IP del tuo computer
  // Aggiorna l'URL ngrok (questo cambia ogni volta che riavvii ngrok)
  static const String baseUrl = 'https://redaproject.whf.bz'; 
  
  // Usa il file api.php unificato che gestisce entrambe le operazioni
  static const String registerEndpoint = '/register.php';
  static const String loginEndpoint = '/login.php';
  
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
  static bool get isLoggedIn => _isLoggedIn;
  static int? get userId => _userId;
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  
  // Inizializza lo stato di autenticazione all'avvio dell'app
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (_isLoggedIn) {
      _userId = prefs.getInt(_userIdKey);
      _userName = prefs.getString(_userNameKey);
      _userEmail = prefs.getString(_userEmailKey);
    }
  }
  
  // Registra un nuovo utente
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$registerEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 Flutter App', // Simula un browser per evitare blocchi
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: json.encode({
          'nome': name,
          'email': email,
          'password': password,
        }),
      );
      
      // Stampa la risposta completa per debug
      print('Risposta completa del server: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return data;
        } catch (e) {
          print('Errore nel parsing del JSON: $e');
          // Se la risposta non è JSON ma contiene "success", considerala un successo
          if (response.body.contains("success") || 
              response.body.contains("registrazione completata")) {
            return {
              'success': true,
              'message': 'Registrazione completata con successo',
            };
          }
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
      final response = await http.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 Flutter App', // Simula un browser per evitare blocchi
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      // Stampa la risposta completa per debug
      print('Risposta completa del server: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          if (data['success']) {
            // Salva i dati utente se presenti
            if (data.containsKey('user')) {
              await _saveUserData(
                data['user']['id'],
                data['user']['nome'],
                data['user']['email'],
              );
            } else {
              // Fallback per dati utente non strutturati
              await _saveUserData(
                0, // ID fallback
                email.split('@')[0], // Nome fallback usando parte dell'email
                email,
              );
            }
          }
          
          return data;
        } catch (e) {
          print('Errore nel parsing del JSON: $e');
          // Se la risposta non è JSON ma contiene "success", considerala un successo
          if (response.body.contains("success") || 
              response.body.contains("login effettuato")) {
            // Login riuscito senza dati JSON strutturati
            await _saveUserData(
              0, // ID fallback
              email.split('@')[0], // Nome fallback usando parte dell'email
              email,
            );
            return {
              'success': true,
              'message': 'Login completato con successo',
            };
          }
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
  
  // Salva i dati dell'utente nelle SharedPreferences
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
  
  // Logout: rimuovi i dati utente dalle SharedPreferences
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

// Classe per gestire la verifica della disponibilità dei contenuti
class AvailabilityService {
  static const String _cacheKey = 'available_content_ids';
  static Map<String, bool> _availabilityCache = {};
  static bool _isInitialized = false;
  
  // Inizializza la cache dai dati salvati
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        // Converti la mappa da dynamic a bool
        _availabilityCache = data.map((key, value) => MapEntry(key, value as bool));
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Errore nell\'inizializzazione della cache: $e');
      _availabilityCache = {};
      _isInitialized = true;
    }
  }
  
  // Salva la cache su disco
  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_availabilityCache));
    } catch (e) {
      print('Errore nel salvataggio della cache: $e');
    }
  }
  
  // Verifica se un contenuto è disponibile
  static Future<bool> isContentAvailable(String mediaType, int id) async {
    await initialize();
    
    String key = '$mediaType:$id';
    
    // Per testare, assumiamo che tutto sia disponibile
    _availabilityCache[key] = true;
    _saveCache();
    return true;
    
    // Codice originale commentato
    /*
    // Se abbiamo già il risultato in cache, lo usiamo
    if (_availabilityCache.containsKey(key)) {
      return _availabilityCache[key]!;
    }
    
    // Altrimenti facciamo la verifica
    try {
      final url = 'https://vixsrc.to/$mediaType/$id';
      final response = await http.head(Uri.parse(url)).timeout(Duration(seconds: 3)); 
      final isAvailable = response.statusCode != 404;
      
      // Aggiungiamo alla cache
      _availabilityCache[key] = isAvailable;
      _saveCache(); // Salviamo in background
      
      return isAvailable;
    } catch (e) {
      // In caso di errore, assumiamo che non sia disponibile
      _availabilityCache[key] = false;
      _saveCache();
      return false;
    }
    */
  }
}

// Classe per gestire il tracciamento della posizione di riproduzione
class PlaybackPositionManager {
  static const String _positionsKey = 'playback_positions';
  static Map<String, double> _positions = {};
  static bool _isInitialized = false;
  
  // Inizializza dai dati salvati
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_positionsKey);
      
      if (savedData != null) {
        final Map<String, dynamic> data = json.decode(savedData);
        _positions = data.map((key, value) => MapEntry(key, value.toDouble()));
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Errore nell\'inizializzazione delle posizioni: $e');
      _positions = {};
      _isInitialized = true;
    }
  }
  
  // Salva la cache su disco
  static Future<void> _savePositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_positionsKey, json.encode(_positions));
    } catch (e) {
      print('Errore nel salvataggio delle posizioni: $e');
    }
  }
  
  // Salva la posizione di riproduzione
  static Future<void> savePosition(String mediaType, int id, int? seasonNumber, int? episodeNumber, double position) async {
    await initialize();
    
    String key = _generateKey(mediaType, id, seasonNumber, episodeNumber);
    _positions[key] = position;
    await _savePositions();
  }
  
  // Ottieni la posizione di riproduzione
  static Future<double?> getPosition(String mediaType, int id, int? seasonNumber, int? episodeNumber) async {
    await initialize();
    
    String key = _generateKey(mediaType, id, seasonNumber, episodeNumber);
    return _positions[key];
  }
  
  // Genera una chiave univoca per ogni contenuto
  static String _generateKey(String mediaType, int id, int? seasonNumber, int? episodeNumber) {
    if (mediaType == 'tv' && seasonNumber != null && episodeNumber != null) {
      return '$mediaType:$id:s$seasonNumber:e$episodeNumber';
    }
    return '$mediaType:$id';
  }
  
  // Formatta il tempo in minuti e secondi
  static String formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
  
  // Ottieni l'ultimo episodio guardato per una serie TV
  static Future<Map<String, dynamic>?> getLastWatchedEpisode(String mediaType, int id) async {
    if (mediaType != 'tv') return null;
    
    await initialize();
    
    // Cerca tutte le chiavi che corrispondono a questa serie
    final seriesPrefix = '$mediaType:$id:s';
    Map<String, dynamic>? lastEpisode;
    double maxPosition = 0;
    
    for (var entry in _positions.entries) {
      if (entry.key.startsWith(seriesPrefix)) {
        // Estrai la stagione e l'episodio dalla chiave
        final parts = entry.key.split(':');
        if (parts.length >= 4) {
          final seasonStr = parts[2].substring(1); // Rimuovi la 's' iniziale
          final episodeStr = parts[3].substring(1); // Rimuovi la 'e' iniziale
          
          try {
            final seasonNumber = int.parse(seasonStr);
            final episodeNumber = int.parse(episodeStr);
            final position = entry.value;
            
            // Controlla se questo è l'episodio guardato più recentemente
            if (position > maxPosition) {
              maxPosition = position;
              lastEpisode = {
                'seasonNumber': seasonNumber,
                'episodeNumber': episodeNumber,
                'position': position,
              };
            }
          } catch (e) {
            // Ignora chiavi con formato non valido
          }
        }
      }
    }
    
    return lastEpisode;
  }
}

// Modelli per le stagioni e gli episodi
class Season {
  final int id;
  final int seasonNumber;
  final String name;
  final String? posterPath;
  final String? overview;
  final int episodeCount;
  final String? airDate;
  
  Season({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.posterPath,
    this.overview,
    required this.episodeCount,
    this.airDate,
  });
  
  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      name: json['name'] ?? 'Stagione ${json['season_number'] ?? 0}',
      posterPath: json['poster_path'],
      overview: json['overview'],
      episodeCount: json['episode_count'] ?? 0,
      airDate: json['air_date'],
    );
  }
}

class Episode {
  final int id;
  final int episodeNumber;
  final String name;
  final String? stillPath; // immagine dell'episodio
  final String? overview;
  final String? airDate;
  final double? voteAverage;
  final int? runtime; // Durata dell'episodio in minuti
  
  Episode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    this.stillPath,
    this.overview,
    this.airDate,
    this.voteAverage,
    this.runtime,
  });
  
  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? 0,
      episodeNumber: json['episode_number'] ?? 0,
      name: json['name'] ?? 'Episodio ${json['episode_number'] ?? 0}',
      stillPath: json['still_path'],
      overview: json['overview'],
      airDate: json['air_date'],
      voteAverage: json['vote_average']?.toDouble(),
      runtime: json['runtime'],
    );
  }
}

class WatchedContent {
  final int? id;
  final int userId;
  final int contentId;
  final String contentType; // 'movie' o 'tv'
  final String title;
  final String? posterPath;
  final double position; // Posizione di riproduzione in secondi
  final DateTime lastWatched;
  final int? seasonNumber;
  final int? episodeNumber;

  WatchedContent({
    this.id,
    required this.userId,
    required this.contentId,
    required this.contentType,
    required this.title,
    this.posterPath,
    required this.position,
    required this.lastWatched,
    this.seasonNumber,
    this.episodeNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'content_id': contentId,
      'content_type': contentType,
      'title': title,
      'poster_path': posterPath,
      'position': position,
      'last_watched': lastWatched.millisecondsSinceEpoch,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
    };
  }

  factory WatchedContent.fromJson(Map<String, dynamic> json) {
    return WatchedContent(
      id: json['id'],
      userId: json['user_id'],
      contentId: json['content_id'],
      contentType: json['content_type'],
      title: json['title'],
      posterPath: json['poster_path'],
      position: json['position'].toDouble(),
      lastWatched: DateTime.fromMillisecondsSinceEpoch(json['last_watched']),
      seasonNumber: json['season_number'],
      episodeNumber: json['episode_number'],
    );
  }
}

// Classe per la visualizzazione dei contenuti in WebView
class StreamingWebView extends StatefulWidget {
  final String url;
  final String title;
  final String mediaType;
  final int id;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? posterPath; // Aggiungi questo campo
  
  const StreamingWebView({
    Key? key, 
    required this.url, 
    required this.title,
    required this.mediaType,
    required this.id,
    this.seasonNumber,
    this.episodeNumber,
    this.posterPath, // Aggiungi questo parametro
  }) : super(key: key);

  @override
  State<StreamingWebView> createState() => _StreamingWebViewState();
}

class _StreamingWebViewState extends State<StreamingWebView> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  double? playbackPosition;
  bool hasInjectedJs = false;
  Timer? _autoSaveTimer; // Timer per il salvataggio automatico
  bool hasAttemptedReload = false; // Per tenere traccia dei tentativi di ricaricamento
  
@override
void initState() {
  super.initState();
  _loadSavedPosition();
  
  // Configura il timer per il salvataggio automatico ogni 30 secondi
  _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    if (playbackPosition != null && playbackPosition! > 0) {
      _savePlaybackPosition(showNotification: false);
    }
  });
  
  _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    // Aggiorna l'User-Agent per sembrare più un browser desktop
    ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    // Configura le impostazioni corrette per i media
    ..setBackgroundColor(const Color(0x00000000))
    ..enableZoom(false) // Disabilita lo zoom per migliorare la compatibilità
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            isLoading = true;
            hasError = false;
          });
          
          // Imposta un timeout più lungo (45 secondi)
          Future.delayed(Duration(seconds: 45), () {
            if (isLoading && mounted) {
              setState(() {
                isLoading = false;
                hasError = true;
                errorMessage = "Timeout di caricamento. Il server potrebbe essere irraggiungibile.";
              });
            }
          });
        },
        onPageFinished: (String url) {
          setState(() {
            isLoading = false;
          });
          
          // Abilita la riproduzione automatica dei media
          _controller.runJavaScript('''
            document.querySelectorAll('video, audio').forEach(media => {
              media.autoplay = true;
              media.setAttribute('playsinline', 'true');
              media.setAttribute('controls', 'true');
            });
          ''');
          
          // Inietta gli script nell'ordine corretto
          _injectAdBlocker();
          
          // Aggiungi un ritardo prima di iniettare il tracker per dare tempo al player di inizializzarsi
          Future.delayed(Duration(seconds: 2), () {
            _injectPlaybackTracker();
            hasInjectedJs = true;
          });
        },
        onWebResourceError: (WebResourceError error) {
          setState(() {
            hasError = true;
            errorMessage = "Errore ${error.errorCode}: ${error.description}";
            isLoading = false;
          });
          
          // Tenta di ricaricare solo per certi errori e se non ha già tentato
          if ((error.errorCode == -1 || error.errorCode == -2) && !hasAttemptedReload) {
            hasAttemptedReload = true;
            Future.delayed(Duration(seconds: 3), () {
              _controller.reload();
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          // Blocca reindirizzamenti a domini pubblicitari noti
          if (_isAdUrl(request.url)) {
            return NavigationDecision.prevent;
          }
          
          // Consenti solo i link che iniziano con l'URL di base
          if (request.url.startsWith('https://vixsrc.to/')) {
            return NavigationDecision.navigate;
          }
          
          // Blocca tutti gli altri reindirizzamenti
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Reindirizzamento bloccato"),
                duration: Duration(seconds: 1),
              ),
            );
          }
          
          return NavigationDecision.prevent;
        },
      ),
    )
    ..addJavaScriptChannel(
      'PlaybackChannel',
      onMessageReceived: (JavaScriptMessage message) {
        final newPosition = double.tryParse(message.message);
        if (newPosition != null) {
          setState(() {
            playbackPosition = newPosition;
          });
        }
      },
    )
    ..loadRequest(
      Uri.parse(widget.url),
      headers: {
        'Referer': 'https://vixsrc.to/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Upgrade-Insecure-Requests': '1',
        'X-Requested-With': 'com.example.StreamingAir',
        // Imposta un cookie direttamente nell'header
        'Cookie': 'allowVideo=true; domain=vixsrc.to',
      },
    );
    
  // Inizializza i cookie manualmente
  _setCookies();
}

// Metodo per impostare i cookie
Future<void> _setCookies() async {
  try {
    await _controller.runJavaScript('''
      document.cookie = "allowVideo=true; domain=vixsrc.to; path=/";
      document.cookie = "autoplay=true; domain=vixsrc.to; path=/";
    ''');
  } catch (e) {
    print('Errore nell\'impostazione dei cookie: $e');
  }
}
  
@override
void dispose() {
  // Cancella il timer quando la pagina viene chiusa
  _autoSaveTimer?.cancel();
  
  // Log per debugging
  print("StreamingWebView dispose - saving final position: $playbackPosition");
  
  // Salva la posizione finale quando l'utente esce
  if (playbackPosition != null && playbackPosition! > 0) {
    _savePlaybackPosition(showNotification: false);
  } else {
    print("No position to save on dispose");
  }
  
  super.dispose();
}   
  
  // Verifica se un URL è pubblicitario
  bool _isAdUrl(String url) {
    // Lista di domini pubblicitari comuni da bloccare
    final List<String> adDomains = [
      'ads.', 'ad.', 'adserver.', 'adclick.',
      'doubleclick.net', 'googleadservices.com', 'googlesyndication.com',
      'amazon-adsystem.com', 'adnxs.com', 'taboola.com',
      'outbrain.com', 'clicksor.com', 'clksite.com',
      'popads.net', 'popcash.net', 'propellerads.com',
      'exoclick.com', 'juicyads.com', 'clickadu.com',
      'advertserve.', 'cdn.adsafeprotected.com', 'banner.',
      'track.', 'counter.', 'pixel.', 'stat.',
      'affiliate.', 'promo.', 'redirect.'
    ];
    
    // Controlla se l'URL contiene domini pubblicitari
    for (var domain in adDomains) {
      if (url.contains(domain)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Inietta JavaScript per bloccare pubblicità
// Sostituisci il metodo _injectAdBlocker con questa versione migliorata
void _injectAdBlocker() {
  _controller.runJavaScript('''
    (function() {
      // Funzione ottimizzata per bloccare pubblicità e popup
      function blockAds() {
        // Selettori più completi per gli elementi pubblicitari
        const adSelectors = [
          'div[id*="google_ads_"]',
          'div[id*="ad-"], div[id*="ad_"]',
          'div[class*="ad-"], div[class*="ad_"]',
          'div[class*="ads-"], div[class*="ads_"]',
          'iframe[src*="ads"], iframe[src*="ad."]',
          'iframe[src*="doubleclick"], iframe[src*="googleads"]',
          'a[href*="adclick"], a[href*="doubleclick"]',
          'ins.adsbygoogle, .adsbygoogle',
          '.ad-container, .ad-wrapper, #ad-wrapper, #ad-container',
          '.popupOverlay, .popup-overlay, .modal-backdrop',
          '.adBox, .ad-box',
          'div[style*="z-index: 9999"]',
          'div[style*="position: fixed"][style*="width: 100%"][style*="height: 100%"]',
          // Selettori specifici per vixsrc.to
          '.show-ads, .ads-container, .ad-overlay',
          'div[class*="popup"], div[id*="popup"]',
          '.preroll-overlay, .midroll-overlay'
        ];
        
        // Rimuovi gli elementi corrispondenti
        adSelectors.forEach(selector => {
          const elements = document.querySelectorAll(selector);
          elements.forEach(el => {
            el.style.display = 'none';
            el.remove();
          });
        });
        
        // Pulisci i popup che appaiono sopra il contenuto
        const bodyElements = document.querySelectorAll('body > div:not([class]):not([id])');
        bodyElements.forEach(el => {
          const style = window.getComputedStyle(el);
          if (style.position === 'fixed' && style.zIndex > 100) {
            el.style.display = 'none';
            el.remove();
          }
        });
        
        // Rimuovi overlay modali
        const overlays = document.querySelectorAll('div[style*="position: fixed"]');
        overlays.forEach(el => {
          const style = window.getComputedStyle(el);
          if (style.zIndex > 1000 && (style.width === '100%' || style.width === '100vw') && 
              (style.height === '100%' || style.height === '100vh')) {
            el.style.display = 'none';
            el.remove();
          }
        });
        
        // Blocca anche i bottoni che aprono nuove finestre
        document.querySelectorAll('a[target="_blank"]').forEach(a => {
          a.setAttribute('target', '_self');
          a.addEventListener('click', function(e) {
            // Non bloccare link interni
            if (!a.href.startsWith('https://vixsrc.to')) {
              e.preventDefault();
              console.log('Link esterno bloccato:', a.href);
            }
          });
        });
      }
      
      // Esegui il blocco iniziale
      blockAds();
      
      // Configura un osservatore più performante per rilevare dinamicamente gli annunci
      const observer = new MutationObserver(function(mutations) {
        let shouldBlock = false;
        
        for (const mutation of mutations) {
          if (mutation.addedNodes.length > 0) {
            shouldBlock = true;
            break;
          }
        }
        
        if (shouldBlock) {
          blockAds();
        }
      });
      
      // Avvia l'osservazione con configurazione ottimizzata
      observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: false,
        characterData: false
      });
      
      // Blocca i pop-up in modo più efficace
      window.open = function() { return null; };
      
      // Sovrascrivi funzioni usate per i redirect
      try {
        // Salva le funzioni originali
        const _createElement = document.createElement;
        
        // Sovrascrivi createElement per bloccare script malevoli
        document.createElement = function(tagName) {
          const element = _createElement.call(document, tagName);
          if (tagName.toLowerCase() === 'script') {
            const originalSetAttribute = element.setAttribute;
            element.setAttribute = function(name, value) {
              if (name === 'src' && (
                  value.includes('ads') || 
                  value.includes('tracker') || 
                  value.includes('pop') || 
                  value.includes('banner')
                )) {
                console.log('Bloccato script malevolo:', value);
                return element;
              }
              return originalSetAttribute.call(this, name, value);
            };
          }
          return element;
        };
        
        // Prova un metodo alternativo per bloccare i redirect
        const oldLocation = location;
        Object.defineProperty(window, '_blockedLocation', {
          value: {},
          writable: false,
          configurable: false
        });
        
        // Cerca di intercettare tutte le proprietà di location
        ['href', 'replace', 'assign'].forEach(prop => {
          Object.defineProperty(window._blockedLocation, prop, {
            get: function() {
              console.log('Accesso a location.' + prop + ' intercettato');
              return oldLocation[prop];
            },
            set: function(val) {
              console.log('Tentativo di redirect bloccato a: ' + val);
              return true;
            }
          });
        });
        
        // Prova a sostituire window.location
        try {
          Object.defineProperty(window, 'location', {
            get: function() { return window._blockedLocation; }
          });
        } catch(e) {
          console.log('Non è stato possibile sovrascrivere completamente location');
        }
      } catch(e) {
        console.error('Errore nel bloccare i redirect:', e);
      }
      
      // Migliora il supporto HLS
      try {
        // Se hls.js è presente, assicurati che funzioni correttamente
        if (typeof Hls !== 'undefined') {
          console.log('HLS.js rilevato, ottimizzazione in corso...');
          // Verifica che il browser supporti MediaSource
          if (Hls.isSupported()) {
            console.log('Browser supporta HLS via MSE');
          } else {
            console.log('Browser non supporta HLS via MSE, utilizzo fallback nativo');
          }
        }
      } catch(e) {
        console.log('HLS.js non rilevato:', e);
      }
    })();
  ''');
}
  
  // Carica la posizione salvata
  Future<void> _loadSavedPosition() async {
    final savedPosition = await PlaybackPositionManager.getPosition(
      widget.mediaType, 
      widget.id, 
      widget.seasonNumber, 
      widget.episodeNumber
    );
    
    if (savedPosition != null) {
      setState(() {
        playbackPosition = savedPosition;
      });
    }
  }
  
  // Inietta JavaScript per tracciare la posizione di riproduzione
// Sostituisci l'attuale metodo _injectPlaybackTracker con questa versione migliorata
void _injectPlaybackTracker() {
  _controller.runJavaScript('''
    try {
      // Tracciamento migliorato con retry più robusti
      let videoCheckInterval;
      let retryCount = 0;
      const maxRetries = 60; // Più tentativi prima di arrendersi
      
      function findVideoElement() {
        // Cerca in diversi formati di player video
        const videoElements = document.querySelectorAll('video');
        if (videoElements.length > 0) {
          return videoElements[0];
        }
        
        // Prova a cercare anche elementi con classe tipica dei player
        const videoPlayers = document.querySelectorAll('.video-js, .plyr, .vjs-tech, .hls-player');
        for (const player of videoPlayers) {
          const video = player.querySelector('video');
          if (video) return video;
        }
        
        // Cerca anche negli iframe
        const iframes = document.querySelectorAll('iframe');
        for (const iframe of iframes) {
          try {
            const iframeVideos = iframe.contentDocument?.querySelectorAll('video');
            if (iframeVideos && iframeVideos.length > 0) {
              return iframeVideos[0];
            }
          } catch(e) {
            // Errore di cross-origin, ignora
          }
        }
        
        return null;
      }
      
      // Controlla se c'è un video e configura il tracking
      function setupVideo() {
        const video = findVideoElement();
        if (video) {
          console.log('Video player trovato, configurazione in corso...');
          
          // Pulisci l'intervallo di controllo se il video è stato trovato
          if (videoCheckInterval) {
            clearInterval(videoCheckInterval);
          }
          
          // Abilita la riproduzione automatica e i controlli
          video.autoplay = true;
          video.controls = true;
          video.setAttribute('playsinline', 'true');
          
          // Imposta la posizione se disponibile con un ritardo per garantire il caricamento
          ${playbackPosition != null ? "setTimeout(() => { try { video.currentTime = $playbackPosition; video.play().catch(e => console.log('Errore play:', e)); } catch(e) { console.error('Errore nel settare la posizione:', e); } }, 2000);" : ""}
          
          // Imposta gli handler degli eventi
          try {
            // Controlla la posizione ogni 5 secondi durante la riproduzione
            setInterval(function() {
              if (!video.paused && video.currentTime > 0) {
                PlaybackChannel.postMessage(video.currentTime.toString());
              }
            }, 5000);
            
            // Salva quando l'utente mette in pausa
            video.addEventListener('pause', function() {
              if (video.currentTime > 0) {
                PlaybackChannel.postMessage(video.currentTime.toString());
              }
            });
            
            // Salva quando il video termina
            video.addEventListener('ended', function() {
              PlaybackChannel.postMessage(video.currentTime.toString());
            });
            
            // Aggiungi anche altri eventi per maggiore affidabilità
            video.addEventListener('seeked', function() {
              PlaybackChannel.postMessage(video.currentTime.toString());
            });
            
            console.log('Eventi configurati con successo');
          } catch(e) {
            console.error('Errore nella configurazione degli eventi:', e);
          }
        } else {
          retryCount++;
          if (retryCount > maxRetries) {
            clearInterval(videoCheckInterval);
            console.error('Impossibile trovare un player video dopo ' + maxRetries + ' tentativi');
          }
        }
      }
      
      // Controlla più frequentemente all'inizio e poi rallenta
      videoCheckInterval = setInterval(() => {
        setupVideo();
        // Riduce la frequenza dopo 10 tentativi
        if (retryCount === 10) {
          clearInterval(videoCheckInterval);
          videoCheckInterval = setInterval(setupVideo, 1000);
        }
      }, 500);
      
      // Prima esecuzione immediata
      setupVideo();
    } catch(e) {
      console.error('Errore nel tracciamento della riproduzione:', e);
    }
  ''');
}
  
  // Salva la posizione di riproduzione quando si esce
Future<void> _savePlaybackPosition({bool showNotification = true}) async {
  if (playbackPosition != null && playbackPosition! > 0) {
    // Salva localmente
    await PlaybackPositionManager.savePosition(
      widget.mediaType, 
      widget.id, 
      widget.seasonNumber, 
      widget.episodeNumber, 
      playbackPosition!
    );
    
    // Se l'utente è loggato, salva anche nel database
    if (AuthService.isLoggedIn && AuthService.userId != null) {
      // Aggiungi logging per il debug
      print("Saving to database - UserID: ${AuthService.userId}, Content: ${widget.title}, Position: $playbackPosition");
      
      final watchedContent = WatchedContent(
        userId: AuthService.userId!,
        contentId: widget.id,
        contentType: widget.mediaType,
        title: widget.title,
        posterPath: widget.posterPath,
        position: playbackPosition!,
        lastWatched: DateTime.now(),
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );
      
      // Usa await e verifica il risultato
      final success = await WatchedContentService.saveWatchedContent(watchedContent);
      print("Save to database result: $success");
    } else {
      print("User not logged in, not saving to database");
    }
    
    if (showNotification && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Posizione salvata: ${PlaybackPositionManager.formatTime(playbackPosition!)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
  
  Future<void> _openInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Non posso aprire il link: $url")),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _savePlaybackPosition();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141420),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2133),
          elevation: 0,
          title: Text(widget.title),
          actions: [
            if (playbackPosition != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E72E4).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF5E72E4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    PlaybackPositionManager.formatTime(playbackPosition!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E72E4),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: 'Blocca pubblicità',
              onPressed: () => _injectAdBlocker(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Ricarica',
              onPressed: () => _controller.reload(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'browser') {
                  _openInBrowser(widget.url);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'browser',
                  child: ListTile(
                    leading: Icon(Icons.open_in_browser),
                    title: Text('Apri nel browser'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF5E72E4),
                  ),
                ),
              ),
            if (hasError)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2133),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Errore nel caricamento',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Riprova'),
                            onPressed: () => _controller.reload(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5E72E4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(120, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Apri nel Browser'),
                            onPressed: () => _openInBrowser(widget.url),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF262942),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(120, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text(
                'Problemi? Apri nel Browser',
                style: TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262942),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              onPressed: () => _openInBrowser(widget.url),
            ),
          ),
        ),
      ),
    );
  }
}

// Classe di servizio per condividere dati tra le pagine
class SearchService {
  static String? pendingSearchQuery;
  static String? pendingSearchType;
  
  static void setSearch(String query, String type) {
    pendingSearchQuery = query;
    pendingSearchType = type;
  }
  
  static void clearSearch() {
    pendingSearchQuery = null;
    pendingSearchType = null;
  }
}

// Servizio per gestire i dati del catalogo e mantenerli tra le navigazioni
class CatalogService {
  // Singleton pattern
  static final CatalogService _instance = CatalogService._internal();
  factory CatalogService() => _instance;
  CatalogService._internal();
  
  static const String apiKey = "80157e25b43ede5bf3e4114fa3845d18";
  
  // Dati per film
  String _movieSearchQuery = '';
  List<CatalogItem> _movieItems = [];
  List<int> _movieTmdbIds = [];
  bool _isLoadingMovie = false;
  bool _isLoadingMoreMovie = false;
  String _movieError = '';
  String _movieRawResponse = '';
  int _loadedMovieItemsCount = 0;
  int _totalMovieItems = 0;
  bool _hasInitializedMovie = false;
  
  // Dati per serie TV
  String _tvSearchQuery = '';
  List<CatalogItem> _tvItems = [];
  List<int> _tvTmdbIds = [];
  bool _isLoadingTv = false;
  bool _isLoadingMoreTv = false;
  String _tvError = '';
  String _tvRawResponse = '';
  int _loadedTvItemsCount = 0;
  int _totalTvItems = 0;
  bool _hasInitializedTv = false;
  
  // Mappe per i generi
  Map<int, String> movieGenres = {};
  Map<int, String> tvGenres = {};
  bool _hasLoadedGenres = false;
  
  // Getter per i dati basati sul tipo selezionato
  String getSearchQuery(String type) => type == 'movie' ? _movieSearchQuery : _tvSearchQuery;
  List<CatalogItem> getItems(String type) => type == 'movie' ? _movieItems : _tvItems;
  List<int> getTmdbIds(String type) => type == 'movie' ? _movieTmdbIds : _tvTmdbIds;
  bool isLoading(String type) => type == 'movie' ? _isLoadingMovie : _isLoadingTv;
  bool isLoadingMore(String type) => type == 'movie' ? _isLoadingMoreMovie : _isLoadingMoreTv;
  String getError(String type) => type == 'movie' ? _movieError : _tvError;
  String getRawResponse(String type) => type == 'movie' ? _movieRawResponse : _tvRawResponse;
  int getLoadedItemsCount(String type) => type == 'movie' ? _loadedMovieItemsCount : _loadedTvItemsCount;
  int getTotalItems(String type) => type == 'movie' ? _totalMovieItems : _totalTvItems;
  bool hasInitialized(String type) => type == 'movie' ? _hasInitializedMovie : _hasInitializedTv;
  
  // Setter per i valori
  void setSearchQuery(String type, String query) {
    if (type == 'movie') {
      _movieSearchQuery = query;
    } else {
      _tvSearchQuery = query;
    }
  }
  
  void setLoading(String type, bool loading) {
    if (type == 'movie') {
      _isLoadingMovie = loading;
    } else {
      _isLoadingTv = loading;
    }
  }
  
  void setLoadingMore(String type, bool loading) {
    if (type == 'movie') {
      _isLoadingMoreMovie = loading;
    } else {
      _isLoadingMoreTv = loading;
    }
  }
  
  void setError(String type, String error) {
    if (type == 'movie') {
      _movieError = error;
    } else {
      _tvError = error;
    }
  }
  
  void setRawResponse(String type, String response) {
    if (type == 'movie') {
      _movieRawResponse = response;
    } else {
      _tvRawResponse = response;
    }
  }
  
  void setTmdbIds(String type, List<int> ids) {
    if (type == 'movie') {
      _movieTmdbIds = ids;
      _totalMovieItems = ids.length;
    } else {
      _tvTmdbIds = ids;
      _totalTvItems = ids.length;
    }
  }
  
  void setItems(String type, List<CatalogItem> items) {
    if (type == 'movie') {
      _movieItems = items;
    } else {
      _tvItems = items;
    }
  }
  
  void setLoadedItemsCount(String type, int count) {
    if (type == 'movie') {
      _loadedMovieItemsCount = count;
    } else {
      _loadedTvItemsCount = count;
    }
  }
  
  void setInitialized(String type, bool initialized) {
    if (type == 'movie') {
      _hasInitializedMovie = initialized;
    } else {
      _hasInitializedTv = initialized;
    }
  }
  
  // Funzione per caricare i generi
  Future<void> loadGenres() async {
    if (_hasLoadedGenres) return;
    
    try {
      // Carica generi film
      final movieGenresUrl = 'https://api.themoviedb.org/3/genre/movie/list?api_key=$apiKey&language=it';
      final movieGenresResponse = await http.get(Uri.parse(movieGenresUrl));
      if (movieGenresResponse.statusCode == 200) {
        final data = json.decode(movieGenresResponse.body);
        if (data['genres'] != null) {
          for (var genre in data['genres']) {
            movieGenres[genre['id']] = genre['name'];
          }
        }
      }
      
      // Carica generi serie TV
      final tvGenresUrl = 'https://api.themoviedb.org/3/genre/tv/list?api_key=$apiKey&language=it';
      final tvGenresResponse = await http.get(Uri.parse(tvGenresUrl));
      if (tvGenresResponse.statusCode == 200) {
        final data = json.decode(tvGenresResponse.body);
        if (data['genres'] != null) {
          for (var genre in data['genres']) {
            tvGenres[genre['id']] = genre['name'];
          }
        }
      }
      
      _hasLoadedGenres = true;
    } catch (e) {
      print('Errore nel caricamento dei generi: $e');
    }
  }
  
  // Funzione per la ricerca nel catalogo
  Future<void> searchInCatalog(String query, String type, Function setState) async {
    setLoading(type, true);
    setError(type, '');
    setItems(type, []);
    setSearchQuery(type, query);
    
    try {
      final searchType = type == 'movie' ? 'movie' : 'tv';
      final url = 'https://api.themoviedb.org/3/search/$searchType?api_key=$apiKey&query=$query&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          List<CatalogItem> searchResults = [];
          List<Map<int, String>> genreMaps = [movieGenres, tvGenres];
          
          for (var item in data['results']) {
            searchResults.add(CatalogItem.fromTmdbJson(item, type, genreMaps));
          }
          
          setState(() {
            setItems(type, searchResults);
            setLoading(type, false);
          });
        } else {
          setState(() {
            setError(type, 'Nessun risultato trovato per "$query"');
            setLoading(type, false);
          });
        }
      } else {
        setState(() {
          setError(type, 'Errore nella ricerca: ${response.statusCode}');
          setLoading(type, false);
        });
      }
    } catch (e) {
      setState(() {
        setError(type, 'Errore: $e');
        setLoading(type, false);
      });
    }
  }
  
  // Funzione per caricare gli ID del catalogo
  Future<void> fetchCatalogIds(String type, Function setState) async {
    // Se già inizializzato e non c'è una ricerca attiva, usa i dati esistenti
    if (hasInitialized(type) && getSearchQuery(type).isEmpty) {
      return;
    }
    
    // Se c'è una query di ricerca, esegui una ricerca invece
    if (getSearchQuery(type).isNotEmpty) {
      return searchInCatalog(getSearchQuery(type), type, setState);
    }
    
    setState(() {
      setLoading(type, true);
      setError(type, '');
      setItems(type, []);
      setTmdbIds(type, []);
      setRawResponse(type, '');
      setLoadedItemsCount(type, 0);
    });

    try {
      // Ottiene la lista degli ID TMDB
      final url = 'https://vixsrc.to/api/list/$type?lang=it';
      final response = await http.get(Uri.parse(url));
      
      setState(() {
        setRawResponse(type, 'URL: $url\n\nStatus: ${response.statusCode}\n\nResponse body:\n${response.body}');
      });
      
      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          setState(() {
            setError(type, 'Errore nel formato della risposta: $e');
            setLoading(type, false);
          });
          return;
        }
        
        List<int> tmdbIds = [];
        
        if (data is List) {
          for (var item in data) {
            if (item is Map && item.containsKey('tmdb_id')) {
              final tmdbId = item['tmdb_id'];
              if (tmdbId != null) {
                try {
                  final id = tmdbId is int ? tmdbId : int.parse(tmdbId.toString());
                  tmdbIds.add(id);
                } catch (e) {
                  // Skip invalid IDs
                }
              }
            }
          }
        }
        
        if (tmdbIds.isEmpty) {
          setState(() {
            setError(type, 'Nessun ID TMDB valido trovato nella risposta');
            setLoading(type, false);
          });
          return;
        }
        
        // Salva tutti gli ID per il caricamento progressivo
        setState(() {
          setTmdbIds(type, tmdbIds);
        });
        
        // Carica solo i primi _initialLoadCount titoli inizialmente
        final initialLoadCount = 20;
        final initialBatchSize = tmdbIds.length < initialLoadCount ? tmdbIds.length : initialLoadCount;
        final initialBatch = tmdbIds.sublist(0, initialBatchSize);
        
        // Crea placeholder per i primi elementi
        List<CatalogItem> initialPlaceholders = initialBatch.map((id) => CatalogItem(
          id: id,
          title: 'Caricamento...',
          mediaType: type,
        )).toList();
        
        setState(() {
          setItems(type, initialPlaceholders);
        });
        
        // Carica i dettagli per il batch iniziale
        await fetchTitlesForIds(type, initialBatch, 0, setState);
        
        setState(() {
          setLoading(type, false);
          setLoadedItemsCount(type, initialBatchSize);
          setInitialized(type, true);
        });
        
      } else {
        setState(() {
          setError(type, 'Errore ${response.statusCode}: ${response.reasonPhrase}');
          setLoading(type, false);
        });
      }
    } catch (e) {
      setState(() {
        setError(type, 'Errore di connessione: $e');
        setLoading(type, false);
      });
    }
  }
  
  // Funzione per caricare più titoli
  Future<void> loadMoreTitles(String type, Function setState) async {
    if (isLoadingMore(type) || getLoadedItemsCount(type) >= getTmdbIds(type).length) {
      return;
    }
    
    setState(() {
      setLoadingMore(type, true);
    });
    
    // Calcola gli indici per il prossimo batch di ID da caricare
    final loadMoreCount = 10;
    final end = (getLoadedItemsCount(type) + loadMoreCount <= getTmdbIds(type).length) 
        ? getLoadedItemsCount(type) + loadMoreCount 
        : getTmdbIds(type).length;
    
    // Ottieni il prossimo batch di ID
    final nextBatch = getTmdbIds(type).sublist(getLoadedItemsCount(type), end);
    
    // Aggiungi immediatamente item di "caricamento" alla lista
    final startIndex = getItems(type).length;
    List<CatalogItem> updatedItems = List.from(getItems(type));
    
    for (final id in nextBatch) {
      updatedItems.add(CatalogItem(
        id: id,
        title: 'Caricamento...',
        mediaType: type,
      ));
    }
    
    setState(() {
      setItems(type, updatedItems);
    });
    
    // Carica i dettagli per questi ID
    await fetchTitlesForIds(type, nextBatch, startIndex, setState);
    
    setState(() {
      setLoadingMore(type, false);
      setLoadedItemsCount(type, end);
    });
  }
  
  // Funzione per caricare i titoli per un insieme specifico di ID
  Future<void> fetchTitlesForIds(String type, List<int> ids, int startIndex, Function setState) async {
    final tmdbType = type == 'tv' ? 'tv' : 'movie';
    
    // Limita richieste simultanee
    final maxConcurrentRequests = 5;
    
    for (int i = 0; i < ids.length; i += maxConcurrentRequests) {
      final end = (i + maxConcurrentRequests < ids.length) ? i + maxConcurrentRequests : ids.length;
      final chunk = ids.sublist(i, end);
      
      // Richieste parallele per questo blocco
      final results = await Future.wait(
        chunk.map((id) async {
          try {
            final tmdbUrl = 'https://api.themoviedb.org/3/$tmdbType/$id?api_key=$apiKey&language=it';
            final tmdbResponse = await http.get(Uri.parse(tmdbUrl));
            
            if (tmdbResponse.statusCode == 200) {
              final tmdbData = json.decode(tmdbResponse.body);
              
              // Lista dei generi da passare al costruttore
              List<Map<int, String>> genreMaps = [movieGenres, tvGenres];
              
              final item = CatalogItem.fromTmdbJson(tmdbData, tmdbType, genreMaps);
              return item;
            }
          } catch (e) {
            // Ignora errori individuali
          }
          
          // Se non riusciamo a ottenere i dettagli, usa un item con dati minimi
          return CatalogItem(
            id: id,
            title: 'ID: $id',
            mediaType: tmdbType,
          );
        }),
      );
      
      // Aggiorna gli elementi corrispondenti nella lista
      List<CatalogItem> updatedItems = List.from(getItems(type));
      
      for (int j = 0; j < results.length; j++) {
        final itemIndex = startIndex + i + j;
        if (itemIndex < updatedItems.length) {
          updatedItems[itemIndex] = results[j];
        }
      }
      
      setState(() {
        setItems(type, updatedItems);
      });
    }
  }
}

// Gestore dei contenuti salvati
class SavedContentManager {
  static const String _savedContentKey = 'saved_content';
  
  // Salva un elemento
  static Future<bool> saveItem(CatalogItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedItems = prefs.getStringList(_savedContentKey) ?? [];
      
      // Converti l'elemento in JSON e controlla se esiste già
      String itemJson = json.encode({
        'id': item.id,
        'title': item.title,
        'posterPath': item.posterPath,
        'mediaType': item.mediaType,
        'releaseDate': item.releaseDate,
        'overview': item.overview,
        'runtime': item.runtime,
      });
      
      // Verifica se l'elemento è già salvato
      if (!savedItems.any((savedItem) {
        Map<String, dynamic> savedItemMap = json.decode(savedItem);
        return savedItemMap['id'] == item.id && savedItemMap['mediaType'] == item.mediaType;
      })) {
        savedItems.add(itemJson);
        await prefs.setStringList(_savedContentKey, savedItems);
      }
      return true;
    } catch (e) {
      print('Errore nel salvataggio: $e');
      return false;
    }
  }
  
  // Rimuovi un elemento
  static Future<bool> removeItem(int id, String mediaType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedItems = prefs.getStringList(_savedContentKey) ?? [];
      
      savedItems.removeWhere((savedItem) {
        Map<String, dynamic> savedItemMap = json.decode(savedItem);
        return savedItemMap['id'] == id && savedItemMap['mediaType'] == mediaType;
      });
      
      await prefs.setStringList(_savedContentKey, savedItems);
      return true;
    } catch (e) {
      print('Errore nella rimozione: $e');
      return false;
    }
  }
  
  // Controlla se un elemento è salvato
  static Future<bool> isItemSaved(int id, String mediaType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedItems = prefs.getStringList(_savedContentKey) ?? [];
      
      return savedItems.any((savedItem) {
        Map<String, dynamic> savedItemMap = json.decode(savedItem);
        return savedItemMap['id'] == id && savedItemMap['mediaType'] == mediaType;
      });
    } catch (e) {
      print('Errore nel controllo: $e');
      return false;
    }
  }
  
  // Ottieni tutti gli elementi salvati
  static Future<List<CatalogItem>> getAllSavedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedItems = prefs.getStringList(_savedContentKey) ?? [];
      
      return savedItems.map((savedItem) {
        Map<String, dynamic> map = json.decode(savedItem);
        return CatalogItem(
          id: map['id'],
          title: map['title'],
          posterPath: map['posterPath'],
          mediaType: map['mediaType'],
          releaseDate: map['releaseDate'],
          overview: map['overview'],
          runtime: map['runtime'],
        );
      }).toList();
    } catch (e) {
      print('Errore nel recupero: $e');
      return [];
    }
  }
}

class WatchedContentService {
  static const String _endpoint = '/watched_content.php';
  
  // Salva un contenuto guardato
  static Future<bool> saveWatchedContent(WatchedContent content) async {
    if (!AuthService.isLoggedIn) {
      print("Not saving watched content: user not logged in");
      return false;
    }
    
    try {
      print("Preparing to save watched content to ${AuthService.baseUrl}$_endpoint");
      final jsonData = {
        'action': 'save',
        'content': content.toJson(),
      };
      print("Request data: ${json.encode(jsonData)}");
      
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}$_endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(jsonData),
      );
      
      print("Server response status: ${response.statusCode}");
      print("Server response body: ${response.body}");
      
      return response.statusCode == 200;
    } catch (e) {
      print('Errore nel salvataggio del contenuto guardato: $e');
      return false;
    }
  }
  
  // Ottieni i contenuti guardati per l'utente corrente
  static Future<List<WatchedContent>> getWatchedContent() async {
    if (!AuthService.isLoggedIn || AuthService.userId == null) return [];
    
    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}$_endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': 'get',
          'user_id': AuthService.userId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['content'] is List) {
          return (data['content'] as List)
              .map((item) => WatchedContent.fromJson(item))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Errore nel recupero dei contenuti guardati: $e');
      return [];
    }
  }
  
  // Aggiorna la posizione di PlaybackPositionManager quando un utente fa login
  static Future<void> syncWatchedContentWithPlaybackManager() async {
    final watchedContent = await getWatchedContent();
    
    for (var content in watchedContent) {
      await PlaybackPositionManager.savePosition(
        content.contentType,
        content.contentId,
        content.seasonNumber,
        content.episodeNumber,
        content.position,
      );
    }
  }
}


// Pagina principale di ricerca
class StreamingHomePage extends StatefulWidget {
  const StreamingHomePage({super.key});

  @override
  State<StreamingHomePage> createState() => _StreamingHomePageState();
}

class _StreamingHomePageState extends State<StreamingHomePage> {
  String choice = '';
  final TextEditingController titleController = TextEditingController();
  final TextEditingController seasonController = TextEditingController();
  final TextEditingController episodeController = TextEditingController();
  String result = '';
  String? linkToOpen;
  bool isLoading = false;
  CatalogItem? foundItem; // Per memorizzare l'elemento trovato

  static const apiKey = "80157e25b43ede5bf3e4114fa3845d18";

  Future<void> search() async {
    setState(() { isLoading = true; result = ""; linkToOpen = null; foundItem = null; });
    String titolo = titleController.text.trim();
    if (titolo.isEmpty) {
      setState(() {
        result = "Inserisci il titolo.";
        isLoading = false;
      });
      return;
    }

    if (choice == 'film') {
      final urlF = "https://api.themoviedb.org/3/search/movie";
      final response = await http.get(Uri.parse("$urlF?api_key=$apiKey&query=$titolo"));
      final data = json.decode(response.body);
      if (data["results"] != null && data["results"].isNotEmpty) {
        final tmdbId = data["results"][0]["id"];
        final url = "https://vixsrc.to/movie/$tmdbId";
        
        // Crea un oggetto CatalogItem per il film trovato
        final item = CatalogItem(
          id: tmdbId,
          title: data["results"][0]["title"] ?? titolo,
          posterPath: data["results"][0]["poster_path"],
          overview: data["results"][0]["overview"],
          releaseDate: data["results"][0]["release_date"],
          voteAverage: data["results"][0]["vote_average"]?.toDouble(),
          mediaType: 'movie',
        );
        
        setState(() {
          result = "Film trovato! Guarda in WebView o apri nel browser:";
          linkToOpen = url;
          foundItem = item;
          isLoading = false;
        });
      } else {
        setState(() {
          result = "Film non trovato.";
          isLoading = false;
        });
      }
    } else if (choice == 'serie') {
      final stagione = seasonController.text.trim();
      final episodio = episodeController.text.trim();
      if (stagione.isEmpty || episodio.isEmpty) {
        setState(() {
          result = "Inserisci stagione ed episodio.";
          isLoading = false;
        });
        return;
      }
      final urlS = "https://api.themoviedb.org/3/search/tv";
      final response = await http.get(Uri.parse("$urlS?api_key=$apiKey&query=$titolo"));
      final data = json.decode(response.body);
      if (data["results"] != null && data["results"].isNotEmpty) {
        final tmdbId = data["results"][0]["id"];
        final url = "https://vixsrc.to/tv/$tmdbId/$stagione/$episodio";
        
        // Crea un oggetto CatalogItem per la serie trovata
        final item = CatalogItem(
          id: tmdbId,
          title: data["results"][0]["name"] ?? titolo,
          posterPath: data["results"][0]["poster_path"],
          overview: data["results"][0]["overview"],
          releaseDate: data["results"][0]["first_air_date"],
          voteAverage: data["results"][0]["vote_average"]?.toDouble(),
          mediaType: 'tv',
        );
        
        setState(() {
          result = "Serie trovata! Guarda in WebView o apri nel browser:";
          linkToOpen = url;
          foundItem = item;
          isLoading = false;
        });
      } else {
        setState(() {
          result = "Serie non trovata.";
          isLoading = false;
        });
      }
    } else {
      setState(() {
        result = "Scegli Film o Serie.";
        isLoading = false;
      });
    }
  }

  // Apri nel browser esterno
  Future<void> openInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Non posso aprire il link: $url"))
      );
    }
  }

  // Apri in WebView
void openInWebView(String url) {
  if (foundItem == null) return;
  
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => StreamingWebView(
        url: url,
        title: foundItem!.title,
        mediaType: foundItem!.mediaType,
        id: foundItem!.id,
        posterPath: foundItem!.posterPath,
        seasonNumber: choice == 'serie' ? int.tryParse(seasonController.text) : null,
        episodeNumber: choice == 'serie' ? int.tryParse(episodeController.text) : null,
      ),
    ),
  );
}

  void copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    
    // Mostra feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Link copiato negli appunti!"))
    );
  }
  
  // Pulisce i risultati quando si cambia tipo di ricerca
  void _resetResults() {
    setState(() {
      result = "";
      linkToOpen = null;
      foundItem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141420),
        elevation: 0,
        title: const Text('Cerca contenuti'),
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF262942),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Cerca film o serie...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Tab per Film/Serie
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildTypeButton('Film', 'film'),
                const SizedBox(width: 16),
                _buildTypeButton('Serie', 'serie'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Resto del contenuto
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form di ricerca esistente ma con stile aggiornato
                  if (choice == 'serie') ...[
                    _buildRoundedTextField(
                      controller: seasonController,
                      labelText: "Stagione",
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildRoundedTextField(
                      controller: episodeController,
                      labelText: "Episodio",
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Pulsante di ricerca
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E72E4),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Cerca", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  
                  // Risultati della ricerca con il nuovo stile
                  if (result.isNotEmpty) ..._buildSearchResults(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypeButton(String label, String value) {
    final isSelected = choice == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            choice = value;
            _resetResults();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFF262942),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: labelText,
        filled: true,
        fillColor: const Color(0xFF262942),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16),
    );
  }
  
  List<Widget> _buildSearchResults() {
    return [
      const SizedBox(height: 24),
      Text(
        result,
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      if (linkToOpen != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF262942),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  linkToOpen!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5E72E4),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Color(0xFF5E72E4)),
                onPressed: () => copyLink(linkToOpen!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Guarda in WebView', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E72E4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => openInWebView(linkToOpen!),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Apri nel Browser', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF262942),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => openInBrowser(linkToOpen!),
          ),
        ),
        if (foundItem != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.info),
            label: const Text('Visualizza Dettagli', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2133),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) => 
                    DetailPage(item: foundItem!),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    var begin = const Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ],
    ];
  }
}

// Pagina di visualizzazione del catalogo
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final CatalogService _catalogService = CatalogService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'movie'; // Default a film
  final FocusNode _searchFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    
    // Carica i generi all'avvio
    _catalogService.loadGenres();
    
    // Controlla se c'è una ricerca in sospeso
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SearchService.pendingSearchQuery != null && SearchService.pendingSearchType != null) {
        // Imposta il tipo corrente
        _selectedType = SearchService.pendingSearchType!;
        
        // Imposta il testo della ricerca
        _searchController.text = SearchService.pendingSearchQuery!;
        
        // Esegui la ricerca
        _performSearch();
        
        // Pulisci la ricerca in sospeso
        SearchService.clearSearch();
      } else {
        // Altrimenti carica il catalogo normalmente
        _loadCatalog();
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  // Carica il catalogo
  Future<void> _loadCatalog() async {
    await _catalogService.fetchCatalogIds(_selectedType, setState);
  }
  
  // Carica più titoli
  Future<void> _loadMore() async {
    await _catalogService.loadMoreTitles(_selectedType, setState);
  }
  
  // Esegue una ricerca
  Future<void> _performSearch() async {
    // Nascondi la tastiera
    FocusScope.of(context).unfocus();
    
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      // Se la query è vuota, carica il catalogo normale
      _catalogService.setSearchQuery(_selectedType, '');
      _loadCatalog();
      return;
    }
    
    // Esegui la ricerca
    await _catalogService.searchInCatalog(query, _selectedType, setState);
  }
  
  // Naviga alla pagina di dettaglio
  void _navigateToDetailPage(CatalogItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => DetailPage(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Animazione dal basso verso l'alto
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141420),
        elevation: 0,
        title: const Text('Catalogo'),
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF262942),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Cerca ${_selectedType == 'movie' ? 'film' : 'serie TV'}...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _catalogService.setSearchQuery(_selectedType, '');
                      _loadCatalog();
                      _searchFocusNode.unfocus();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: (_) => _performSearch(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          
          // Pulsanti Film/Serie simili a quelli nella pagina Cerca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildTypeButton('Film', 'movie'),
                const SizedBox(width: 16),
                _buildTypeButton('Serie TV', 'tv'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contenuto principale
          Expanded(
            child: _buildContentList(_selectedType),
          ),
        ],
      ),
    );
  }
  
  // Pulsante per il tipo di contenuto (film/serie)
  Widget _buildTypeButton(String label, String value) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedType != value) {
            setState(() {
              _selectedType = value;
            });
            _loadCatalog();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFF262942),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContentList(String type) {
    // Se è in caricamento, mostra il loader
    if (_catalogService.isLoading(type)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF5E72E4),
            ),
            const SizedBox(height: 20),
            Text(
              'Caricamento in corso...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Se c'è un errore, mostra il messaggio
    if (_catalogService.getError(type).isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Errore',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _catalogService.getError(type),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E72E4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadCatalog,
            ),
          ],
        ),
      );
    }
    
    final items = _catalogService.getItems(type);
    
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun risultato trovato',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }
    
    // Costruisci la griglia con gli elementi
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Implementa il caricamento infinito
        if (!_catalogService.isLoadingMore(type) &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length + (_catalogService.isLoadingMore(type) ? 1 : 0),
        itemBuilder: (context, index) {
          // Se siamo all'ultimo elemento e stiamo caricando di più
          if (index == items.length) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2133).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5E72E4),
                ),
              ),
            );
          }
          
          final item = items[index];
          return _buildCatalogItemCard(item);
        },
      ),
    );
  }
  
  Widget _buildCatalogItemCard(CatalogItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2133),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToDetailPage(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'poster_${item.id}_${item.mediaType}',
                    child: item.posterPath != null
                      ? Image.network(
                          'https://image.tmdb.org/t/p/w342${item.posterPath}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF262942),
                            child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF262942),
                          child: const Icon(Icons.movie, size: 40, color: Colors.grey),
                        ),
                  ),
                  
                  // Gradiente scuro in basso per migliorare leggibilità
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Badge per tipo media e voto
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.mediaType == 'movie' ? 'Film' : 'TV',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  if (item.voteAverage != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              item.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Titolo e anno
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                    Text(
                      item.releaseDate!.length >= 4 ? item.releaseDate!.substring(0, 4) : item.releaseDate!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

// Pagina per visualizzare i contenuti salvati
class SavedContentPage extends StatefulWidget {
  const SavedContentPage({super.key});

  @override
  State<SavedContentPage> createState() => _SavedContentPageState();
}

class _SavedContentPageState extends State<SavedContentPage> {
  List<CatalogItem> savedItems = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }
  
  // Carica gli elementi salvati
  Future<void> _loadSavedItems() async {
    setState(() {
      isLoading = true;
    });
    
    final items = await SavedContentManager.getAllSavedItems();
    
    setState(() {
      savedItems = items;
      isLoading = false;
    });
  }
  
  // Rimuovi un elemento dalla lista
  void _removeItem(int id, String mediaType) async {
    final success = await SavedContentManager.removeItem(id, mediaType);
    if (success) {
      setState(() {
        savedItems.removeWhere((item) => item.id == id && item.mediaType == mediaType);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contenuto rimosso dai preferiti')),
        );
      }
    }
  }
  
  // Apri la pagina di dettaglio per un elemento
  void _openDetailPage(CatalogItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => DetailPage(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Animazione dal basso verso l'alto
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) => _loadSavedItems()); // Ricarica gli elementi quando torni indietro
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141420),
        elevation: 0,
        title: const Text('Contenuti Salvati'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedItems,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E72E4)))
          : savedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text(
                        'Nessun contenuto salvato',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'I tuoi film e serie preferiti appariranno qui',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'Cerca contenuti',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E72E4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          minimumSize: const Size(200, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Vai alla pagina di ricerca
                          (context.findAncestorStateOfType<_MainPageState>())
                              ?._onItemTapped(0);
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: savedItems.length,
                  itemBuilder: (context, index) {
                    final item = savedItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2133),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Dismissible(
                        key: Key('saved_${item.id}_${item.mediaType}'),
                        background: Container(
                          color: Colors.red[900],
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _removeItem(item.id, item.mediaType);
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Hero(
                            tag: 'poster_${item.id}_${item.mediaType}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.posterPath != null
                                  ? Image.network(
                                      'https://image.tmdb.org/t/p/w92${item.posterPath}',
                                      width: 50,
                                      height: 75,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            width: 50,
                                            height: 75,
                                            color: const Color(0xFF262942),
                                            child: const Icon(Icons.movie, size: 30, color: Colors.grey),
                                          ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 75,
                                      color: const Color(0xFF262942),
                                      child: const Icon(Icons.movie, size: 30, color: Colors.grey),
                                    ),
                            ),
                          ),
                          title: Hero(
                            tag: 'title_${item.id}_${item.mediaType}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262942),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.mediaType == 'movie' ? 'Film' : 'Serie TV',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                              if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                                Text(
                                  "Anno: ${item.releaseDate!.length >= 4 
                                      ? item.releaseDate!.substring(0, 4) 
                                      : item.releaseDate!}",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeItem(item.id, item.mediaType),
                          ),
                          onTap: () => _openDetailPage(item),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// Pagina di dettaglio per film/serie TV
class DetailPage extends StatefulWidget {
  final CatalogItem item;
  
  const DetailPage({super.key, required this.item});
  
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with SingleTickerProviderStateMixin {
  static const String apiKey = "80157e25b43ede5bf3e4114fa3845d18";
  bool isSaved = false;
  bool isCheckingSaved = true;
  List<Season> seasons = [];
  bool isLoadingSeasons = false;
  TabController? _tabController;
  int? movieRuntime; // Per memorizzare la durata del film
  double? savedPosition; // Per mostrare la posizione salvata
  
  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    _loadSavedPosition();
    
    // Se è un film, carica i dettagli aggiuntivi come la durata
    if (widget.item.mediaType == 'movie') {
      _loadMovieDetails();
    }
    
    // Se è una serie TV, carica le stagioni
    if (widget.item.mediaType == 'tv') {
      _loadSeasons();
      _tabController = TabController(length: 2, vsync: this);
    }
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
  
  // Carica la posizione salvata
  Future<void> _loadSavedPosition() async {
    final position = await PlaybackPositionManager.getPosition(
      widget.item.mediaType, 
      widget.item.id, 
      null, 
      null
    );
    
    if (mounted && position != null) {
      setState(() {
        savedPosition = position;
      });
    }
  }
  
  // Carica i dettagli aggiuntivi del film come la durata
  Future<void> _loadMovieDetails() async {
    try {
      final url = 'https://api.themoviedb.org/3/movie/${widget.item.id}?api_key=$apiKey&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['runtime'] != null) {
          setState(() {
            movieRuntime = data['runtime'];
          });
        }
      }
    } catch (e) {
      print('Errore nel caricamento dei dettagli del film: $e');
    }
  }
  
  // Controlla se l'elemento è già stato salvato
  Future<void> _checkIfSaved() async {
    final saved = await SavedContentManager.isItemSaved(widget.item.id, widget.item.mediaType);
    if (mounted) {
      setState(() {
        isSaved = saved;
        isCheckingSaved = false;
      });
    }
  }
  
  // Salva o rimuovi l'elemento dai preferiti
  Future<void> _toggleSave() async {
    if (isSaved) {
      // Rimuovi dai preferiti
      final success = await SavedContentManager.removeItem(widget.item.id, widget.item.mediaType);
      if (success && mounted) {
        setState(() {
          isSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rimosso dai preferiti')),
        );
      }
    } else {
      // Aggiungi ai preferiti
      final itemToSave = CatalogItem(
        id: widget.item.id,
        title: widget.item.title,
        posterPath: widget.item.posterPath,
        mediaType: widget.item.mediaType,
        releaseDate: widget.item.releaseDate,
        overview: widget.item.overview,
        runtime: movieRuntime ?? widget.item.runtime,
      );
      
      final success = await SavedContentManager.saveItem(itemToSave);
      if (success && mounted) {
        setState(() {
          isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aggiunto ai preferiti')),
        );
      }
    }
  }
  
  // Carica le stagioni per la serie TV
  Future<void> _loadSeasons() async {
    if (widget.item.mediaType != 'tv') return;
    
    setState(() {
      isLoadingSeasons = true;
    });
    
    try {
      final url = 'https://api.themoviedb.org/3/tv/${widget.item.id}?api_key=$apiKey&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['seasons'] != null) {
          final List<Season> loadedSeasons = [];
          for (var seasonData in data['seasons']) {
            loadedSeasons.add(Season.fromJson(seasonData));
          }
          
          if (mounted) {
            setState(() {
              seasons = loadedSeasons;
              isLoadingSeasons = false;
            });
          }
        }
      } else {
        setState(() {
          isLoadingSeasons = false;
        });
      }
    } catch (e) {
      print('Errore nel caricamento delle stagioni: $e');
      setState(() {
        isLoadingSeasons = false;
      });
    }
  }
  
  // Apri il contenuto in WebView integrata
void openInWebView(BuildContext context, {int? seasonNumber, int? episodeNumber}) async {
  String url;
  String mediaType = widget.item.mediaType;
  int id = widget.item.id;
  
  // Verifica se il contenuto è disponibile
  bool isAvailable = await AvailabilityService.isContentAvailable(mediaType, id);
  if (!isAvailable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Questo contenuto non è disponibile per lo streaming")),
      );
    }
    return;
  }
  
  if (mediaType == 'movie') {
    url = 'https://vixsrc.to/movie/$id';
  } else if (mediaType == 'tv') {
    // Per le serie TV, se non sono specificate stagione ed episodio,
    // imposta automaticamente alla prima stagione, primo episodio
    if (seasonNumber != null && episodeNumber != null) {
      url = 'https://vixsrc.to/tv/$id/$seasonNumber/$episodeNumber';
    } else {
      // Usa sempre stagione 1, episodio 1 per le serie TV
      url = 'https://vixsrc.to/tv/$id/1/1';
    }
  } else {
    url = 'https://vixsrc.to/$mediaType/$id';
  }

  // Apri nella WebView integrata
  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamingWebView(
          url: url,
          title: widget.item.title,
          mediaType: mediaType,
          id: id,
          posterPath: widget.item.posterPath,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        ),
      ),
    );
  }
}
  
  // Apri nel browser esterno
  Future<void> openInBrowser(BuildContext context, {int? seasonNumber, int? episodeNumber}) async {
    String url;
    String mediaType = widget.item.mediaType;
    int id = widget.item.id;
    
    // Verifica se il contenuto è disponibile
    bool isAvailable = await AvailabilityService.isContentAvailable(mediaType, id);
    
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Questo contenuto non è disponibile per lo streaming")),
        );
      }
      return;
    }
    
    if (mediaType == 'movie') {
      url = 'https://vixsrc.to/movie/$id';
    } else if (mediaType == 'tv') {
      // Per le serie TV, se non sono specificate stagione ed episodio,
      // imposta automaticamente alla prima stagione, primo episodio
      if (seasonNumber != null && episodeNumber != null) {
        url = 'https://vixsrc.to/tv/$id/$seasonNumber/$episodeNumber';
      } else {
        // Usa sempre stagione 1, episodio 1 per le serie TV
        url = 'https://vixsrc.to/tv/$id/1/1';
      }
    } else {
      url = 'https://vixsrc.to/$mediaType/$id';
    }

    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Non posso aprire il link: $url")),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Pulsante per salvare/rimuovere dai preferiti
          isCheckingSaved
              ? const SizedBox(
                  width: 48,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Color(0xFF5E72E4),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? const Color(0xFF5E72E4) : Colors.white,
                  ),
                  tooltip: isSaved ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
                  onPressed: _toggleSave,
                ),
        ],
        bottom: widget.item.mediaType == 'tv'
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Informazioni'),
                  Tab(text: 'Stagioni'),
                ],
                indicatorColor: const Color(0xFF5E72E4),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
              )
            : null,
      ),
      body: widget.item.mediaType == 'tv'
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildSeasonsTab(),
              ],
            )
          : _buildInfoTab(),
    );
  }
  
  // Tab con le informazioni generali
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero header with gradient overlay
          SizedBox(
            height: 400,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (widget.item.posterPath != null)
                  ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w500${widget.item.posterPath}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF1F2133),
                      ),
                    ),
                  ),
                
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF141420).withOpacity(0.8),
                        const Color(0xFF141420),
                      ],
                      stops: const [0.4, 0.75, 1.0],
                    ),
                  ),
                ),
                
                // Content positioned at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster and basic info in a row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Poster with rounded corners and elevation
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Hero(
                                tag: 'poster_${widget.item.id}_${widget.item.mediaType}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: widget.item.posterPath != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w185${widget.item.posterPath}',
                                        width: 110,
                                        height: 165,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 110,
                                          height: 165,
                                          color: const Color(0xFF262942),
                                          child: const Icon(Icons.image_not_supported, size: 40),
                                        ),
                                      )
                                    : Container(
                                        width: 110,
                                        height: 165,
                                        color: const Color(0xFF262942),
                                        child: const Icon(Icons.movie, size: 40),
                                      ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            // Info column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Hero(
                                    tag: 'title_${widget.item.id}_${widget.item.mediaType}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        widget.item.title,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Year
                                  if (widget.item.releaseDate != null && widget.item.releaseDate!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF262942),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        widget.item.releaseDate!.length >= 4 
                                            ? widget.item.releaseDate!.substring(0, 4) 
                                            : widget.item.releaseDate!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  
                                  // Rating with stars
                                  if (widget.item.voteAverage != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${widget.item.voteAverage!.toStringAsFixed(1)}/10",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  
                                  // Runtime if available
                                  if (widget.item.mediaType == 'movie' && (movieRuntime != null || widget.item.runtime != null))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, color: Colors.white70, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatRuntime(movieRuntime ?? widget.item.runtime!),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Genres as pills in a wrapped row
                        if (widget.item.genres.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.item.genres.map((genre) => 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262942),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF5E72E4).withOpacity(0.3)),
                                ),
                                child: Text(
                                  genre,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              )
                            ).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Continue watching widget if available
          _buildContinueWatchingWidget(),
          
          // Overview section with modern card design
          if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2133),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.description, size: 20, color: Color(0xFF5E72E4)),
                      SizedBox(width: 8),
                      Text(
                        'Trama',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.overview ?? 'Nessuna descrizione disponibile',
                    style: const TextStyle(
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
          // Pulsanti di azione
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pulsante guarda in WebView
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Guarda in WebView', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E72E4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => openInWebView(context),
                ),
                const SizedBox(height: 12),
                // Pulsante apri nel browser
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri nel browser', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF262942),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => openInBrowser(context),
                ),
                const SizedBox(height: 12),
                // Pulsante condividi
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2133),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF5E72E4), width: 1),
                    ),
                  ),
                  onPressed: () {
                    String text = "Guarda ${widget.item.title} su Vixsrc!\n";
                    if (widget.item.mediaType == 'movie') {
                      text += "https://vixsrc.to/movie/${widget.item.id}";
                    } else {
                      text += "https://vixsrc.to/tv/${widget.item.id}/1/1";
                    }
                    Share.share(text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget per mostrare la posizione di riproduzione salvata
  Widget _buildContinueWatchingWidget() {
    if (savedPosition == null || savedPosition! <= 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5E72E4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5E72E4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (widget.item.mediaType == 'movie') {
              openInWebView(context);
            } else {
              // Per le serie TV, dobbiamo ottenere l'ultimo episodio guardato
              PlaybackPositionManager.getLastWatchedEpisode(widget.item.mediaType, widget.item.id).then((lastEpisode) {
                if (lastEpisode != null) {
                  openInWebView(
                    context,
                    seasonNumber: lastEpisode['seasonNumber'],
                    episodeNumber: lastEpisode['episodeNumber'],
                  );
                } else {
                  openInWebView(context);
                }
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E72E4),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continua a guardare',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E72E4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Posizione salvata: ${PlaybackPositionManager.formatTime(savedPosition!)}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF5E72E4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Tab con le stagioni (per serie TV)
  Widget _buildSeasonsTab() {
    if (isLoadingSeasons) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5E72E4)),
      );
    }
    
    if (seasons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nessuna stagione trovata',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadSeasons,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E72E4),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Ricarica'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2133),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showEpisodesDialog(season),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Poster della stagione
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: season.posterPath != null
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w92${season.posterPath}',
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 90,
                              color: const Color(0xFF262942),
                              child: const Icon(Icons.photo, size: 30, color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 90,
                            color: const Color(0xFF262942),
                            child: const Icon(Icons.photo, size: 30, color: Colors.grey),
                          ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            season.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${season.episodeCount} episodi',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          if (season.airDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Anno: ${season.airDate!.length >= 4 ? season.airDate!.substring(0, 4) : season.airDate!}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Mostra un dialogo con gli episodi di una stagione
  void _showEpisodesDialog(Season season) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2133),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 16),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      // Titolo
                      Text(
                        season.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lista di episodi
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: season.episodeCount,
                          itemBuilder: (context, index) {
                            final episodeNumber = index + 1;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF262942),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                   onTap: () {
                                      Navigator.pop(context);
                                      openInWebView(
                                        context,
                                        seasonNumber: season.seasonNumber,
                                        episodeNumber: episodeNumber,
                                      );
                                    },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Text(
                                          '$episodeNumber',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF5E72E4),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            'Episodio $episodeNumber',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                        const Icon(Icons.play_arrow, color: Color(0xFF5E72E4)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  // Formatta la durata in ore e minuti
  String _formatRuntime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '$hours h ${mins > 0 ? '$mins min' : ''}';
    } else {
      return '$mins min';
    }
  }
}

// Pagina dell'account utente
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool isLoggedIn = false;
  String? userName;
  String? userEmail;
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  void _checkLoginStatus() {
    setState(() {
      isLoggedIn = AuthService.isLoggedIn;
      userName = AuthService.userName;
      userEmail = AuthService.userEmail;
    });
  }
  
Future<void> _logout() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Conferma'),
      content: const Text('Sei sicuro di voler effettuare il logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await AuthService.logout();
            
            // Usa questa tecnica più diretta per riavviare l'app
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MyApp()),
                (route) => false,
              );
            }
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}
  
  void _showLoginRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(showBackButton: true),
      ),
    ).then((_) => _checkLoginStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141420),
        elevation: 0,
        title: const Text('Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2133),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: isLoggedIn
                  ? Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0xFF5E72E4),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userName ?? 'Utente',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userEmail ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5E72E4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Logout', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Non hai effettuato l\'accesso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accedi o registrati per sincronizzare i tuoi contenuti preferiti.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showLoginRegisterScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5E72E4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Accedi / Registrati', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Schermata di login/registrazione
class AuthScreen extends StatefulWidget {
  final bool showBackButton;
  
  const AuthScreen({super.key, this.showBackButton = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoginMode = true;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showPassword = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _toggleMode() {
    setState(() {
      isLoginMode = !isLoginMode;
      _errorMessage = '';
    });
  }
  
  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Compila tutti i campi';
      });
      return;
    }
    
    if (!isLoginMode && _nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Inserisci il tuo nome';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      Map<String, dynamic> result;
      
      if (isLoginMode) {
        // Login
        result = await AuthService.login(email, password);
      } else {
        // Registrazione
        final name = _nameController.text.trim();
        result = await AuthService.register(name, email, password);
      }
      
      if (result['success']) {
        if (mounted) {
          // Invece di fare pop, facciamo un restart completo dell'app
          // Questo è un modo sicuro per evitare problemi di navigazione
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MyApp(),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Si è verificato un errore';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Si è verificato un errore: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141420),
        elevation: 0,
        title: Text(isLoginMode ? 'Accedi' : 'Registrati'),
        automaticallyImplyLeading: widget.showBackButton, // Usa il parametro qui
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              isLoginMode ? 'Bentornato!' : 'Crea un account',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoginMode 
                ? 'Accedi per continuare a guardare i tuoi contenuti preferiti'
                : 'Registrati per sincronizzare i tuoi contenuti su tutti i dispositivi',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            
            // Form
            if (!isLoginMode)
              _buildTextField(
                controller: _nameController,
                label: 'Nome',
                icon: Icons.person,
              ),
              
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: !_showPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
            ),
            
            // Error message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Submit button
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E72E4),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isLoginMode ? 'Accedi' : 'Registrati',
                        style: const TextStyle(fontSize: 16),
                      ),
                ),
              ),
            ),
            
            // Toggle mode button
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _toggleMode,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      children: [
                        TextSpan(
                          text: isLoginMode
                            ? 'Non hai un account? '
                            : 'Hai già un account? ',
                        ),
                        TextSpan(
                          text: isLoginMode ? 'Registrati' : 'Accedi',
                          style: const TextStyle(
                            color: Color(0xFF5E72E4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2133),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

// Pagina principale con barra di navigazione
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const StreamingHomePage(),
    const CatalogPage(),
    const SavedContentPage(),
    const AccountPage(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  @override
  void initState() {
    super.initState();
    // Inizializza i servizi all'avvio dell'app
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AuthService.initialize();
      await PlaybackPositionManager.initialize();
      await AvailabilityService.initialize();
      
      // Sincronizza i contenuti guardati se l'utente è loggato
      if (AuthService.isLoggedIn) {
        await WatchedContentService.syncWatchedContentWithPlaybackManager();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2133),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.search, 'Cerca'),
                _buildNavItem(1, Icons.movie, 'Catalogo'),
                _buildNavItem(2, Icons.bookmark, 'Salvati'),
                _buildNavItem(3, Icons.person, 'Account'),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5E72E4).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF5E72E4) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF5E72E4) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper di autenticazione per controllare lo stato di login
class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await AuthService.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF141420),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF5E72E4),
            secondary: Color(0xFF5E72E4),
          ),
        ),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF5E72E4)),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'RedaMovie',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141420),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141420),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5E72E4),
          secondary: Color(0xFF5E72E4),
        ),
      ),
      home: AuthService.isLoggedIn ? widget.child : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Nuova schermata di login dedicata
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        VersionChecker.checkAppVersion(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthScreen();
  }
}

// Widget ausiliario che si occupa del controllo dell'autenticazione
class _AuthenticationGate extends StatefulWidget {
  final Widget child;
  final Function(BuildContext) onAfterBuild;
  
  const _AuthenticationGate({
    Key? key, 
    required this.child,
    required this.onAfterBuild,
  }) : super(key: key);

  @override
  State<_AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<_AuthenticationGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAfterBuild(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthService.isLoggedIn 
        ? widget.child 
        : const AuthScreen();
  }
}


// Entry point dell'applicazione
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(
      child: MaterialApp(
        title: 'RedaMovie',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF141420),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF141420),
            elevation: 0,
          ),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF5E72E4),
            secondary: Color(0xFF5E72E4),
          ),
        ),
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
