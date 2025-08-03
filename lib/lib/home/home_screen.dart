import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
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

  // Pagine da mostrare nella barra di navigazione inferiore
  final List<Widget> _pages = [
    const HomeContent(),
    const SearchContent(),
    const ProfileContent(),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Apri le impostazioni
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
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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

// Contenuto della pagina Home
class HomeContent extends StatelessWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    
    return Column(
      children: [
        // Barra di ricerca
        CustomSearchBar(
          controller: searchController,
          onSearch: (value) {
            // Gestisci la ricerca
          },
        ),
        
        // Tab di selezione
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildCategoryTab(context, 'All', true),
              _buildCategoryTab(context, 'People', false),
              _buildCategoryTab(context, 'Posts', false),
            ],
          ),
        ),
        
        // Indicatore tab selezionato
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 2),
          height: 2,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: AppTheme.accentColor,
                ),
              ),
              const Expanded(
                flex: 2,
                child: SizedBox(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Contenuto scorrevole
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Sezione Film
              _buildCategorySection(
                context,
                'Film',
                'Trova i migliori film da guardare',
                'https://image.tmdb.org/t/p/w500/rr7E0NoGKxvbkb89eR1GwfoYjpA.jpg',
              ),
              
              const SizedBox(height: 24),
              
              // Sezione Serie TV
              _buildCategorySection(
                context,
                'Serie TV',
                'Le serie più popolari del momento',
                'https://image.tmdb.org/t/p/w500/sWgBv7LV2PRoQgkxwlibdGXKz1S.jpg',
              ),
              
              const SizedBox(height: 24),
              
              // Sezione Documentari
              _buildCategorySection(
                context,
                'Documentari',
                'Scopri il mondo con i nostri documentari',
                'https://image.tmdb.org/t/p/w500/9t0tJXcOdWwwxmGTk112HGDaT0Q.jpg',
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  // Costruisce un tab di categoria
  Widget _buildCategoryTab(BuildContext context, String title, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.subtitleColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }

  // Costruisce una sezione di categoria
  Widget _buildCategorySection(BuildContext context, String title, String subtitle, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titolo e sottotitolo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Immagine
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
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

// Contenuto della pagina Cerca
class SearchContent extends StatelessWidget {
  const SearchContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Pagina di ricerca - Da implementare'),
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
    
    return Column(
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
        
        // Pulsante logout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
      ],
    );
  }
}
