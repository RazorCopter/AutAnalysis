class AnswerModel {
  final String codiceDomanda;
  int punteggio;
  String? nota;

  AnswerModel({
    required this.codiceDomanda,
    required this.punteggio,
    this.nota,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      codiceDomanda: json['codice_domanda'] ?? '',
      punteggio: json['punteggio'] ?? 0,
      nota: json['nota'],
    );
  }

  Map<String, dynamic> toJson() => {
    'codice_domanda': codiceDomanda,
    'punteggio': punteggio,
    if (nota != null && nota!.isNotEmpty) 'nota': nota,
  };
}

class DomainScore {
  final String codice;
  final String etichetta;
  final int punteggio;
  final int numDomande;

  DomainScore({
    required this.codice,
    required this.etichetta,
    required this.punteggio,
    required this.numDomande,
  });

  factory DomainScore.fromJson(Map<String, dynamic> json) {
    return DomainScore(
      codice: json['codice'] ?? '',
      etichetta: json['etichetta'] ?? '',
      punteggio: (json['punteggio_totale'] as num?)?.toInt() ?? 0,
      numDomande: (json['num_domande'] as num?)?.toInt() ?? 0,
    );
  }
}

class DomainAnalysis {
  final String codice;
  final String etichetta;
  final int punteggioDiretto;
  final int? punteggioStandard;
  final int? percentileDominio;
  final String? fascia;
  final int numDomande;

  DomainAnalysis({
    required this.codice,
    required this.etichetta,
    required this.punteggioDiretto,
    this.punteggioStandard,
    this.percentileDominio,
    this.fascia,
    required this.numDomande,
  });

  factory DomainAnalysis.fromJson(Map<String, dynamic> json) {
    return DomainAnalysis(
      codice: json['codice'] ?? '',
      etichetta: json['etichetta'] ?? '',
      punteggioDiretto: (json['punteggio_diretto'] as num?)?.toInt() ?? 0,
      punteggioStandard: (json['punteggio_standard'] as num?)?.toInt(),
      percentileDominio: (json['percentile_dominio'] as num?)?.toInt(),
      fascia: json['fascia'] as String?,
      numDomande: (json['num_domande'] as num?)?.toInt() ?? 0,
    );
  }
}

class PsychometricAnalysis {
  final String idValutazione;
  final String idPaziente;
  final String idScala;
  final String scalaNome;
  final List<DomainAnalysis> domini;
  final int? sommaPunteggiStandard;
  final int? indiceQv;
  final int? percentile;
  final String? fasciaQv;

  PsychometricAnalysis({
    required this.idValutazione,
    required this.idPaziente,
    required this.idScala,
    required this.scalaNome,
    required this.domini,
    this.sommaPunteggiStandard,
    this.indiceQv,
    this.percentile,
    this.fasciaQv,
  });

  factory PsychometricAnalysis.fromJson(Map<String, dynamic> json) {
    return PsychometricAnalysis(
      idValutazione: json['id_valutazione'] ?? '',
      idPaziente: json['id_paziente'] ?? '',
      idScala: json['id_scala'] ?? '',
      scalaNome: json['scala_nome'] ?? '',
      sommaPunteggiStandard: (json['somma_punteggi_standard'] as num?)?.toInt(),
      indiceQv: (json['indice_qv'] as num?)?.toInt(),
      percentile: (json['percentile'] as num?)?.toInt(),
      fasciaQv: json['fascia_qv'] as String?,
      domini: (json['domini'] as List?)
              ?.map((e) => DomainAnalysis.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AggregatedEvaluation {
  final String idValutazione;
  final String idPaziente;
  final String idScala;
  final int anno;
  final String dataCompilazione;
  final String nomeOperatore;
  final String? nomeIntervistato;
  final List<DomainScore> domini;
  final List<AnswerModel> risposte;

  AggregatedEvaluation({
    required this.idValutazione,
    required this.idPaziente,
    required this.idScala,
    required this.anno,
    required this.dataCompilazione,
    required this.nomeOperatore,
    this.nomeIntervistato,
    required this.domini,
    required this.risposte,
  });

  factory AggregatedEvaluation.fromJson(Map<String, dynamic> json) {
    return AggregatedEvaluation(
      idValutazione: json['id_valutazione'] ?? '',
      idPaziente: json['id_paziente'] ?? '',
      idScala: json['id_scala'] ?? '',
      anno: (json['anno'] as num?)?.toInt() ?? 0,
      dataCompilazione: json['data_compilazione']?.toString() ?? '',
      nomeOperatore: json['nome_operatore'] ?? '',
      nomeIntervistato: json['nome_intervistato'] as String?,
      domini: (json['domini'] as List?)
              ?.map((e) => DomainScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      risposte: (json['risposte'] as List?)
              ?.map((e) => AnswerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
