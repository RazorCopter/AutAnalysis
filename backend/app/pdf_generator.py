"""
pdf_generator.py — Generazione PDF per valutazioni cliniche.

Supporta sia scale con scoring psicometrico (San Martín: radar chart, QoL, percentili)
sia scale semplici (POS: bar chart orizzontale).
"""
import io
from datetime import datetime, timezone
from typing import List, Dict, Optional

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib.colors import Color, HexColor, white, black
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image as RLImage, HRFlowable
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT

# ─── Palette colori tema ────────────────────────────────────────────────────
PRIMARY    = HexColor('#1A237E')
SECONDARY  = HexColor('#FFB74D')
ACCENT     = HexColor('#81C784')
DARK_TEXT  = HexColor('#2D3748')
LIGHT_GREY = HexColor('#F3F8FF')
MID_GREY   = HexColor('#718096')
BORDER     = HexColor('#E8EEF8')
RED_MEAN   = HexColor('#E57373')

DOMAIN_COLORS = [
    '#1A237E', '#E53935', '#43A047', '#FB8C00',
    '#8E24AA', '#00ACC1', '#3949AB', '#F4511E',
]

FASCIA_COLORS = {
    "Molto Basso": '#D32F2F',
    "Basso":       '#F57C00',
    "Medio":       '#FBC02D',
    "Alto":        '#7CB342',
    "Molto Alto":  '#388E3C',
}


def _wrap_label(text: str, max_chars: int = 16) -> str:
    if len(text) <= max_chars:
        return text
    if ' ' in text:
        mid = len(text) // 2
        best = mid
        for i, ch in enumerate(text):
            if ch == ' ':
                if abs(i - mid) < abs(best - mid):
                    best = i
        return text[:best] + '\n' + text[best + 1:]
    mid = len(text) // 2
    return text[:mid] + '\n' + text[mid:]


# ─── Grafico radar per San Martín ───────────────────────────────────────────

def _make_radar_chart(
    domains: List[dict],
    score_min: int = 0,
    score_max: int = 20,
    mean_ref: int = 10,
) -> io.BytesIO:
    """
    Crea un grafico radar (tela di ragno) a 8 assi con:
    - Profilo paziente (blu navy pieno + fill)
    - Linea media normativa (rossa tratteggiata)
    - Anelli concentrici con etichette
    """
    labels = [d["codice"] for d in domains]
    patient_values = [d.get("punteggio_standard") or 0 for d in domains]
    mean_values = [mean_ref] * len(labels)
    n = len(labels)

    angles = np.linspace(0, 2 * np.pi, n, endpoint=False).tolist()
    angles += angles[:1]

    patient_vals = patient_values + patient_values[:1]
    mean_vals = mean_values + mean_values[:1]

    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True), dpi=150)
    fig.patch.set_facecolor('#F8FBFF')
    ax.set_facecolor('#F8FBFF')

    ax.set_theta_offset(np.pi / 2)
    ax.set_theta_direction(-1)

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels, fontsize=12, fontweight='bold', color='#2D3748')

    ax.set_ylim(score_min, score_max)
    ax.set_yticks([0, 4, 8, 12, 16, 20])
    ax.set_yticklabels(['0', '4', '8', '12', '16', '20'],
                        fontsize=8, color='#9E9E9E')
    ax.yaxis.grid(True, color='#DDE7F8', linewidth=0.8)
    ax.xaxis.grid(True, color='#DDE7F8', linewidth=0.8)
    ax.spines['polar'].set_color('#90A4AE')
    ax.spines['polar'].set_linewidth(1.2)

    ax.fill(angles, patient_vals, color='#1A237E', alpha=0.10)
    ax.plot(angles, patient_vals, 'o-', linewidth=2.5, markersize=7,
            color='#1A237E', markerfacecolor='white', markeredgewidth=2,
            markeredgecolor='#1A237E', label='Paziente', zorder=5)

    ax.plot(angles, mean_vals, '--', linewidth=1.8, color='#E57373',
            label=f'Media ({mean_ref})', alpha=0.8)

    ax.legend(loc='upper right', bbox_to_anchor=(1.25, 1.12),
              fontsize=9, framealpha=0.9, edgecolor='#E8EEF8')

    ax.set_title('Profilo Punteggi Standard', fontsize=14,
                 fontweight='bold', color='#2D3748', pad=24)

    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', facecolor='#F8FBFF', dpi=150)
    plt.close(fig)
    buf.seek(0)
    return buf


# ─── Grafico a barre (fallback POS) ─────────────────────────────────────────

def _make_bar_chart(domains: List[dict], score_min: int = 6, score_max: int = 18) -> io.BytesIO:
    labels = [_wrap_label(d['etichetta']) for d in domains]
    scores = [d["punteggio_totale"] for d in domains]
    n = len(labels)
    colors = DOMAIN_COLORS[:n]

    fig, ax = plt.subplots(figsize=(10, max(3.5, n * 0.6 + 1.2)), dpi=140)
    fig.patch.set_facecolor('#F8FBFF')
    ax.set_facecolor('#F8FBFF')

    y = np.arange(n)
    bars = ax.barh(y, scores, color=colors, height=0.6, zorder=3)

    ax.axvline(score_min, color='#E57373', linewidth=1.2, linestyle='--',
               alpha=0.7, label=f'Min ({score_min})')
    ax.axvline(score_max, color='#81C784', linewidth=1.2, linestyle='--',
               alpha=0.7, label=f'Max ({score_max})')

    for bar, score in zip(bars, scores):
        ax.text(bar.get_width() + 0.2, bar.get_y() + bar.get_height() / 2,
                str(score), va='center', ha='left', fontsize=10,
                fontweight='bold', color='#2D3748')

    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=10, color='#2D3748')
    ax.set_xlabel('Punteggio', fontsize=10, color='#718096')
    ax.set_xlim(0, score_max * 1.18)
    ax.invert_yaxis()
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#E8EEF8')
    ax.spines['bottom'].set_color('#E8EEF8')
    ax.grid(axis='x', color='#E8EEF8', linestyle='--', linewidth=0.8)
    ax.legend(loc='lower right', fontsize=9)
    ax.set_title('Istogramma Comparato dei Punteggi per Dominio', fontsize=13,
                 fontweight='bold', color='#2D3748', pad=12)

    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', facecolor='#F8FBFF')
    plt.close(fig)
    buf.seek(0)
    return buf


# ─── Helper tabelle ─────────────────────────────────────────────────────────

def _make_table(headers: list, rows: list, col_widths: list,
                header_color, style_extras: list = None) -> Table:
    data = [headers] + rows
    t = Table(data, colWidths=col_widths)
    base_style = [
        ('FONTNAME',     (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE',     (0, 0), (-1, -1), 9),
        ('BACKGROUND',   (0, 0), (-1, 0), header_color),
        ('TEXTCOLOR',    (0, 0), (-1, 0), white),
        ('VALIGN',       (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [LIGHT_GREY, white]),
        ('GRID',         (0, 0), (-1, -1), 0.3, BORDER),
        ('TOPPADDING',   (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING',  (0, 0), (-1, -1), 6),
    ]
    if style_extras:
        base_style.extend(style_extras)
    t.setStyle(TableStyle(base_style))
    return t


# ─── Generazione PDF completo ────────────────────────────────────────────────

def generate_evaluation_pdf(
    evaluation: dict,
    patient: dict,
    scale: dict,
    domains: List[dict],
    analysis: Optional[dict] = None,
) -> bytes:
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )

    styles = getSampleStyleSheet()
    story = []

    # ── Stili personalizzati ────────────────────────────────────────────────
    title_style = ParagraphStyle(
        'CustomTitle', parent=styles['Title'],
        fontSize=22, textColor=DARK_TEXT, spaceAfter=4, fontName='Helvetica-Bold',
    )
    subtitle_style = ParagraphStyle(
        'Subtitle', parent=styles['Normal'],
        fontSize=12, textColor=MID_GREY, spaceAfter=16, fontName='Helvetica',
    )
    section_header = ParagraphStyle(
        'SectionHeader', parent=styles['Normal'],
        fontSize=12, textColor=DARK_TEXT, fontName='Helvetica-Bold',
        spaceBefore=20, spaceAfter=8,
    )

    has_analysis = analysis is not None and analysis.get("indice_qv") is not None
    scala_nome = scale.get("nome", "")
    is_sanmartin = has_analysis and "San Martín" in scala_nome

    # ── Header ─────────────────────────────────────────────────────────────
    story.append(Paragraph("AutAnalysis", title_style))
    story.append(Paragraph("Report di Valutazione Clinica", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER, spaceAfter=14))

    # ── Info scala ─────────────────────────────────────────────────────────
    if is_sanmartin:
        scale_meta = []
        if scale.get("autori"):
            scale_meta.append(f"Autori: {scale['autori']}")
        if scale.get("anno"):
            scale_meta.append(f"Anno: {scale['anno']}")
        if scale.get("editore"):
            scale_meta.append(f"Editore: {scale['editore']}")
        if scale_meta:
            story.append(Paragraph("Scala San Martín", section_header))
            for line in scale_meta:
                story.append(Paragraph(line, ParagraphStyle(
                    'ScaleMeta', parent=styles['Normal'],
                    fontSize=8, textColor=MID_GREY, fontName='Helvetica',
                    spaceAfter=1,
                )))
            story.append(Spacer(1, 0.3 * cm))

    # ── Info paziente / valutazione ─────────────────────────────────────────
    nome_paziente = f"{patient.get('nome', '')} {patient.get('cognome', '')}"
    data_str = evaluation.get("data_compilazione", datetime.now(timezone.utc))
    if isinstance(data_str, datetime):
        data_str = data_str.strftime("%d/%m/%Y")
    else:
        try:
            data_str = datetime.fromisoformat(str(data_str)).strftime("%d/%m/%Y")
        except Exception:
            data_str = str(data_str)[:10]

    meta_data = [
        ["Paziente:", nome_paziente, "Data:", data_str],
        ["Scala:", scala_nome, "Operatore:", evaluation.get("nome_operatore", "-")],
        ["Intervistato/a:", evaluation.get("nome_intervistato", "-"),
         "Anno:", str(evaluation.get("anno", "-"))],
        ["ID Valutazione:", evaluation.get("id_valutazione", "-")[:8] + "…", "", ""],
    ]

    # Aggiungi dati clinici se disponibili
    note_lines = []
    if patient.get("altezza") or patient.get("peso"):
        clinica = []
        if patient.get("altezza"):
            clinica.append(f"Altezza: {patient['altezza']} cm")
        if patient.get("peso"):
            clinica.append(f"Peso: {patient['peso']} kg")
        meta_data.append(["Dati clinici:", " · ".join(clinica), "", ""])

    if patient.get("note"):
        raw_note = str(patient["note"])
        note_lines = [l.strip() for l in raw_note.split('\n') if l.strip()]
        meta_data.append(["Note:", note_lines[0][:60] + ("…" if len(note_lines[0]) > 60 else ""), "", ""])

    meta_table = Table(meta_data, colWidths=[2.8*cm, 7*cm, 2.8*cm, 7*cm])
    meta_table.setStyle(TableStyle([
        ('FONTNAME',    (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE',    (0, 0), (-1, -1), 9),
        ('FONTNAME',    (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME',    (2, 0), (2, -1), 'Helvetica-Bold'),
        ('TEXTCOLOR',   (0, 0), (0, -1), DARK_TEXT),
        ('TEXTCOLOR',   (2, 0), (2, -1), DARK_TEXT),
        ('TEXTCOLOR',   (1, 0), (1, -1), MID_GREY),
        ('TEXTCOLOR',   (3, 0), (3, -1), MID_GREY),
        ('VALIGN',      (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 0), (-1, -1), [LIGHT_GREY, white]),
        ('TOPPADDING',  (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 0.4 * cm))

    # ── Riepilogo QV (solo San Martín) ───────────────────────────────────────
    if has_analysis:
        ind_qv = analysis.get("indice_qv")
        perc = analysis.get("percentile")
        fascia_qv = analysis.get("fascia_qv", "")
        fascia_color = FASCIA_COLORS.get(fascia_qv, '#2D3748')

        qv_data = [
            [Paragraph("Indice di Qualità della Vita",
                       ParagraphStyle('QvLabel', parent=styles['Normal'],
                                      fontSize=11, textColor=white, fontName='Helvetica-Bold')),
             Paragraph(f"{ind_qv} / 132",
                       ParagraphStyle('QvValue', parent=styles['Normal'],
                                      fontSize=24, textColor=white, fontName='Helvetica-Bold')),
             Paragraph("Percentile",
                       ParagraphStyle('QvLabel', parent=styles['Normal'],
                                      fontSize=11, textColor=white, fontName='Helvetica-Bold')),
             Paragraph(f"{perc}°",
                       ParagraphStyle('QvValue', parent=styles['Normal'],
                                      fontSize=24, textColor=HexColor('#AED581'), fontName='Helvetica-Bold')),
             ],
            [Paragraph(f"Fascia: {fascia_qv}",
                       ParagraphStyle('Fascia', parent=styles['Normal'],
                                      fontSize=13, textColor=HexColor(fascia_color),
                                      fontName='Helvetica-Bold')),
             "", "", ""],
        ]
        qv_table = Table(qv_data, colWidths=[5*cm, 3.5*cm, 3*cm, 3*cm])
        qv_table.setStyle(TableStyle([
            ('BACKGROUND',   (0, 0), (-1, -1), PRIMARY),
            ('VALIGN',       (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING',  (0, 0), (-1, -1), 12),
            ('RIGHTPADDING', (0, 0), (-1, -1), 12),
            ('TOPPADDING',   (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING',(0, 0), (-1, -1), 10),
            ('SPAN',         (1, 1), (-1, 1)),
            ('ROUNDEDCORNERS', [8]),
        ]))
        story.append(qv_table)
        story.append(Spacer(1, 0.5 * cm))

    # ── Grafico ─────────────────────────────────────────────────────────────
    story.append(Paragraph("Profilo dei Punteggi", section_header))

    if has_analysis:
        chart_domains = analysis.get("domini", [])
        chart_buf = _make_radar_chart(chart_domains)
        chart_img = RLImage(chart_buf, width=14 * cm, height=14 * cm)
    else:
        chart_buf = _make_bar_chart(domains)
        chart_img = RLImage(chart_buf, width=17 * cm, height=6.5 * cm)

    story.append(chart_img)
    story.append(Spacer(1, 0.4 * cm))

    # ── Legenda fasce ───────────────────────────────────────────────────────
    if has_analysis:
        story.append(Paragraph("Fasce Interpretative (Punteggi Standard)",
                               ParagraphStyle('LegendTitle', parent=styles['Normal'],
                                              fontSize=9, textColor=MID_GREY,
                                              fontName='Helvetica-Bold', spaceAfter=4)))
        fasce_data = [[
            Paragraph("Molto Basso<br/>1–4",
                      ParagraphStyle('FB', parent=styles['Normal'], fontSize=7,
                                     textColor=HexColor('#D32F2F'), fontName='Helvetica-Bold',
                                     alignment=TA_CENTER, leading=9)),
            Paragraph("Basso<br/>5–7",
                      ParagraphStyle('FB', parent=styles['Normal'], fontSize=7,
                                     textColor=HexColor('#F57C00'), fontName='Helvetica-Bold',
                                     alignment=TA_CENTER, leading=9)),
            Paragraph("Medio<br/>8–12",
                      ParagraphStyle('FB', parent=styles['Normal'], fontSize=7,
                                     textColor=HexColor('#FBC02D'), fontName='Helvetica-Bold',
                                     alignment=TA_CENTER, leading=9)),
            Paragraph("Alto<br/>13–15",
                      ParagraphStyle('FB', parent=styles['Normal'], fontSize=7,
                                     textColor=HexColor('#7CB342'), fontName='Helvetica-Bold',
                                     alignment=TA_CENTER, leading=9)),
            Paragraph("Molto Alto<br/>16–20",
                      ParagraphStyle('FB', parent=styles['Normal'], fontSize=7,
                                     textColor=HexColor('#388E3C'), fontName='Helvetica-Bold',
                                     alignment=TA_CENTER, leading=9)),
        ]]
        legend_table = Table(fasce_data, colWidths=[3.2*cm]*5)
        legend_table.setStyle(TableStyle([
            ('VALIGN',       (0, 0), (-1, -1), 'MIDDLE'),
            ('ALIGN',        (0, 0), (-1, -1), 'CENTER'),
            ('BACKGROUND',   (0, 0), (-1, -1), LIGHT_GREY),
            ('TOPPADDING',   (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING',(0, 0), (-1, -1), 4),
            ('ROUNDEDCORNERS', [6]),
        ]))
        story.append(legend_table)
        story.append(Spacer(1, 0.5 * cm))

    # ── Tabella riepilogo domìni ─────────────────────────────────────────────
    story.append(Paragraph("Riepilogo per Dominio", section_header))

    if has_analysis:
        domain_headers = ["Cod.", "Dominio", "Punteggio\nDiretto",
                          "Punteggio\nStandard", "Percentile", "Fascia"]
        domain_rows = [
            [d["codice"], d["etichetta"],
             str(d["punteggio_diretto"]),
             str(d["punteggio_standard"]) if d["punteggio_standard"] is not None else "—",
             f"{d['percentile_dominio']}°" if d.get("percentile_dominio") is not None else "—",
             Paragraph(d.get("fascia") or "—",
                       ParagraphStyle('FasciaCell', parent=styles['Normal'],
                                      fontSize=8, textColor=HexColor(FASCIA_COLORS.get(d.get("fascia"), '#2D3748')),
                                      fontName='Helvetica-Bold', alignment=TA_CENTER))]
            for d in analysis.get("domini", [])
        ]
        col_widths = [1.2*cm, 3.5*cm, 2.2*cm, 2.2*cm, 2*cm, 2.5*cm]
        style_extras = [
            ('ALIGN', (2, 0), (4, -1), 'CENTER'),
        ]
    else:
        domain_headers = ["Cod.", "Dominio", "Punteggio Totale", "N° Domande"]
        domain_rows = [
            [d["codice"], d["etichetta"], str(d["punteggio_totale"]), str(d["num_domande"])]
            for d in domains
        ]
        col_widths = [1.5*cm, 7*cm, 4*cm, 3*cm]
        style_extras = [
            ('ALIGN', (2, 0), (3, -1), 'CENTER'),
        ]

    domain_table = _make_table(
        domain_headers, domain_rows, col_widths, PRIMARY, style_extras
    )
    story.append(domain_table)
    story.append(Spacer(1, 0.5 * cm))

    # ── Tabella dettaglio risposte ───────────────────────────────────────────
    story.append(Paragraph("Dettaglio Risposte", section_header))

    resp_headers = ["Codice", "Punteggio", "Nota"]
    resp_rows = [
        [
            r.get("codice_domanda", "-"),
            str(r.get("punteggio", "-")),
            r.get("nota") or "",
        ]
        for r in evaluation.get("risposte", [])
    ]
    resp_table = _make_table(
        resp_headers, resp_rows, [2.5*cm, 2.5*cm, 14.5*cm], SECONDARY,
        [('ALIGN', (1, 0), (1, -1), 'CENTER'),
         ('WORDWRAP', (2, 0), (2, -1), True)]
    )
    story.append(resp_table)

    # ── Footer ──────────────────────────────────────────────────────────────
    story.append(Spacer(1, 0.8 * cm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER))
    story.append(Paragraph(
        f"Generato da AutAnalysis il {datetime.now(timezone.utc).strftime('%d/%m/%Y %H:%M')} UTC",
        ParagraphStyle('Footer', parent=styles['Normal'], fontSize=8,
                       textColor=MID_GREY, fontName='Helvetica', alignment=TA_RIGHT)
    ))

    doc.build(story)
    return buf.getvalue()
