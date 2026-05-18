"""
analytics.py — Motore di calcolo psicometrico per scale cliniche.

Supporta sia scale con tabelle di conversione (San Martín) sia scale semplici (POS)
con semplice aggregazione per dominio.
"""

from typing import Any, Dict, List, Optional


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


def _get_domain_conversion_table(
    domain_code: str,
    num_domande: int,
    table_a: Dict[str, Any],
) -> Dict[str, dict]:
    """Seleziona la tabella di conversione corretta per il dominio corrente."""
    domini_12 = table_a.get("domini_con_12_item", {})
    dominio_11 = table_a.get("dominio_IS_con_11_item", {})

    conv_12 = domini_12.get("conversione", {})
    conv_11 = dominio_11.get("conversione", {})

    # San Martín ha 7 domini da 12 item e un dominio da 11 item.
    # Privilegiamo il numero di item effettivamente aggregati, con fallback sul codice.
    if num_domande == 11 and conv_11:
        return conv_11
    if domain_code.upper() == "IS" and conv_11:
        return conv_11
    return conv_12


def _build_domain_analyses(
    direct_scores: List[dict],
    table_a: Dict[str, Any],
) -> tuple[List[dict], Optional[int]]:
    """Converte i punteggi grezzi di dominio in punteggi standard."""
    domain_analyses: List[dict] = []
    total_standard = 0
    has_any_standard_score = False

    for domain in direct_scores:
        raw_score = domain["punteggio_totale"]
        domain_code = domain["codice"]
        num_domande = domain["num_domande"]

        conversion_table = _get_domain_conversion_table(
            domain_code=domain_code,
            num_domande=num_domande,
            table_a=table_a,
        )

        entry = conversion_table.get(str(raw_score), {})
        standard_score = entry.get("std")
        percentile = entry.get("perc")
        fascia = _std_to_fascia(standard_score) if standard_score is not None else None

        domain_analyses.append({
            "codice": domain_code,
            "etichetta": domain["etichetta"],
            "punteggio_diretto": raw_score,
            "punteggio_standard": standard_score,
            "percentile_dominio": percentile,
            "fascia": fascia,
            "num_domande": num_domande,
        })

        if standard_score is not None:
            total_standard += standard_score
            has_any_standard_score = True

    return domain_analyses, total_standard if has_any_standard_score else None


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
            "somma_punteggi_standard": int | None,
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
            "somma_punteggi_standard": None,
            "indice_qv": None,
            "percentile": None,
            "fascia_qv": None,
            "scala_nome": scale_doc.get("nome", ""),
        }

    table_a = scoring.get("tabella_A_conversione_punteggi_diretti_standard", {})
    table_b = scoring.get("tabella_B_indice_qdv", {})
    conv_qdv = table_b.get("conversione", {})
    domain_analyses, total_standard = _build_domain_analyses(
        direct_scores=direct_scores,
        table_a=table_a,
    )

    indice_qv = None
    percentile = None
    fascia_qv = None

    if conv_qdv and total_standard is not None:
        total_str = str(total_standard)
        if total_str in conv_qdv:
            entry = conv_qdv[total_str]
            indice_qv = entry.get("indice")
            percentile = entry.get("perc")
            fascia_qv = _indice_to_fascia(indice_qv)

    return {
        "domini": domain_analyses,
        "somma_punteggi_standard": total_standard,
        "indice_qv": indice_qv,
        "percentile": percentile,
        "fascia_qv": fascia_qv,
        "scala_nome": scale_doc.get("nome", ""),
    }


def _indice_to_fascia(indice: int) -> str:
    """Restituisce la fascia interpretativa per l'indice QdV (media=100, DS=15)."""
    if indice >= 130:
        return "Molto Alto"
    elif indice >= 116:
        return "Alto"
    elif indice >= 85:
        return "Medio"
    elif indice >= 70:
        return "Basso"
    else:
        return "Molto Basso"
