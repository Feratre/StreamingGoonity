class Movie {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String videoUrl;
  final List<String> genres;
  final String year;
  final double rating;

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.videoUrl,
    required this.genres,
    required this.year,
    required this.rating,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      year: json['year'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
    );
  }
}
