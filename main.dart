import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


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
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                        label: const Text('Cerca contenuti'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
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
  
  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    
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
  
  Future<void> openStreamingLink(BuildContext context, {int? seasonNumber, int? episodeNumber}) async {
    String url;
    if (widget.item.mediaType == 'movie') {
      url = 'https://vixsrc.to/movie/${widget.item.id}';
    } else if (widget.item.mediaType == 'tv') {
      if (seasonNumber != null && episodeNumber != null) {
        url = 'https://vixsrc.to/tv/${widget.item.id}/$seasonNumber/$episodeNumber';
      } else {
        url = 'https://vixsrc.to/tv/${widget.item.id}';
      }
    } else {
      url = 'https://vixsrc.to/${widget.item.mediaType}/${widget.item.id}';
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
          
          // Pulsante per vedere lo streaming
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Guarda ora"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => openStreamingLink(context),
              ),
            ),
          ),
        ],
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
              onTap: () => openStreamingLink(
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
          result = "Film trovato! Clicca il link per aprirlo o copia il link:";
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
          result = "Serie trovata! Clicca il link per aprirla o copia il link:";
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

  Future<void> openLink(String url) async {
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
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: "Copia link",
                          onPressed: () => copyLink(linkToOpen!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Pulsanti per azioni
                Row(
                  children: [
                    // Pulsante per aprire nel browser
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text("Apri nel Browser"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => openLink(linkToOpen!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Pulsante per vedere nel catalogo
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.library_books),
                        label: const Text("Vedi nel Catalogo"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          if (foundItem != null) {
                            // Salva la ricerca attuale nel servizio
                            SearchService.setSearch(
                              titleController.text.trim(),
                              choice == 'film' ? 'movie' : 'tv'
                            );
                            
                            // Passa alla tab del catalogo
                            final mainPageState = context.findAncestorStateOfType<_MainPageState>();
                            if (mainPageState != null) {
                              mainPageState._onItemTapped(1);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                // Aggiunta per visualizzare direttamente i dettagli
                if (foundItem != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.info),
                    label: const Text("Visualizza Dettagli"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 0),
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
  static const String apiKey = "80157e25b43ede5bf3e4114fa3845d18";
  
  String selectedType = 'movie';
  List<CatalogItem> catalogItems = [];
  List<int> allTmdbIds = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String error = '';
  String rawResponse = '';
  int loadedItemsCount = 0;
  int totalItems = 0;
  String? searchQuery; // Per memorizzare la ricerca dalla home
  
  final ScrollController _scrollController = ScrollController();
  final int _initialLoadCount = 20; // Numero di titoli da caricare all'inizio
  final int _loadMoreCount = 10; // Numero di titoli da caricare quando si scorre
  final double _scrollThreshold = 200.0; // Soglia di scorrimento per caricare più titoli
  
  // Mappe per i generi di film e serie TV
  Map<int, String> movieGenres = {};
  Map<int, String> tvGenres = {};
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadGenres();
    
    // Verifica se c'è una ricerca pendente
    if (SearchService.pendingSearchQuery != null) {
      searchQuery = SearchService.pendingSearchQuery;
      selectedType = SearchService.pendingSearchType ?? 'movie';
      
      // Programma la ricerca dopo il primo render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchInCatalog(searchQuery!);
        // Pulisci la ricerca pendente
        SearchService.clearSearch();
      });
    } else {
      fetchCatalogIds();
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
      _loadMoreTitles();
    }
  }
  
  // Imposta la query di ricerca e aggiorna la vista
  void setSearchQuery(String query, String type) {
    setState(() {
      searchQuery = query;
      selectedType = type;
    });
    // Effettua la ricerca
    searchInCatalog(query);
  }
  
  // Cerca un titolo nel catalogo
  Future<void> searchInCatalog(String query) async {
    if (mounted) {
      setState(() {
        isLoading = true;
        error = '';
        catalogItems = [];
      });
    }
    
    try {
      final searchType = selectedType == 'movie' ? 'movie' : 'tv';
      final url = 'https://api.themoviedb.org/3/search/$searchType?api_key=$apiKey&query=$query&language=it';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          List<CatalogItem> searchResults = [];
          List<Map<int, String>> genreMaps = [movieGenres, tvGenres];
          
          for (var item in data['results']) {
            searchResults.add(CatalogItem.fromTmdbJson(item, selectedType, genreMaps));
          }
          
          if (mounted) {
            setState(() {
              catalogItems = searchResults;
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              error = 'Nessun risultato trovato per "$query"';
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            error = 'Errore nella ricerca: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Errore: $e';
          isLoading = false;
        });
      }
    }
  }
  
  // Carica più titoli quando si scorre in fondo
  void _loadMoreTitles() {
    if (!isLoadingMore && loadedItemsCount < allTmdbIds.length) {
      if (mounted) {
        setState(() {
          isLoadingMore = true;
        });
      }
      
      // Calcola gli indici per il prossimo batch di ID da caricare
      final end = (loadedItemsCount + _loadMoreCount <= allTmdbIds.length) 
          ? loadedItemsCount + _loadMoreCount 
          : allTmdbIds.length;
      
      // Ottieni il prossimo batch di ID
      final nextBatch = allTmdbIds.sublist(loadedItemsCount, end);
      
      // Aggiungi immediatamente item di "caricamento" alla lista
      final startIndex = catalogItems.length;
      if (mounted) {
        setState(() {
          for (final id in nextBatch) {
            catalogItems.add(CatalogItem(
              id: id,
              title: 'Caricamento...',
              mediaType: selectedType,
            ));
          }
        });
      }
      
      // Carica i dettagli per questi ID
      _fetchTitlesForIds(nextBatch, startIndex).then((_) {
        if (mounted) {
          setState(() {
            isLoadingMore = false;
            loadedItemsCount = end;
          });
        }
      });
    }
  }
  
  // Carica le liste di generi da TMDB
  Future<void> _loadGenres() async {
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
    } catch (e) {
      // Ignora errori nel caricamento dei generi
    }
  }

  // Carica tutti gli ID TMDB inizialmente
  Future<void> fetchCatalogIds() async {
    // Se c'è una query di ricerca, esegui una ricerca invece
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return searchInCatalog(searchQuery!);
    }
    
    if (mounted) {
      setState(() {
        isLoading = true;
        error = '';
        catalogItems = [];
        allTmdbIds = [];
        rawResponse = '';
        loadedItemsCount = 0;
        totalItems = 0;
      });
    }

    try {
      // Ottiene la lista degli ID TMDB
      final url = 'https://vixsrc.to/api/list/$selectedType?lang=it';
      final response = await http.get(Uri.parse(url));
      
      if (mounted) {
        setState(() {
          rawResponse = 'URL: $url\n\nStatus: ${response.statusCode}\n\nResponse body:\n${response.body}';
        });
      }
      
      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          if (mounted) {
            setState(() {
              error = 'Errore nel formato della risposta: $e';
              isLoading = false;
            });
          }
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
          if (mounted) {
            setState(() {
              error = 'Nessun ID TMDB valido trovato nella risposta';
              isLoading = false;
            });
          }
          return;
        }
        
        // Salva tutti gli ID per il caricamento progressivo
        if (mounted) {
          setState(() {
            allTmdbIds = tmdbIds;
            totalItems = tmdbIds.length;
          });
        }
        
        // Carica solo i primi _initialLoadCount titoli inizialmente
        final initialBatchSize = tmdbIds.length < _initialLoadCount ? tmdbIds.length : _initialLoadCount;
        final initialBatch = tmdbIds.sublist(0, initialBatchSize);
        
        // Crea placeholder per i primi elementi
        List<CatalogItem> initialPlaceholders = initialBatch.map((id) => CatalogItem(
          id: id,
          title: 'Caricamento...',
          mediaType: selectedType,
        )).toList();
        
        if (mounted) {
          setState(() {
            catalogItems = initialPlaceholders;
          });
        }
        
        // Carica i dettagli per il batch iniziale
        await _fetchTitlesForIds(initialBatch, 0);
        
        if (mounted) {
          setState(() {
            isLoading = false;
            loadedItemsCount = initialBatchSize;
          });
        }
        
      } else {
        if (mounted) {
          setState(() {
            error = 'Errore ${response.statusCode}: ${response.reasonPhrase}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Errore di connessione: $e';
          isLoading = false;
        });
      }
    }
  }

  // Carica i titoli per un insieme specifico di ID
  Future<void> _fetchTitlesForIds(List<int> ids, int startIndex) async {
    final tmdbType = selectedType == 'tv' ? 'tv' : 'movie';
    
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
      if (mounted) {
        setState(() {
          for (int j = 0; j < results.length; j++) {
            final itemIndex = startIndex + i + j;
            if (itemIndex < catalogItems.length) {
              catalogItems[itemIndex] = results[j];
            }
          }
        });
      }
    }
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
                  rawResponse.isEmpty ? 'Nessuna risposta disponibile' : rawResponse,
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
          if (rawResponse.isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rawResponse));
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
          // Modifica: animazione dal basso invece che da destra
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: searchQuery != null 
            ? Text('Risultati per "$searchQuery"') 
            : const Text('Catalogo'),
        actions: [
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
              });
              fetchCatalogIds();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Pulsanti per selezionare film o serie TV (come nella pagina di ricerca)
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
                        });
                        fetchCatalogIds();
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
                        });
                        fetchCatalogIds();
                      }
                    },
                    child: const Text("Serie"),
                  ),
                ),
              ],
            ),
          ),

          // Contenuto principale
          Expanded(
            child: isLoading && catalogItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Caricamento catalogo...'),
                      ],
                    ),
                  )
                : error.isNotEmpty && catalogItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error, 
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                    ),
                                    onPressed: fetchCatalogIds,
                                    child: const Text("Riprova"),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _viewRawApiResponse,
                                    child: const Text("Vedi risposta API"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : catalogItems.isEmpty
                        ? const Center(
                            child: Text('Nessun contenuto trovato'),
                          )
                        : Stack(
                            children: [
                              // Lista principale con RefreshIndicator
                              RefreshIndicator(
                                onRefresh: fetchCatalogIds,
                                color: Theme.of(context).primaryColor,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(8),
                                  itemCount: catalogItems.length + (loadedItemsCount < allTmdbIds.length ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    // Se siamo all'ultimo elemento e ci sono ancora ID da caricare, mostra un indicatore
                                    if (index == catalogItems.length) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        alignment: Alignment.center,
                                        child: CircularProgressIndicator(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      );
                                    }
                                    
                                    final item = catalogItems[index];
                                    return Card(
                                      // Applica lo stile della card qui invece di usare cardTheme
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: InkWell(
                                        onTap: () => openDetailPage(context, item),
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
                                              Text("ID: ${item.id}"),
                                              if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                                                Text(
                                                  "Anno: ${item.releaseDate!.length >= 4 
                                                      ? item.releaseDate!.substring(0, 4) 
                                                      : item.releaseDate!}"
                                                ),
                                            ],
                                          ),
                                          trailing: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.info_outline,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Indicatore durante il caricamento
                              if (isLoading && !catalogItems.isEmpty)
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
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
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Caricamento titoli...',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
