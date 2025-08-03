import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../models/movie_model.dart';
import '../services/movie_service.dart';
import '../screens/movie_detail_screen.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/movie_card.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Cambia pagina e aggiorna l'indice
  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_currentIndex == 0 
            ? 'Home' 
            : _currentIndex == 1 
                ? 'Cerca' 
                : 'Profilo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          HomeContent(),
          SearchContent(),
          ProfileContent(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Cerca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}

// Contenuto della pagina Home con catalogo
class HomeContent extends StatefulWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final MovieService _movieService = MovieService();
  List<Movie> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final movies = await _movieService.getMovies();
      
      // Se non ci sono film dall'API, usa quelli di esempio
      if (movies.isEmpty) {
        _movies = _movieService.getExampleMovies();
      } else {
        _movies = movies;
      }
    } catch (e) {
      // In caso di errore, usa i film di esempio
      _movies = _movieService.getExampleMovies();
      print('Errore nel caricamento dei film: $e');
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
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMovies,
      color: AppTheme.accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Sezione Film in evidenza
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Film in evidenza',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Film in evidenza (orizzontale)
            SizedBox(
              height: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _movies.length > 5 ? 5 : _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];
                  return FeaturedMovieCard(
                    movie: movie,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailScreen(movie: movie),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sezione Catalogo completo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Catalogo completo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Griglia dei film
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];
                  return MovieGridCard(
                    movie: movie,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailScreen(movie: movie),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Contenuto della pagina Cerca aggiornata
class SearchContent extends StatefulWidget {
  const SearchContent({Key? key}) : super(key: key);

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  final MovieService _movieService = MovieService();
  List<Movie> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    
    try {
      final results = await _movieService.searchMovies(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Errore nella ricerca: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra di ricerca
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomSearchBar(
            controller: _searchController,
            onSearch: _performSearch,
            hintText: 'Cerca film, serie TV...',
          ),
        ),
        
        // Risultati della ricerca
        Expanded(
          child: _isLoading 
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                  ),
                )
              : !_hasSearched
                  ? _buildInitialSearchState()
                  : _searchResults.isEmpty
                      ? _buildNoResultsFound()
                      : _buildSearchResults(),
        ),
      ],
    );
  }

  // Widget per mostrare lo stato iniziale della ricerca
  Widget _buildInitialSearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: AppTheme.subtitleColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Cerca film per titolo o descrizione',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget per mostrare quando non ci sono risultati
  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun risultato trovato per "${_searchController.text}"',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _hasSearched = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancella ricerca'),
          ),
        ],
      ),
    );
  }

  // Widget per mostrare i risultati della ricerca
  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        return SearchResultCard(
          movie: movie,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailScreen(movie: movie),
              ),
            );
          },
        );
      },
    );
  }
}

// Contenuto della pagina Profilo
class ProfileContent extends StatelessWidget {
  const ProfileContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.userName ?? 'Utente';
    final userEmail = AuthService.userEmail ?? 'email@example.com';
    
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // Avatar profilo
          CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.accentColor,
            child: Text(
              userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Nome utente
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Email utente
          Text(
            userEmail,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.subtitleColor,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Preferenze e impostazioni
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildProfileOption(
                  context,
                  icon: Icons.favorite,
                  title: 'I miei preferiti',
                  onTap: () {
                    // Implementare
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  context,
                  icon: Icons.history,
                  title: 'Cronologia visualizzazioni',
                  onTap: () {
                    // Implementare
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  context,
                  icon: Icons.notifications,
                  title: 'Notifiche',
                  onTap: () {
                    // Implementare
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Supporto e informazioni
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildProfileOption(
                  context,
                  icon: Icons.help,
                  title: 'Aiuto e supporto',
                  onTap: () {
                    // Implementare
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  context,
                  icon: Icons.info,
                  title: 'Informazioni',
                  onTap: () {
                    // Implementare
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Pulsante logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthService.logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDivider() {
    return Divider(
      color: Colors.grey[800],
      height: 1,
      indent: 56,
      endIndent: 16,
    );
  }
}
