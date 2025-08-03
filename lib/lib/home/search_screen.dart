import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = false;
  
  // Lista di film esempio
  final List<Map<String, dynamic>> _movies = [
    {
      'id': 1,
      'title': 'Inception',
      'year': '2010',
      'imageUrl': 'https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
      'description': 'Un ladro specializzato nell\'estrarre segreti dal subconscio durante lo stato onirico.',
    },
    {
      'id': 2,
      'title': 'The Dark Knight',
      'year': '2008',
      'imageUrl': 'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
      'description': 'Batman deve affrontare il Joker, un criminale che semina il caos a Gotham City.',
    },
    {
      'id': 3,
      'title': 'Interstellar',
      'year': '2014',
      'imageUrl': 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      'description': 'Un gruppo di astronauti viaggia attraverso un wormhole alla ricerca di una nuova casa per l\'umanità.',
    },
  ];
  
  // Lista di serie TV esempio
  final List<Map<String, dynamic>> _tvShows = [
    {
      'id': 101,
      'title': 'Stranger Things',
      'year': '2016',
      'imageUrl': 'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
      'description': 'Un gruppo di bambini affronta forze soprannaturali e esperimenti governativi segreti.',
    },
    {
      'id': 102,
      'title': 'Breaking Bad',
      'year': '2008',
      'imageUrl': 'https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
      'description': 'Un insegnante di chimica con cancro terminale inizia a produrre metanfetamine per garantire il futuro della sua famiglia.',
    },
  ];
  
  // Risultati di ricerca filtrati
  List<Map<String, dynamic>> get _filteredResults {
    if (_query.isEmpty) {
      return [];
    }
    
    final query = _query.toLowerCase();
    final movieResults = _movies.where((movie) => 
      movie['title'].toLowerCase().contains(query) || 
      movie['description'].toLowerCase().contains(query)
    ).toList();
    
    final tvResults = _tvShows.where((show) => 
      show['title'].toLowerCase().contains(query) || 
      show['description'].toLowerCase().contains(query)
    ).toList();
    
    return [...movieResults, ...tvResults];
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _query = query;
      _isLoading = true;
    });
    
    // Simula un caricamento
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Cerca'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barra di ricerca
          CustomSearchBar(
            controller: _searchController,
            onSearch: _performSearch,
          ),
          
          // Risultati di ricerca
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _query.isEmpty
                    ? _buildInitialContent()
                    : _filteredResults.isEmpty
                        ? _buildNoResultsFound()
                        : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  // Contenuto iniziale prima della ricerca
  Widget _buildInitialContent() {
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
            'Cerca film, serie TV e altro',
            style: TextStyle(
              color: AppTheme.subtitleColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Messaggio quando non ci sono risultati
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
            'Nessun risultato trovato per "$_query"',
            style: const TextStyle(
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Lista dei risultati di ricerca
  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        final result = _filteredResults[index];
        return ContentCard(
          title: result['title'],
          subtitle: '${result['year']} • ${result['description']}',
          imageUrl: result['imageUrl'],
          onTap: () {
            // Implementa azione quando si seleziona un risultato
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hai selezionato ${result['title']}')),
            );
          },
        );
      },
    );
  }
}
