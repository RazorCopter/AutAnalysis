"""
analytics.py — Motore di calcolo psicometrico per scale cliniche.

Supporta sia scale con tabelle di conversione (San Martín) sia scale semplici (POS)
con semplice aggregazione per dominio.
"""

from typing import List, Dict, Optional


def build_domain_map(scale_doc: dict) -> Dict[str, str]:
    """Costruisce la mappa {codice_dominio: nome_dominio} da un documento Scale."""
    domain_map: Dict[str, str] = {}
    for sezione in scale_doc.get("sezioni", []):
        cod = sezione.get("codice_sezione", "")
        nome = sezione.get("titolo_sezione", cod)
        if cod:
            domain_map[cod.upper()] = nome
    return domain_map


def compute_direct_scores(risposte: list, domain_map: Dict[str, str]) -> List[dict]:
    """Calcola i punteggi diretti (grezzi) per ogni dominio."""
    sorted_prefixes = sorted(domain_map.keys(), key=len, reverse=True)
    aggregated: Dict[str, dict] = {}
    for cod, label in domain_map.items():
        aggregated[cod] = {
            "codice": cod,
            "etichetta": label,
            "punteggio_totale": 0,
            "num_domande": 0,
        }

    for r in risposte:
        codice = r.get("codice_domanda", "")
        for prefix in sorted_prefixes:
            if codice.upper().startswith(prefix.upper()):
                aggregated[prefix]["punteggio_totale"] += r.get("punteggio", 0)
                aggregated[prefix]["num_domande"] += 1
                break

    return list(aggregated.values())


def _std_to_fascia(std: int) -> str:
    """Restituisce la fascia interpretativa per un punteggio standard."""
    if std <= 4:
        return "Molto Basso"
    elif std <= 7:
        return "Basso"
    elif std <= 12:
        return "Medio"
    elif std <= 15:
        return "Alto"
    else:
        return "Molto Alto"


def compute_psychometric_analysis(
    risposte: list,
    scale_doc: dict,
) -> dict:
    """
    Calcola l'analisi psicometrica completa.

    Per scale con scoring_tables (San Martín):
      - Punteggio diretto per dominio
      - Punteggio standard (1-20) via tabella A
      - Percentile per dominio via tabella A
      - Indice QdV = somma std → tabella B
      - Percentile globale via tabella B

    Per scale senza scoring_tables (POS): solo punteggi diretti.

    Returns:
        {
            "domini": [{codice, etichetta, punteggio_diretto, punteggio_standard,
                        percentile_dominio, fascia, num_domande}, ...],
            "indice_qv": int | None,
            "percentile": int | None,
            "fascia_qv": str | None,
            "scala_nome": str,
        }
    """
    domain_map = build_domain_map(scale_doc)
    direct_scores = compute_direct_scores(risposte, domain_map)

    scoring = scale_doc.get("scoring_tables")
    if not scoring:
        return {
            "domini": [
                {
                    "codice": d["codice"],
                    "etichetta": d["etichetta"],
                    "punteggio_diretto": d["punteggio_totale"],
                    "punteggio_standard": None,
                    "percentile_dominio": None,
                    "fascia": None,
                    "num_domande": d["num_domande"],
                }
                for d in direct_scores
            ],
            "indice_qv": None,
            "percentile": None,
            "fascia_qv": None,
            "scala_nome": scale_doc.get("nome", ""),
        }

    table_a = scoring.get("tabella_A_conversione_punteggi_diretti_standard", {})
    table_b = scoring.get("tabella_B_indice_qdv", {})

    domini_12 = table_a.get("domini_con_12_item", {})
    conv_12 = domini_12.get("conversione", {})
    dom_11 = table_a.get("dominio_IS_con_11_item", {})
    conv_11 = dom_11.get("conversione", {})
    conv_qdv = table_b.get("conversione", {})

    domain_analyses = []
    total_standard = 0

    for d in direct_scores:
        raw = d["punteggio_totale"]
        codice = d["codice"].upper()

        if codice == "IS":
            conv = conv_11
        else:
            conv = conv_12

        raw_str = str(raw)
        std_val = None
        perc_val = None
        if raw_str in conv:
            entry = conv[raw_str]
            std_val = entry.get("std")
            perc_val = entry.get("perc")

        fascia = _std_to_fascia(std_val) if std_val is not None else None

        domain_analyses.append({
            "codice": d["codice"],
            "etichetta": d["etichetta"],
            "punteggio_diretto": raw,
            "punteggio_standard": std_val,
            "percentile_dominio": perc_val,
            "fascia": fascia,
            "num_domande": d["num_domande"],
        })

        if std_val is not None:
            total_standard += std_val

    indice_qv = None
    percentile = None
    fascia_qv = None

    if conv_qdv:
        total_str = str(total_standard)
        if total_str in conv_qdv:
            entry = conv_qdv[total_str]
            indice_qv = entry.get("indice")
            percentile = entry.get("perc")
            fascia_qv = _indice_to_fascia(indice_qv)

    return {
        "domini": domain_analyses,
        "indice_qv": indice_qv,
        "percentile": percentile,
        "fascia_qv": fascia_qv,
        "scala_nome": scale_doc.get("nome", ""),
    }


def _indice_to_fascia(indice: int) -> str:
    """Restituisce la fascia interpretativa per l'indice QdV (media=100, DS=15)."""
    if indice > 145:
        return "Molto Alto"
    elif indice > 115:
        return "Alto"
    elif indice >= 85:
        return "Medio"
    elif indice >= 70:
        return "Basso"
    else:
        return "Molto Basso"
