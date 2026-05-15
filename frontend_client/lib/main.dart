import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutAnalysis - Valutazione',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SelectionScreen(),
    );
  }
}

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header con logo
            _buildHeader(context),
            // Corpo principale
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo bradipo decorativo
                    _buildSlothLogo(),
                    const SizedBox(height: 32),
                    const Text(
                      'Nuova Valutazione',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Seleziona il paziente e la scala\ndi valutazione da compilare',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Card di selezione paziente
                    _buildSelectionCard(
                      icon: Icons.person_outline,
                      label: 'Paziente',
                      placeholder: 'Seleziona paziente...',
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    // Card di selezione scala
                    _buildSelectionCard(
                      icon: Icons.library_books_outlined,
                      label: 'Scala di Valutazione',
                      placeholder: 'Seleziona protocollo...',
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(height: 40),
                    // Pulsante avvia
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () {
                          // Naviga al WizardScreen (da migrare dal frontend_legacy)
                        },
                        icon: const Icon(Icons.play_circle_outline, size: 24),
                        label: const Text(
                          'Inizia Compilazione',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer puzzle decoration
            _buildPuzzleFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AutAnalysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Valutazione Clinica',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlothLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            AppTheme.purpleColor.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Puzzle pieces decorative layout
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _puzzlePiece(AppTheme.primaryColor),
              const SizedBox(width: 4),
              _puzzlePiece(AppTheme.secondaryColor),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _puzzlePiece(AppTheme.accentColor),
              const SizedBox(width: 4),
              _puzzlePiece(AppTheme.purpleColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _puzzlePiece(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.extension, size: 16, color: Colors.white.withValues(alpha: 0.9)),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String label,
    required String placeholder,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  placeholder,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildPuzzleFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final colors = [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
            AppTheme.accentColor,
            AppTheme.purpleColor,
          ];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.extension,
              size: 20,
              color: colors[i].withValues(alpha: 0.4),
            ),
          );
        }),
      ),
    );
  }
}
