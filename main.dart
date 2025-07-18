import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async'; // Aggiunto per il Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

// Classe per la visualizzazione dei contenuti in WebView
class StreamingWebView extends StatefulWidget {
  final String url;
  final String title;
  final String mediaType;
  final int id;
  final int? seasonNumber;
  final int? episodeNumber;
  
  const StreamingWebView({
    Key? key, 
    required this.url, 
    required this.title,
    required this.mediaType,
    required this.id,
    this.seasonNumber,
    this.episodeNumber,
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
  bool _isFullScreen = false; // Traccia lo stato della modalità a schermo intero
  
  @override
  void initState() {
    super.initState();
    _loadSavedPosition();
    
    // Configura il timer per salvare automaticamente ogni 30 secondi
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (playbackPosition != null && playbackPosition! > 0) {
        _savePlaybackPosition(showNotification: false);
      }
    });
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            if (!hasInjectedJs) {
              _injectPlaybackTracker();
              _injectAdBlocker(); // Aggiungiamo il blocco pubblicità
              _injectFullscreenDetector(); // Aggiungiamo il rilevatore fullscreen
              hasInjectedJs = true;
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              hasError = true;
              errorMessage = "Errore ${error.errorCode}: ${error.description}";
              isLoading = false;
            });
            print("WebView error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            // Blocca reindirizzamenti a domini pubblicitari noti
            if (_isAdUrl(request.url)) {
              print("Bloccato URL pubblicitario: ${request.url}");
              return NavigationDecision.prevent;
            }
            
            // Consenti solo i link che iniziano con l'URL di base
            if (request.url.startsWith('https://vixsrc.to/')) {
              return NavigationDecision.navigate;
            }
            
            // Blocca tutti gli altri reindirizzamenti senza mostrare dialogo
            print("Bloccato reindirizzamento a: ${request.url}");
            
            // Mostra un messaggio breve che scompare automaticamente
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Reindirizzamento bloccato"),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            
            return NavigationDecision.prevent;
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36')
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
      // Nuovo canale JavaScript per rilevare i cambiamenti del fullscreen
      ..addJavaScriptChannel(
        'FullscreenChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'enter') {
            _enterFullScreen();
          } else if (message.message == 'exit') {
            _exitFullScreen();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }
  
  @override
  void dispose() {
    // Assicurati di uscire dalla modalità fullscreen quando si chiude la pagina
    if (_isFullScreen) {
      _exitFullScreen();
    }
    
    // Cancella il timer quando la pagina viene chiusa
    _autoSaveTimer?.cancel();
    // Salva la posizione finale quando l'utente esce
    _savePlaybackPosition(showNotification: false);
    super.dispose();
  }
  
  // Metodo per entrare in modalità fullscreen
  void _enterFullScreen() {
    if (!_isFullScreen) {
      setState(() {
        _isFullScreen = true;
      });
      // Nascondi tutti gli elementi dell'interfaccia di sistema
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }
  
  // Metodo per uscire dalla modalità fullscreen
  void _exitFullScreen() {
    if (_isFullScreen) {
      setState(() {
        _isFullScreen = false;
      });
      // Ripristina l'interfaccia di sistema normale
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
  
  // Aggiungi questo metodo per rilevare quando il contenuto web entra/esce dal fullscreen
  void _injectFullscreenDetector() {
    _controller.runJavaScript('''
      (function() {
        // Lista di possibili eventi di cambio fullscreen in diversi browser
        const fullscreenEvents = [
          'fullscreenchange',
          'webkitfullscreenchange',
          'mozfullscreenchange',
          'MSFullscreenChange'
        ];
        
        // Funzione per controllare se siamo in fullscreen
        function checkFullscreen() {
          const isFullscreen = !!(
            document.fullscreenElement ||
            document.webkitFullscreenElement ||
            document.mozFullScreenElement ||
            document.msFullscreenElement
          );
          
          // Comunica lo stato fullscreen all'app Flutter
          if (isFullscreen) {
            FullscreenChannel.postMessage('enter');
          } else {
            FullscreenChannel.postMessage('exit');
          }
        }
        
        // Aggiungi event listener per tutti i possibili eventi di fullscreen
        fullscreenEvents.forEach(eventName => {
          document.addEventListener(eventName, checkFullscreen);
        });
        
        // Monitora anche i video che potrebbero entrare in modalità fullscreen
        function monitorVideoFullscreen() {
          const videos = document.querySelectorAll('video');
          videos.forEach(video => {
            // Aggiungi eventi di controllo alle proprietà fullscreen
            if (!video._hasFullscreenListeners) {
              video._hasFullscreenListeners = true;
              
              // Eventi specifici per iOS
              video.addEventListener('webkitbeginfullscreen', function() {
                console.log('Video entered fullscreen');
                FullscreenChannel.postMessage('enter');
              });
              
              video.addEventListener('webkitendfullscreen', function() {
                console.log('Video exited fullscreen');
                FullscreenChannel.postMessage('exit');
              });
              
              // Eventi Picture-in-Picture
              video.addEventListener('enterpictureinpicture', function() {
                console.log('Entered PiP mode');
                FullscreenChannel.postMessage('enter');
              });
              
              video.addEventListener('leavepictureinpicture', function() {
                console.log('Left PiP mode');
                FullscreenChannel.postMessage('exit');
              });
            }
          });
        }
        
        // Esegui subito e controlla periodicamente per nuovi video
        monitorVideoFullscreen();
        setInterval(monitorVideoFullscreen, 1000);
        
        // Inoltre, osserva le mutazioni del DOM per rilevare nuovi video
        const observer = new MutationObserver(function(mutations) {
          monitorVideoFullscreen();
        });
        
        // Avvia l'osservazione
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
      })();
    ''');
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
  void _injectAdBlocker() {
    _controller.runJavaScript('''
      (function() {
        // Funzione per rimuovere annunci
        function blockAds() {
          // Selettori comuni per elementi pubblicitari
          const adSelectors = [
            'div[id*="google_ads_"]',
            'div[id*="ad-"]',
            'div[id*="ad_"]',
            'div[class*="ad-"]',
            'div[class*="ad_"]',
            'div[class*="ads-"]',
            'div[class*="ads_"]',
            'iframe[src*="ads"]',
            'iframe[src*="doubleclick"]',
            'iframe[src*="googleads"]',
            'iframe[src*="ad."]',
            'a[href*="adclick"]',
            'a[href*="doubleclick"]',
            'a[href*="googleadservices"]',
            'a[target="_blank"]',
            'ins.adsbygoogle',
            '.adsbygoogle',
            '.ad-container',
            '.ad-wrapper',
            '#ad-wrapper',
            '#ad-container',
            '.popupOverlay',
            '.popup-overlay',
            '.modal-backdrop',
            '.adBox',
            '.ad-box',
            'div[style*="z-index: 9999"]',
            'div[style*="position: fixed"][style*="width: 100%"][style*="height: 100%"]'
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
          
          // Blocca anche gli overlay modali
          const overlays = document.querySelectorAll('div[style*="position: fixed"]');
          overlays.forEach(el => {
            const style = window.getComputedStyle(el);
            if (style.zIndex > 1000 && (style.width === '100%' || style.width === '100vw') && 
                (style.height === '100%' || style.height === '100vh')) {
              el.style.display = 'none';
              el.remove();
            }
          });
        }
        
        // Esegui il blocco iniziale
        blockAds();
        
        // Configura un osservatore per rilevare dinamicamente gli annunci
        const observer = new MutationObserver(function(mutations) {
          blockAds();
        });
        
        // Avvia l'osservazione
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        // Blocca anche i pop-up
        window.open = function() { return null; };
        
        // Disabilita i redirect tramite location
        const originalLocation = window.location;
        let locationProxy = new Proxy(originalLocation, {
          set: function(obj, prop, value) {
            if (prop === 'href' || prop === 'replace') {
              console.log('Tentativo di reindirizzamento bloccato a: ' + value);
              return true; // Blocca il reindirizzamento
            }
            return Reflect.set(obj, prop, value);
          }
        });
        
        // Sostituisci l'oggetto location con il proxy
        try {
          Object.defineProperty(window, 'location', {
            configurable: false,
            get: function() { return locationProxy; },
            set: function(val) { console.log('Reindirizzamento bloccato'); }
          });
        } catch(e) {
          console.log('Non è stato possibile sostituire window.location', e);
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
  void _injectPlaybackTracker() {
    _controller.runJavaScript('''
      try {
        // Funzione per trovare il video player
        let videoCheckInterval;
        let retryCount = 0;
        
        function findVideoElement() {
          const videoElements = document.querySelectorAll('video');
          if (videoElements.length > 0) {
            return videoElements[0]; // Prendi il primo elemento video trovato
          }
          return null;
        }
        
        // Controlla se c'è un video prima di impostare la posizione
        function setupVideo() {
          const video = findVideoElement();
          if (video) {
            // Rimuovi l'intervallo di controllo
            if (videoCheckInterval) {
              clearInterval(videoCheckInterval);
            }
            
            // Imposta la posizione se disponibile
            ${playbackPosition != null ? "try { video.currentTime = $playbackPosition; } catch(e) {}" : ""}
            
            // Imposta un listener per gli eventi del video
            try {
              // Traccia la posizione più frequentemente (ogni 5 secondi)
              setInterval(function() {
                if (!video.paused && video.currentTime > 0) {
                  PlaybackChannel.postMessage(video.currentTime.toString());
                }
              }, 5000);
              
              // Salva anche quando l'utente mette in pausa
              video.addEventListener('pause', function() {
                if (video.currentTime > 0) {
                  PlaybackChannel.postMessage(video.currentTime.toString());
                }
              });
              
              // Salva quando il video termina
              video.addEventListener('ended', function() {
                PlaybackChannel.postMessage(video.currentTime.toString());
              });
            } catch(e) {
              console.error('Errore nell\\'impostare gli eventi del video:', e);
            }
          } else {
            retryCount++;
            if (retryCount > 30) { // Limita i tentativi a 30 (15 secondi)
              clearInterval(videoCheckInterval);
            }
          }
        }
        
        // Controlla ogni 500ms se il video è disponibile
        videoCheckInterval = setInterval(setupVideo, 500);
        
        // Prova subito la prima volta
        setupVideo();
      } catch(e) {
        console.error('Errore nel tracciamento della riproduzione:', e);
      }
    ''');
  }
  
  // Salva la posizione di riproduzione quando si esce
  Future<void> _savePlaybackPosition({bool showNotification = true}) async {
    if (playbackPosition != null && playbackPosition! > 0) {
      await PlaybackPositionManager.savePosition(
        widget.mediaType, 
        widget.id, 
        widget.seasonNumber, 
        widget.episodeNumber, 
        playbackPosition!
      );
      
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
        // Se siamo in modalità fullscreen, esci da questa prima
        if (_isFullScreen) {
          _exitFullScreen();
          return false; // Non chiudere la pagina, solo esci dal fullscreen
        }
        
        await _savePlaybackPosition();
        return true;
      },
      child: Scaffold(
        appBar: _isFullScreen ? null : AppBar(
          title: Text(widget.title),
          actions: [
            if (playbackPosition != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    PlaybackPositionManager.formatTime(playbackPosition!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: 'Blocca pubblicità',
              onPressed: () => _injectAdBlocker(),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Salva posizione',
              onPressed: () => _savePlaybackPosition(),
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
                } else if (value == 'fullscreen') {
                  _enterFullScreen();
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
                const PopupMenuItem<String>(
                  value: 'fullscreen',
                  child: ListTile(
                    leading: Icon(Icons.fullscreen),
                    title: Text('Schermo intero'),
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
            if (isLoading && !_isFullScreen)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (hasError && !_isFullScreen)
              Center(
                child: Column(
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
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(120, 45),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Apri nel Browser'),
                          onPressed: () => _openInBrowser(widget.url),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(120, 45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: _isFullScreen 
            ? null 
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text(
                      'Problemi? Apri nel Browser',
                      style: TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      minimumSize: const Size(double.infinity, 48),
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

void main() {
  runApp(const StreamingApp());
}

class StreamingApp extends StatelessWidget {
  const StreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definisci i colori personalizzati per il tema scuro moderno
    const primaryColor = Color(0xFF2979FF); // Blu brillante per accenti
    const primaryColorLight = Color(0xFF5393FF);
    const backgroundColor = Color(0xFF121212); // Sfondo scuro quasi nero
    const surfaceColor = Color(0xFF1E1E1E); // Superfici leggermente più chiare
    const cardColor = Color(0xFF252525); // Card ancora più chiare

    return MaterialApp(
      title: 'StreamingGoonity',
      // Tema scuro personalizzato
      theme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColorLight,
          surface: surfaceColor,
          background: backgroundColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        cardColor: cardColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        // Bottoni arrotondati e moderni
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800], // Bottoni non selezionati
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            minimumSize: const Size(100, 45), // Dimensione minima per tutti i pulsanti
            textStyle: const TextStyle(fontSize: 15), // Dimensione testo coerente
          ),
        ),
        useMaterial3: false,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const StreamingHomePage(),
    const CatalogPage(),
    const SavedContentPage(), // Nuova pagina per i contenuti salvati
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Theme(
        // Utilizza un tema specifico per la BottomNavigationBar
        data: Theme.of(context).copyWith(
          // Mantieni lo sfondo uguale a quello dell'app
          canvasColor: Theme.of(context).scaffoldBackgroundColor,
          // Disabilita effetti di splash e highlight
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          // Rimuovi il colore di selezione della bottomNav
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            // Imposta il colore di sfondo come trasparente
            backgroundColor: Colors.transparent,
            // Rimuovi l'ombra
            elevation: 0,
            // Non cambiare colore quando selezionato
            type: BottomNavigationBarType.fixed,
          ),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Cerca',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Catalogo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark),
              label: 'Salvati',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          // Disabilita l'animazione di cambio colore
          enableFeedback: false,
        ),
      ),
    );
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
      appBar: AppBar(
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
          ? const Center(child: CircularProgressIndicator())
          : savedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Nessun contenuto salvato',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'I tuoi film e serie preferiti appariranno qui',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'Cerca contenuti',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          minimumSize: const Size(200, 48),
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
                  padding: const EdgeInsets.all(8),
                  itemCount: savedItems.length,
                  itemBuilder: (context, index) {
                    final item = savedItems[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Dismissible(
                        key: Key('saved_${item.id}_${item.mediaType}'),
                        background: Container(
                          color: Colors.red,
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
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.movie, size: 50),
                                    )
                                  : const Icon(Icons.movie, size: 50),
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
                              Text(item.mediaType == 'movie' ? 'Film' : 'Serie TV'),
                              if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                                Text(
                                  "Anno: ${item.releaseDate!.length >= 4 
                                      ? item.releaseDate!.substring(0, 4) 
                                      : item.releaseDate!}"
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
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
    if (json['genre_ids'] != null && json['genre_ids'] is List) {
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
      appBar: AppBar(
        title: Text(widget.item.title),
        elevation: 0,
        actions: [
          // Pulsante per salvare/rimuovere dai preferiti
          isCheckingSaved
              ? const SizedBox(
                  width: 48,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
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
          // Poster e info di base
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background sfocato
                if (widget.item.posterPath != null)
                  ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
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
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                
                // Contenuto principale
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Poster
                      Hero(
                        tag: 'poster_${widget.item.id}_${widget.item.mediaType}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.item.posterPath != null
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w185${widget.item.posterPath}',
                                width: 120,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 120,
                                  height: 180,
                                  color: Theme.of(context).cardColor,
                                  child: const Icon(Icons.image_not_supported, size: 40),
                                ),
                              )
                            : Container(
                                width: 120,
                                height: 180,
                                color: Theme.of(context).cardColor,
                                child: const Icon(Icons.movie, size: 40),
                              ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Info di base
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'title_${widget.item.id}_${widget.item.mediaType}',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  widget.item.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1.0, 1.0),
                                        blurRadius: 3.0,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (widget.item.releaseDate != null && widget.item.releaseDate!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Anno: ${widget.item.releaseDate!.length >= 4 
                                      ? widget.item.releaseDate!.substring(0, 4) 
                                      : widget.item.releaseDate!}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1.0, 1.0),
                                        blurRadius: 3.0,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Durata del film se disponibile
                            if (widget.item.mediaType == 'movie' && (movieRuntime != null || widget.item.runtime != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatRuntime(movieRuntime ?? widget.item.runtime!),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 3.0,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.item.voteAverage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${widget.item.voteAverage!.toStringAsFixed(1)}/10",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 3.0,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.item.genres.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Wrap(
                                  spacing: 8.0,
                                  children: widget.item.genres.map((genre) => 
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        genre,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  ).toList(),
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
          ),
          
          // Utilizza i nuovi metodi per continua a guardare
          _buildContinueWatchingWidget(),
          
          // Trama
          if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trama',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.overview!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          
          // Info aggiuntive
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tipo'),
                  subtitle: Text(widget.item.mediaType == 'movie' ? 'Film' : 'Serie TV'),
                ),
                // Durata del film
                if (widget.item.mediaType == 'movie' && (movieRuntime != null || widget.item.runtime != null))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Durata'),
                    subtitle: Text(_formatRuntime(movieRuntime ?? widget.item.runtime!)),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ID TMDB'),
                  subtitle: Text(widget.item.id.toString()),
                ),
                if (widget.item.releaseDate != null && widget.item.releaseDate!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data di uscita'),
                    subtitle: Text(widget.item.releaseDate!),
                  ),
              ],
            ),
          ),
          
          // Pulsanti per vedere lo streaming
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Pulsante principale per WebView
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      "Guarda in WebView",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => openInWebView(context),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Pulsante per browser esterno
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text(
                      "Apri nel Browser",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => openInBrowser(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget per continuare a guardare
  Widget _buildContinueWatchingWidget() {
    if (widget.item.mediaType == 'tv') {
      return FutureBuilder<Map<String, dynamic>?>(
        future: PlaybackPositionManager.getLastWatchedEpisode(widget.item.mediaType, widget.item.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            final lastEpisode = snapshot.data!;
            final seasonNumber = lastEpisode['seasonNumber'];
            final episodeNumber = lastEpisode['episodeNumber'];
            final position = lastEpisode['position'] as double;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline, color: Colors.white70),
                        const SizedBox(width: 8),
                        const Text(
                          'Continua a guardare',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stagione $seasonNumber, Episodio $episodeNumber (${PlaybackPositionManager.formatTime(position)})',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text(
                            'Riprendi',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(120, 40),
                          ),
                          onPressed: () => openInWebView(
                            context, 
                            seasonNumber: seasonNumber, 
                            episodeNumber: episodeNumber
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Se non ci sono dati sull'ultimo episodio, mostra comunque la posizione globale
          if (savedPosition != null && savedPosition! > 0) {
            return _buildMovieContinueWatchingWidget();
          }
          
          return const SizedBox.shrink();
        },
      );
    } else if (savedPosition != null && savedPosition! > 0) {
      // Per i film, mostra il widget standard per continuare a guardare
      return _buildMovieContinueWatchingWidget();
    }
    
    return const SizedBox.shrink();
  }

  // Widget per continuare a guardare un film
  Widget _buildMovieContinueWatchingWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline, color: Colors.white70),
                const SizedBox(width: 8),
                const Text(
                  'Continua a guardare',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Riprendi da ${PlaybackPositionManager.formatTime(savedPosition!)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Riprendi',
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    minimumSize: const Size(120, 40),
                  ),
                  onPressed: () => openInWebView(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Formatta la durata in ore e minuti
  String _formatRuntime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours h ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }
  
  // Tab con le stagioni e gli episodi
  Widget _buildSeasonsTab() {
    if (isLoadingSeasons) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (seasons.isEmpty) {
      return const Center(
        child: Text('Nessuna stagione disponibile'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              season.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${season.episodeCount} episodi'),
            leading: season.posterPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w92${season.posterPath}',
                      width: 40,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.tv, size: 40),
                    ),
                  )
                : const Icon(Icons.tv, size: 40),
            children: [
              if (season.overview != null && season.overview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(season.overview!),
                ),
              _buildEpisodesList(season.seasonNumber),
            ],
          ),
        );
      },
    );
  }
  
  // Costruisce la lista degli episodi per una stagione
  Widget _buildEpisodesList(int seasonNumber) {
    return FutureBuilder<List<Episode>>(
      future: _fetchEpisodes(seasonNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Errore nel caricamento degli episodi: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Nessun episodio disponibile'),
          );
        }
        
        final episodes = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return ListTile(
              title: Text(
                '${episode.episodeNumber}. ${episode.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              // Mostra la durata invece della data
              subtitle: episode.runtime != null
                  ? Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(_formatRuntime(episode.runtime!)),
                      ],
                    )
                  : null,
              leading: const Icon(Icons.play_circle_outline),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Guarda in WebView',
                    onPressed: () => openInWebView(
                      context,
                      seasonNumber: seasonNumber,
                      episodeNumber: episode.episodeNumber,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    tooltip: 'Apri nel Browser',
                    onPressed: () => openInBrowser(
                      context,
                      seasonNumber: seasonNumber,
                      episodeNumber: episode.episodeNumber,
                    ),
                  ),
                ],
              ),
              onTap: () => openInWebView(
                context,
                seasonNumber: seasonNumber,
                episodeNumber: episode.episodeNumber,
              ),
            );
          },
        );
      },
    );
  }
  
  // Carica gli episodi di una stagione
  Future<List<Episode>> _fetchEpisodes(int seasonNumber) async {
    try {
      final url = 'https://api.themoviedb.org/3/tv/${widget.item.id}/season/$seasonNumber?api_key=$apiKey&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['episodes'] != null) {
          final List<Episode> episodes = [];
          for (var episodeData in data['episodes']) {
            episodes.add(Episode.fromJson(episodeData));
          }
          return episodes;
        }
      }
      return [];
    } catch (e) {
      print('Errore nel caricamento degli episodi: $e');
      return [];
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
          seasonNumber: choice == 'serie' ? int.tryParse(seasonController.text) : null,
          episodeNumber: choice == 'serie' ? int.tryParse(episodeController.text) : null,
        ),
      ),
    );
  }

  void copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    
    // Mostra feedback anche sopra il container del link
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
      appBar: AppBar(
        title: const Text('Cerca contenuti'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: choice == 'film' 
                            ? Theme.of(context).primaryColor 
                            : null,
                      ),
                      onPressed: () {
                        setState(() {
                          choice = 'film';
                          seasonController.clear();
                          episodeController.clear();
                        });
                        // Reset dei risultati quando cambio tipo
                        _resetResults();
                      },
                      child: const Text("Film"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: choice == 'serie' 
                            ? Theme.of(context).primaryColor 
                            : null,
                      ),
                      onPressed: () {
                        setState(() {
                          choice = 'serie';
                          seasonController.clear();
                          episodeController.clear();
                        });
                        // Reset dei risultati quando cambio tipo
                        _resetResults();
                      },
                      child: const Text("Serie"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Titolo",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
              if (choice == "serie") ...[
                const SizedBox(height: 16),
                TextField(
                  controller: seasonController,
                  decoration: InputDecoration(
                    labelText: "Stagione",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: episodeController,
                  decoration: InputDecoration(
                    labelText: "Episodio",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isLoading ? null : search,
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Cerca"),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (linkToOpen != null) ...[
                const SizedBox(height: 16),
                // Link display
                Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            linkToOpen!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        Theme(
                          // Disabilita l'effetto splash
                          data: ThemeData(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.copy, color:Colors.white),
                            tooltip: "Copia link",
                            onPressed: () => copyLink(linkToOpen!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Pulsante per aprire in WebView (principale)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      "Guarda in WebView",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => openInWebView(linkToOpen!),
                  ),
                ),
                const SizedBox(height: 8),
                // Pulsante per aprire nel browser
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text(
                      "Apri nel Browser",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => openInBrowser(linkToOpen!),
                  ),
                ),
                // Pulsante per visualizzare i dettagli
                if (foundItem != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.info),
                    label: const Text(
                      "Visualizza Dettagli",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (context, animation, secondaryAnimation) => 
                            DetailPage(item: foundItem!),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            // Animazione dal basso verso l'alto
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
            ],
          ),
        ),
      ),
    );
  }
}

// Pagina del catalogo
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final CatalogService _catalogService = CatalogService();
  
  // Cache degli episodi spostata a livello di classe
  static final Map<int, int> _episodeCache = {};
  
  String selectedType = 'movie';
  String? searchQuery; // Per memorizzare la ricerca dalla home
  
  final ScrollController _scrollController = ScrollController();
  final double _scrollThreshold = 200.0; // Soglia di scorrimento per caricare più titoli
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Carica i generi all'inizio
    _catalogService.loadGenres();
    
    // Verifica se c'è una ricerca pendente
    if (SearchService.pendingSearchQuery != null) {
      searchQuery = SearchService.pendingSearchQuery;
      selectedType = SearchService.pendingSearchType ?? 'movie';
      
      // Programma la ricerca dopo il primo render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _catalogService.searchInCatalog(searchQuery!, selectedType, setState);
        // Pulisci la ricerca pendente
        SearchService.clearSearch();
      });
    } else {
      _loadCatalogIfNeeded();
    }
  }
  
  void _loadCatalogIfNeeded() {
    // Carica il catalogo solo se non è già stato inizializzato
    if (!_catalogService.hasInitialized(selectedType)) {
      _catalogService.fetchCatalogIds(selectedType, setState);
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels > 
        _scrollController.position.maxScrollExtent - _scrollThreshold) {
      _catalogService.loadMoreTitles(selectedType, setState);
    }
  }
  
  // Imposta la query di ricerca e aggiorna la vista
  void setSearchQuery(String query, String type) {
    setState(() {
      searchQuery = query;
      selectedType = type;
    });
    // Effettua la ricerca
    _catalogService.searchInCatalog(query, selectedType, setState);
  }
  
  // Funzione per vedere la risposta grezza dell'API
  void _viewRawApiResponse() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Risposta API'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _catalogService.getRawResponse(selectedType).isEmpty 
                    ? 'Nessuna risposta disponibile' 
                    : _catalogService.getRawResponse(selectedType),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          if (_catalogService.getRawResponse(selectedType).isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _catalogService.getRawResponse(selectedType)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Risposta API copiata negli appunti')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Copia'),
            ),
        ],
      ),
    );
  }

  // Apre la pagina di dettaglio
  void openDetailPage(BuildContext context, CatalogItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => DetailPage(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Animazione dal basso invece che da destra
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
  }

  // Apri direttamente in WebView
  void openInWebView(BuildContext context, CatalogItem item) {
    String url;
    if (item.mediaType == 'movie') {
      url = 'https://vixsrc.to/movie/${item.id}';
    } else {
      // Per le serie TV, usa sempre stagione 1, episodio 1
      url = 'https://vixsrc.to/tv/${item.id}/1/1';
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamingWebView(
          url: url,
          title: item.title,
          mediaType: item.mediaType,
          id: item.id,
          seasonNumber: item.mediaType == 'tv' ? 1 : null,
          episodeNumber: item.mediaType == 'tv' ? 1 : null,
        ),
      ),
    );
  }

  // Metodo per ottenere il numero totale di episodi di una serie
  Future<int> _getEpisodeCount(int tvId) async {
    // Usa un sistema di cache per evitare richieste ripetute
    if (_episodeCache.containsKey(tvId)) {
      return _episodeCache[tvId]!;
    }

    try {
      final url = 'https://api.themoviedb.org/3/tv/$tvId?api_key=${CatalogService.apiKey}&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int totalEpisodes = 0;
        
        if (data['seasons'] != null) {
          for (var season in data['seasons']) {
            totalEpisodes += season['episode_count'] as int? ?? 0;
          }
        }
        
        // Memorizza nella cache
        _episodeCache[tvId] = totalEpisodes;
        return totalEpisodes;
      }
    } catch (e) {
      print('Errore nel recupero degli episodi: $e');
    }
    
    return 0;
  }

  // Metodo per formattare la durata in ore e minuti
  String _formatRuntime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours h ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _catalogService.getItems(selectedType);
    final isLoading = _catalogService.isLoading(selectedType);
    final error = _catalogService.getError(selectedType);
    final loadedItemsCount = _catalogService.getLoadedItemsCount(selectedType);
    final allTmdbIds = _catalogService.getTmdbIds(selectedType);
    
    return Scaffold(
      appBar: AppBar(
        title: searchQuery != null 
            ? Text('Risultati per "$searchQuery"') 
            : const Text('Catalogo'),
        actions: [
          // Pulsante per tornare alla visualizzazione principale se siamo in modalità ricerca
          if (searchQuery != null)
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Torna al catalogo',
              onPressed: () {
                setState(() {
                  searchQuery = null;
                  _catalogService.setSearchQuery(selectedType, '');
                });
                _catalogService.fetchCatalogIds(selectedType, setState);
              },
            ),
          // Pulsante per vedere la risposta API grezza
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Vedi risposta API',
            onPressed: _viewRawApiResponse,
          ),
          // Pulsante per ricaricare
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica catalogo',
            onPressed: () {
              // Cancella la query di ricerca quando si ricarica
              setState(() {
                searchQuery = null;
                _catalogService.setSearchQuery(selectedType, '');
              });
              _catalogService.fetchCatalogIds(selectedType, setState);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Pulsanti per selezionare film o serie TV
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedType == 'movie' 
                          ? Theme.of(context).primaryColor 
                          : null,
                    ),
                    onPressed: () {
                      if (selectedType != 'movie') {
                        setState(() {
                          selectedType = 'movie';
                          searchQuery = null; // Resetta la ricerca
                          _catalogService.setSearchQuery('movie', '');
                        });
                        _loadCatalogIfNeeded();
                      }
                    },
                    child: const Text("Film"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedType == 'tv' 
                          ? Theme.of(context).primaryColor 
                          : null,
                    ),
                    onPressed: () {
                      if (selectedType != 'tv') {
                        setState(() {
                          selectedType = 'tv';
                          searchQuery = null; // Resetta la ricerca
                          _catalogService.setSearchQuery('tv', '');
                        });
                        _loadCatalogIfNeeded();
                      }
                    },
                    child: const Text("Serie"),
                  ),
                ),
              ],
            ),
          ),

          // Campo di ricerca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca nel catalogo',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  setSearchQuery(query, selectedType);
                }
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mostra informazioni sul catalogo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  searchQuery != null 
                      ? 'Risultati per "$searchQuery"' 
                      : allTmdbIds.isEmpty 
                          ? '' 
                          : 'Titoli: ${loadedItemsCount}/${allTmdbIds.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                if (_catalogService.isLoadingMore(selectedType))
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          // Corpo principale con gli elementi del catalogo
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Riprova'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                ),
                                onPressed: () {
                                  if (searchQuery != null) {
                                    _catalogService.searchInCatalog(searchQuery!, selectedType, setState);
                                  } else {
                                    _catalogService.fetchCatalogIds(selectedType, setState);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nessun contenuto disponibile',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Prova a cambiare la ricerca o ricarica il catalogo',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Ricarica catalogo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = null;
                                      _catalogService.setSearchQuery(selectedType, '');
                                    });
                                    _catalogService.fetchCatalogIds(selectedType, setState);
                                  },
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            controller: _scrollController,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return GestureDetector(
                                onTap: () => openDetailPage(context, item),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Poster
                                      Hero(
                                        tag: 'poster_${item.id}_${item.mediaType}',
                                        child: item.posterPath != null
                                            ? Image.network(
                                                'https://image.tmdb.org/t/p/w342${item.posterPath}',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Container(
                                                      color: Theme.of(context).cardColor,
                                                      child: const Icon(Icons.image_not_supported, size: 50),
                                                    ),
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    color: Theme.of(context).cardColor,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: Theme.of(context).cardColor,
                                                child: const Icon(Icons.movie, size: 50),
                                              ),
                                      ),
                                      
                                      // Gradiente dal basso verso l'alto per rendere leggibile il titolo
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 120,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [Colors.black87, Colors.transparent],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Info
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Titolo
                                              Hero(
                                                tag: 'title_${item.id}_${item.mediaType}',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Text(
                                                    item.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              
                                              const SizedBox(height: 4),
                                              
                                              // Anno o rating
                                              if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                                                Text(
                                                  item.releaseDate!.length >= 4
                                                      ? item.releaseDate!.substring(0, 4)
                                                      : item.releaseDate!,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              
                                              const SizedBox(height: 8),
// Pulsante per guardare
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openInWebView(context, item),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sostituire il CircularProgressIndicator con un'icona play statica
              Icon(
                Icons.play_arrow,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Play',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
),
                                              
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      // Badge tipo (film/serie)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: item.mediaType == 'movie' 
                                                ? Colors.blue.withOpacity(0.8) 
                                                : Colors.purple.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item.mediaType == 'movie' ? 'Film' : 'TV',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Se la serie TV, badge con numero episodi
                                      if (item.mediaType == 'tv')
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: FutureBuilder<int>(
                                            future: _getEpisodeCount(item.id),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData || snapshot.data == 0) {
                                                return const SizedBox.shrink();
                                              }
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.8),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${snapshot.data} ep',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
