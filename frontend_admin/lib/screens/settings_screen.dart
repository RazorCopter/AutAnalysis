// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _apiKeyController = TextEditingController();
  
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isImporting = false;
  String? _uploadStatus;
  String? _dbStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = await _apiService.getGeminiKey();
    if (key != null && key.isNotEmpty) {
      setState(() {
        _apiKeyController.text = key;
      });
    }
  }

  Future<void> _pickAndUploadJSON() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _uploadStatus = 'Caricamento in corso...';
      });

      final success = await _apiService.uploadProtocolJSON(
        result.files.single,
      );

      setState(() {
        _isLoading = false;
        if (success) {
          _uploadStatus = 'Protocollo caricato con successo!';
        } else {
          _uploadStatus = 'Errore durante il caricamento o formato non ancora supportato.';
        }
      });
    }
  }

  Future<void> _exportDatabase() async {
    setState(() {
      _isExporting = true;
      _dbStatus = 'Esportazione in corso...';
    });
    final bytes = await _apiService.exportDatabase();
    setState(() => _isExporting = false);
    if (bytes != null) {
      final b64 = base64Encode(bytes);
      final dataUrl = 'data:application/json;base64,$b64';
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-').substring(0, 19);
      html.AnchorElement(href: dataUrl)
        ..setAttribute('download', 'autanalysis_backup_$timestamp.json')
        ..click();
      setState(() => _dbStatus = 'Backup esportato con successo!');
    } else {
      setState(() => _dbStatus = 'Errore durante l\'esportazione.');
    }
  }

  Future<void> _importDatabase() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _isImporting = true;
        _dbStatus = 'Importazione in corso...';
      });

      final success = await _apiService.importDatabase(result.files.single);

      setState(() {
        _isImporting = false;
        if (success) {
          _dbStatus = 'Database importato con successo!';
        } else {
          _dbStatus = 'Errore durante l\'importazione. Verifica il formato del file.';
        }
      });
    }
  }

  Future<void> _saveAIConfig() async {
    setState(() => _isLoading = true);
    final success = await _apiService.saveGeminiKey(_apiKeyController.text);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Configurazione AI salvata!' : 'Errore nel salvataggio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Impostazioni di Sistema', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          // Sezione Protocolli
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protocolli Clinici', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Importa le scale di valutazione da file JSON.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndUploadJSON,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Carica Protocollo JSON'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_isLoading) const CircularProgressIndicator(),
                      if (_isLoading) const SizedBox(width: 16),
                      if (_uploadStatus != null) 
                        Expanded(child: Text(_uploadStatus!, style: TextStyle(color: _uploadStatus!.contains('Errore') ? Colors.red : Colors.green))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sezione AI
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configurazione AI (Gemini)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Inserisci la tua API Key per abilitare le funzionalità di analisi intelligente dei dati.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Gemini API Key',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveAIConfig,
                        icon: const Icon(Icons.save),
                        label: const Text('Salva Configurazione'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sezione Database
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Database', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Esporta l\'intero database in un file JSON o ripristina un backup precedente.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting || _isImporting ? null : _exportDatabase,
                          icon: _isExporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_rounded),
                          label: Text(_isExporting ? 'Esportazione...' : 'Esporta Database'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting || _isImporting ? null : _importDatabase,
                          icon: _isImporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file),
                          label: Text(_isImporting ? 'Importazione...' : 'Importa Database'),
                        ),
                      ),
                    ],
                  ),
                  if (_dbStatus != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_isImporting || _isExporting) const CircularProgressIndicator(),
                        if (_isImporting || _isExporting) const SizedBox(width: 16),
                        Expanded(child: Text(_dbStatus!, style: TextStyle(color: _dbStatus!.contains('Errore') ? Colors.red : Colors.green))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
