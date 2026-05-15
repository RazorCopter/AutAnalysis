import 'package:flutter/material.dart';
import '../models/scale_model.dart';
import '../services/api_service.dart';

class ProtocolsScreen extends StatefulWidget {
  const ProtocolsScreen({super.key});

  @override
  State<ProtocolsScreen> createState() => _ProtocolsScreenState();
}

class _ProtocolsScreenState extends State<ProtocolsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<ScaleModel>> _scalesFuture;

  @override
  void initState() {
    super.initState();
    _refreshScales();
  }

  void _refreshScales() {
    setState(() {
      _scalesFuture = _apiService.getScales();
    });
  }

  void _showEditDialog(ScaleModel scale) {
    final TextEditingController controller = TextEditingController(text: scale.nome);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rinomina Protocollo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome Protocollo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                scale.nome = newName;
                final success = await _apiService.updateScale(scale);
                if (success && mounted) {
                  Navigator.pop(context);
                  _refreshScales();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Protocollo aggiornato')),
                  );
                }
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ScaleModel scale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Sei sicuro di voler eliminare il protocollo "${scale.nome}"? Questa azione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await _apiService.deleteScale(scale.id);
              if (success && mounted) {
                Navigator.pop(context);
                _refreshScales();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Protocollo eliminato')),
                );
              }
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Protocolli a Sistema', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshScales),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: FutureBuilder<List<ScaleModel>>(
              future: _scalesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Errore: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nessun protocollo trovato. Vai in Impostazioni per importarli.'));
                }

                final scales = snapshot.data!;
                return ListView.builder(
                  itemCount: scales.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final scale = scales[index];
                    // Colori puzzle alternati
                    final accentColors = [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                      AppTheme.accentColor,
                      const Color(0xFFCE93D8), // Lilla soft
                    ];
                    final cardColor = accentColors[index % accentColors.length];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.library_books, color: cardColor),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  scale.nome,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                onPressed: () => _showEditDialog(scale),
                                tooltip: 'Rinomina',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                onPressed: () => _confirmDelete(scale),
                                tooltip: 'Elimina',
                              ),
                            ],
                          ),
                          subtitle: Text(
                            scale.descrizione,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          childrenPadding: const EdgeInsets.all(16),
                          children: scale.sezioni.map((section) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: ExpansionTile(
                                shape: const RoundedRectangleBorder(side: BorderSide.none),
                                title: Text(
                                  section.titoloSezione,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                leading: Icon(Icons.folder_open_rounded, size: 22, color: cardColor.withOpacity(0.7)),
                                children: section.domande.map((question) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                    leading: Icon(Icons.quiz_outlined, size: 18, color: Colors.grey.shade400),
                                    title: Text(
                                      question.testoDomanda,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Text(
                                        question.tipoRisposta,
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
