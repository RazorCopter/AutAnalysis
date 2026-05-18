class PatientModel {
  String id;
  String nome;
  String cognome;
  int? altezza;
  double? peso;
  String? dataNascita;
  String? note;

  PatientModel({
    required this.id,
    required this.nome,
    required this.cognome,
    this.altezza,
    this.peso,
    this.dataNascita,
    this.note,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'],
      nome: json['nome'],
      cognome: json['cognome'],
      altezza: json['altezza'],
      peso: json['peso'] != null ? (json['peso'] as num).toDouble() : null,
      dataNascita: json['data_nascita'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nome': nome,
      'cognome': cognome,
      'altezza': altezza,
      'peso': peso,
      'data_nascita': dataNascita,
      'note': note,
    };
  }
}
