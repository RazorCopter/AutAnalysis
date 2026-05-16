class Option {
  final String testoRisposta;
  final int punteggio;

  Option({required this.testoRisposta, required this.punteggio});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      testoRisposta: json['testo_risposta'] ?? '',
      punteggio: json['punteggio'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'testo_risposta': testoRisposta,
    'punteggio': punteggio,
  };
}

class Question {
  final String idDomanda;
  final String? codice;
  final String testoDomanda;
  final List<Option> opzioni;

  Question({
    required this.idDomanda,
    this.codice,
    required this.testoDomanda,
    required this.opzioni,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      idDomanda: json['id_domanda'],
      codice: json['codice'],
      testoDomanda: json['testo_domanda'],
      opzioni: (json['opzioni'] as List?)?.map((e) => Option.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id_domanda': idDomanda,
    'codice': codice,
    'testo_domanda': testoDomanda,
    'opzioni': opzioni.map((e) => e.toJson()).toList(),
  };
}

class Section {
  final String titoloSezione;
  final List<Question> domande;

  Section({
    required this.titoloSezione,
    required this.domande,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      titoloSezione: json['titolo_sezione'],
      domande: (json['domande'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'titolo_sezione': titoloSezione,
    'domande': domande.map((q) => q.toJson()).toList(),
  };
}

class ScaleModel {
  final String id;
  String nome;
  final String descrizione;
  final List<Section> sezioni;

  ScaleModel({
    required this.id,
    required this.nome,
    required this.descrizione,
    required this.sezioni,
  });

  factory ScaleModel.fromJson(Map<String, dynamic> json) {
    return ScaleModel(
      id: json['id'],
      nome: json['nome'],
      descrizione: json['descrizione'],
      sezioni: (json['sezioni'] as List)
          .map((s) => Section.fromJson(s))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'descrizione': descrizione,
    'sezioni': sezioni.map((s) => s.toJson()).toList(),
  };
}
