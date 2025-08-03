import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.userName ?? 'Utente';
    final userEmail = AuthService.userEmail ?? 'email@example.com';
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profilo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar profilo
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.accentColor,
              child: Text(
                userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Nome utente
            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Email utente
            Text(
              userEmail,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Sezione impostazioni
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    context,
                    icon: Icons.person,
                    title: 'Modifica profilo',
                    onTap: () {
                      // Implementare modifica profilo
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funzionalità non ancora disponibile')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsItem(
                    context,
                    icon: Icons.notifications,
                    title: 'Notifiche',
                    onTap: () {
                      // Implementare gestione notifiche
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funzionalità non ancora disponibile')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsItem(
                    context,
                    icon: Icons.lock,
                    title: 'Privacy e Sicurezza',
                    onTap: () {
                      // Implementare privacy e sicurezza
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funzionalità non ancora disponibile')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsItem(
                    context,
                    icon: Icons.help,
                    title: 'Aiuto e Supporto',
                    onTap: () {
                      // Implementare aiuto e supporto
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funzionalità non ancora disponibile')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsItem(
                    context,
                    icon: Icons.info,
                    title: 'Informazioni',
                    onTap: () {
                      // Implementare informazioni
                      showAboutDialog(
                        context: context,
                        applicationName: 'Streaming App',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2023 Reda Project',
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Pulsante logout
            ElevatedButton.icon(
              onPressed: () async {
                // Mostra dialog di conferma
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Sei sicuro di voler effettuare il logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await AuthService.logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Costruisce un elemento di impostazioni
  Widget _buildSettingsItem(
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
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
