import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';

class MovieService {
  static const String baseUrl = 'https://ad549817b04d.ngrok-free.app'; // Aggiorna con il tuo URL ngrok
  static const String moviesEndpoint = '/api.php?action=getMovies';
  static const String searchEndpoint = '/api.php?action=searchMovies';

  Future<List<Movie>> getMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$moviesEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'StreamingApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data.containsKey('movies')) {
          return List<Movie>.from(
            data['movies'].map((movie) => Movie.fromJson(movie)),
          );
        }
        return [];
      } else {
        throw Exception('Errore nel recupero dei film: ${response.statusCode}');
      }
    } catch (e) {
      print('Errore nel servizio film: $e');
      return [];
    }
  }

  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$searchEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'StreamingApp/1.0',
        },
        body: json.encode({
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data.containsKey('movies')) {
          return List<Movie>.from(
            data['movies'].map((movie) => Movie.fromJson(movie)),
          );
        }
        return [];
      } else {
        throw Exception('Errore nella ricerca: ${response.statusCode}');
      }
    } catch (e) {
      print('Errore nel servizio di ricerca: $e');
      return [];
    }
  }

  // Genera dati di esempio in caso di errore API
  List<Movie> getExampleMovies() {
    return [
      Movie(
        id: '1',
        title: 'The Shawshank Redemption',
        description: 'Due uomini trovano redenzione attraverso atti di decenza comune.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/9O7gLzmreU0nGkIB6K3BsJbzvNv.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=6hB3S9bIaco',
        genres: ['Drama'],
        year: '1994',
        rating: 9.3,
      ),
      Movie(
        id: '2',
        title: 'The Godfather',
        description: 'Il patriarca anziano di una dinastia del crimine organizzato trasferisce il controllo del suo impero clandestino al suo figlio riluttante.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=sY1S34973zA',
        genres: ['Crime', 'Drama'],
        year: '1972',
        rating: 9.2,
      ),
      Movie(
        id: '3',
        title: 'Inception',
        description: 'Un ladro che ruba segreti aziendali attraverso l\'uso della tecnologia di condivisione dei sogni riceve l\'incarico inverso di piantare un\'idea nella mente di un CEO.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=YoHD9XEInc0',
        genres: ['Action', 'Adventure', 'Sci-Fi'],
        year: '2010',
        rating: 8.8,
      ),
      Movie(
        id: '4',
        title: 'Pulp Fiction',
        description: 'Le vite di due sicari, un pugile, la moglie di un gangster e una coppia di rapinatori di ristoranti si intrecciano in quattro racconti di violenza e redenzione.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=s7EdQ4FqbhY',
        genres: ['Crime', 'Drama'],
        year: '1994',
        rating: 8.9,
      ),
    ];
  }
}
