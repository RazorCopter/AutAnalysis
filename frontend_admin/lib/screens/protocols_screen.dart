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
                  itemBuilder: (context, index) {
                    final scale = scales[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: const Icon(Icons.library_books),
                        title: Text(scale.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(scale.descrizione),
                        children: scale.sezioni.map((section) {
                          return ExpansionTile(
                            title: Text(section.titoloSezione, style: const TextStyle(fontWeight: FontWeight.w600)),
                            leading: const Icon(Icons.folder_open),
                            children: section.domande.map((question) {
                              return ListTile(
                                leading: const Icon(Icons.question_answer, size: 20),
                                title: Text(question.testoDomanda),
                                trailing: Chip(label: Text(question.tipoRisposta)),
                              );
                            }).toList(),
                          );
                        }).toList(),
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
