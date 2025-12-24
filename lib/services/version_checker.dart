import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionConfig {
  final String minSupportedVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String message;

  VersionConfig({
    required this.minSupportedVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.message,
  });

  factory VersionConfig.fromJson(Map<String, dynamic> json) {
    return VersionConfig(
      minSupportedVersion: json['min_supported_version'] ?? '1.0.0',
      latestVersion: json['latest_version'] ?? '1.0.0',
      forceUpdate: json['force_update'] ?? false,
      message: json['message'] ?? 'Aggiorna l\'app per continuare a usarla.',
    );
  }
}

class VersionChecker {
  // Modifica questo URL con l'endpoint che ospiterà il tuo file di configurazione
  static const String configUrl = 'https://redaproject.whf.bz/app_config.json';
  
  static Future<void> checkAppVersion(BuildContext context) async {
    try {
      // Ottieni informazioni sulla versione attuale dell'app
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      // Ottieni la configurazione dal server
      final response = await http.get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final VersionConfig config = VersionConfig.fromJson(data);
        
        // Confronta le versioni
        if (_isVersionLower(currentVersion, config.minSupportedVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, config);
          }
        }
      }
    } catch (e) {
      print('Errore nel controllo della versione: $e');
      // Non bloccare l'app in caso di errore di connessione
    }
  }
  
  static bool _isVersionLower(String currentVersion, String minVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> min = minVersion.split('.').map(int.parse).toList();
    
    // Assicurati che entrambe le liste abbiano la stessa lunghezza
    while (current.length < min.length) current.add(0);
    while (min.length < current.length) min.add(0);
    
    for (int i = 0; i < current.length; i++) {
      if (current[i] < min[i]) return true;
      if (current[i] > min[i]) return false;
    }
    
    return false; // Versioni uguali
  }
  
  static void _showUpdateDialog(BuildContext context, VersionConfig config) {
    showDialog(
      context: context,
      barrierDismissible: !config.forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !config.forceUpdate,
        child: AlertDialog(
          title: const Text('Aggiornamento Richiesto'),
          content: Text(config.message),
          actions: [
            if (!config.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Più tardi'),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.example.StreamingAir'
                );
                
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Aggiorna ora'),
            ),
          ],
        ),
      ),
    );
  }
}
