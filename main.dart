import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

void main() {
  runApp(const StreamingApp());
}

class StreamingApp extends StatelessWidget {
  const StreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamingGoonity',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StreamingHomePage(),
    );
  }
}

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
  bool isLoading = false;

  static const apiKey = "80157e25b43ede5bf3e4114fa3845d18";

  Future<void> search() async {
    setState(() { isLoading = true; result = ""; });
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
        setState(() {
          result = "Apro: $url";
          isLoading = false;
        });
        await openLink(url);
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
        setState(() {
          result = "Apro: $url";
          isLoading = false;
        });
        await openLink(url);
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() => result = "Non posso aprire il link.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StreamingGoonity')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: choice == 'film' ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        choice = 'film';
                        seasonController.clear();
                        episodeController.clear();
                      });
                    },
                    child: const Text("Film"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: choice == 'serie' ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        choice = 'serie';
                        seasonController.clear();
                        episodeController.clear();
                      });
                    },
                    child: const Text("Serie"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Titolo",
                border: OutlineInputBorder(),
              ),
            ),
            if (choice == "serie") ...[
              const SizedBox(height: 16),
              TextField(
                controller: seasonController,
                decoration: const InputDecoration(
                  labelText: "Stagione",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: episodeController,
                decoration: const InputDecoration(
                  labelText: "Episodio",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : search,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Cerca e apri link"),
            ),
            const SizedBox(height: 16),
            Text(
              result,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
