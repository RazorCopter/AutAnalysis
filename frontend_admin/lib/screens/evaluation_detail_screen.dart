// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/evaluation_model.dart';
import '../models/patient_model.dart';
import '../models/scale_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// ─── Entry point: naviga qui passando paziente e scala ───────────────────────
class EvaluationDetailScreen extends StatefulWidget {
  final PatientModel patient;
  final ScaleModel scale;

  const EvaluationDetailScreen({
    super.key,
    required this.patient,
    required this.scale,
  });

  @override
  State<EvaluationDetailScreen> createState() => _EvaluationDetailScreenState();
}

class _EvaluationDetailScreenState extends State<EvaluationDetailScreen> {
  final ApiService _api = ApiService();

  List<AggregatedEvaluation> _history = [];
  AggregatedEvaluation? _eval;
  PsychometricAnalysis? _analysis;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDownloading = false;
  bool _isLoadingAnalysis = false;

  // Teniamo una copia mutabile delle risposte per l'editing inline
  List<AnswerModel> _editableAnswers = [];

  static const List<Color> _domainColors = [
    Color(0xFF64B5F6), Color(0xFFFFB74D), Color(0xFF81C784), Color(0xFFCE93D8),
    Color(0xFFE57373), Color(0xFF4FC3F7), Color(0xFFAED581), Color(0xFFFF8A65),
  ];

  bool get _hasStandardProfile =>
      _analysis?.domini.any((domain) => domain.punteggioStandard != null) ?? false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final history = await _api.getAggregatedEvaluationHistory(
      widget.patient.id,
      widget.scale.id,
    );
    if (history.isNotEmpty && mounted) {
      setState(() {
        _history = history;
        _selectEvaluation(history.first);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessuna valutazione trovata per questo paziente e scala')),
        );
      }
    }
  }

  void _selectEvaluation(AggregatedEvaluation evaluation) {
    _eval = evaluation;
    _editableAnswers = evaluation.risposte
        .map((r) => AnswerModel(
              codiceDomanda: r.codiceDomanda,
              punteggio: r.punteggio,
              nota: r.nota,
            ))
        .toList();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    if (_eval == null) return;
    setState(() => _isLoadingAnalysis = true);
    final analysis = await _api.getEvaluationAnalysis(_eval!.idValutazione);
    if (mounted) {
      setState(() {
        _analysis = analysis;
        _isLoadingAnalysis = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_eval == null) return;
    setState(() => _isSaving = true);
    final updated = await _api.updateEvaluationAnswers(
      _eval!.idValutazione,
      _editableAnswers,
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _history.indexWhere((e) => e.idValutazione == updated.idValutazione);
        if (idx != -1) {
          _history[idx] = updated;
        }
        _selectEvaluation(updated);
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Modifiche salvate con successo'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel salvataggio')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_eval == null) return;
    setState(() => _isDownloading = true);
    final bytes = await _api.downloadEvaluationPdf(_eval!.idValutazione);
    setState(() => _isDownloading = false);
    if (bytes != null) {
      final b64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$b64';
      html.AnchorElement(href: dataUrl)
        ..setAttribute(
            'download', 'valutazione_${widget.patient.cognome}.pdf')
        ..click();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nella generazione del PDF')),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _eval == null
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  String _formatEvaluationDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.patient.nome} ${widget.patient.cognome}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            widget.scale.nome,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else
          TextButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Salva modifiche'),
          ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _isDownloading ? null : _downloadPdf,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(_isDownloading ? 'Generazione...' : 'Esporta PDF'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('Nessuna valutazione trovata',
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Torna indietro'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHistoryCard(),
              const SizedBox(height: 20),
              if (_hasStandardProfile) ...[
                _buildQvSummaryCard(),
                const SizedBox(height: 20),
              ],
              _buildMetaCard(),
              const SizedBox(height: 20),
              _buildClinicalCard(),
              const SizedBox(height: 20),
              _buildChartCard(),
              const SizedBox(height: 20),
              _buildDomainTable(),
              const SizedBox(height: 20),
              _buildAnswersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    final selectedId = _eval?.idValutazione;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storico Valutazioni',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _history.map((evaluation) {
                final isSelected = evaluation.idValutazione == selectedId;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text('Valutazione del ${_formatEvaluationDate(evaluation.dataCompilazione)}'),
                  onSelected: (_) {
                    setState(() => _selectEvaluation(evaluation));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Metadati paziente ─────────────────────────────────────────────────────
  Widget _buildMetaCard() {
    final e = _eval!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _metaItem('Paziente', '${widget.patient.nome} ${widget.patient.cognome}'),
            _metaItem('Scala', widget.scale.nome),
            _metaItem('Data', _formatEvaluationDate(e.dataCompilazione)),
            _metaItem('Anno', e.anno.toString()),
            _metaItem('Operatore', e.nomeOperatore),
            if (e.nomeIntervistato != null && e.nomeIntervistato!.isNotEmpty)
              _metaItem('Intervistato/a', e.nomeIntervistato!),
            _metaItem('ID', e.idValutazione.length > 8 ? '${e.idValutazione.substring(0, 8)}…' : e.idValutazione),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Pannello Clinico ────────────────────────────────────────────────────────
  Widget _buildClinicalCard() {
    final p = widget.patient;
    final noteLines = (p.note != null && p.note!.isNotEmpty)
        ? p.note!.split('\n').where((l) => l.trim().isNotEmpty).toList()
        : <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Quadro Clinico',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            if (p.altezza != null || p.peso != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    if (p.altezza != null)
                      _clinicalChip(Icons.height, 'Altezza', '${p.altezza} cm'),
                    if (p.peso != null)
                      _clinicalChip(Icons.monitor_weight_outlined, 'Peso', '${p.peso} kg'),
                  ],
                ),
              ),
            if (noteLines.isNotEmpty) ...[
              const Text('Note Cliniche',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              ...noteLines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        Expanded(
                          child: Text(line.trim(),
                              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4)),
                        ),
                      ],
                    ),
                  )),
            ],
            if (p.altezza == null && p.peso == null && noteLines.isEmpty)
              const Text('Nessun dato clinico aggiuntivo registrato.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _clinicalChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ─── Card Riepilogo QV ──────────────────────────────────────────────────────
  Widget _buildQvSummaryCard() {
    final a = _analysis!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
        child: Wrap(
          spacing: 28,
          runSpacing: 20,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _summaryMetric(
              title: 'Indice Qualità della Vita',
              value: a.indiceQv?.toString() ?? '—',
              hint: 'Scala normativa centrata su 100',
              color: Colors.white,
              large: true,
            ),
            _summaryMetric(
              title: 'Percentile',
              value: a.percentile != null ? '${a.percentile}°' : '—',
              hint: 'Posizionamento rispetto al campione',
              color: const Color(0xFFAED581),
              large: true,
            ),
            _summaryMetric(
              title: 'Somma Punteggi Standard',
              value: a.sommaPunteggiStandard?.toString() ?? '—',
              hint: 'Somma degli 8 domini',
              color: const Color(0xFF90CAF9),
            ),
            if (a.fasciaQv != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fascia interpretativa',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  _fasciaBadge(a.fasciaQv!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric({
    required String title,
    required String value,
    required String hint,
    required Color color,
    bool large = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 38 : 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  static const _fasciaColorMap = {
    'Molto Basso': Color(0xFFD32F2F),
    'Basso':       Color(0xFFF57C00),
    'Medio':       Color(0xFFFBC02D),
    'Alto':        Color(0xFF7CB342),
    'Molto Alto':  Color(0xFF388E3C),
  };

  Widget _fasciaBadge(String fascia) {
    final color = _fasciaColorMap[fascia] ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(fascia,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
  Widget _buildChartCard() {
    final hasAnalysis = _analysis != null && _analysis!.domini.isNotEmpty;
    final useRadar = hasAnalysis && _hasStandardProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              useRadar
                  ? 'Profilo della Qualità della Vita'
                  : 'Profilo Punteggi per Dominio',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              useRadar
                  ? 'Radar chart a 8 assi, scala 0–20, con media normativa fissata a 10'
                  : 'Fallback automatico per scale senza tabelle di conversione',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_isLoadingAnalysis)
              const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: useRadar ? 520 : 320,
                child: useRadar ? _buildRadarChart() : _buildBarChart(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Radar Chart (San Martín e scale con scoring_tables) ──────────────────
  Widget _buildRadarChart() {
    final domains = _analysis!.domini;
    final patientValues = domains
        .map((d) => ((d.punteggioStandard ?? 0).clamp(0, 20)).toDouble())
        .toList();
    final maxValues = List<double>.filled(domains.length, 20.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final chartSize =
            math.min(availableWidth - 80, 380.0).clamp(260.0, 380.0).toDouble();

        return Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      RadarChart(
                        RadarChartData(
                          radarShape: RadarShape.polygon,
                          tickCount: 4,
                          ticksTextStyle: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7B8794),
                          ),
                          tickBorderData: const BorderSide(color: Color(0xFFDDE7F8), width: 0.8),
                          gridBorderData: const BorderSide(color: Color(0xFFDDE7F8), width: 0.8),
                          radarBorderData: const BorderSide(color: Color(0xFF90A4AE), width: 1.2),
                          radarBackgroundColor: const Color(0xFFF8FBFF),
                          titlePositionPercentageOffset: 0,
                          titleTextStyle: const TextStyle(color: Colors.transparent),
                          getTitle: (index, _) => const RadarChartTitle(text: ''),
                          dataSets: [
                            RadarDataSet(
                              dataEntries: maxValues
                                  .map((value) => RadarEntry(value: value))
                                  .toList(),
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              fillColor: Colors.transparent,
                              entryRadius: 0,
                            ),
                            RadarDataSet(
                              dataEntries: patientValues
                                  .map((value) => RadarEntry(value: value))
                                  .toList(),
                              borderColor: const Color(0xFF1A237E),
                              borderWidth: 2.6,
                              fillColor: const Color(0xFF1A237E).withValues(alpha: 0.14),
                              entryRadius: 4.5,
                            ),
                          ],
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(chartSize, chartSize),
                          painter: _DashedRadarMeanPainter(
                            axisCount: domains.length,
                            color: const Color(0xFFD84343),
                            levelFraction: 0.5,
                          ),
                        ),
                      ),
                      ..._buildRadarAxisLabels(domains, chartSize),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _LegendItem(
                  color: Color(0xFF1A237E),
                  label: 'Profilo paziente',
                ),
                _LegendItem(
                  color: Color(0xFFD84343),
                  label: 'Media normativa (10)',
                  dashed: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildRadarAxisLabels(List<DomainAnalysis> domains, double chartSize) {
    final center = chartSize / 2;
    final labelRadius = (chartSize / 2) + 26;
    const labelWidth = 76.0;

    return List<Widget>.generate(domains.length, (index) {
      final angle = (-math.pi / 2) + (2 * math.pi * index / domains.length);
      final dx = center + (labelRadius * math.cos(angle));
      final dy = center + (labelRadius * math.sin(angle));

      return Positioned(
        left: dx - (labelWidth / 2),
        top: dy - 14,
        width: labelWidth,
        child: Text(
          domains[index].codice,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      );
    });
  }

  // ─── Istogramma Barre (fallback per scale senza scoring_tables) ────────────
  Widget _buildBarChart() {
    final hasAnalysis = _analysis != null && _analysis!.domini.isNotEmpty;
    final items = hasAnalysis ? _analysis!.domini : _eval!.domini;
    const maxY = 60.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              if (group.x < 0 || group.x >= items.length) return null;
              final item = items is List<DomainAnalysis>
                  ? items[group.x]
                  : (items as List<DomainScore>)[group.x];
              final label = item is DomainAnalysis ? item.etichetta : (item as DomainScore).etichetta;
              final suffix = ' pt';
              return BarTooltipItem(
                '$label\n${rod.toY.toInt()}$suffix',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= items.length) return const SizedBox();
                final name = items is List<DomainAnalysis>
                    ? (items as List<DomainAnalysis>)[idx].etichetta
                    : (items as List<DomainScore>)[idx].etichetta;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 70,
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 10,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: const Color(0xFFE8EEF8), strokeWidth: 1),
        ),
        barGroups: items.asMap().entries.map((e) {
          final color = _domainColors[e.key % _domainColors.length];
          final value = items is List<DomainAnalysis>
              ? (items as List<DomainAnalysis>)[e.key].punteggioDiretto
              : (items as List<DomainScore>)[e.key].punteggio;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: value.toDouble(),
                color: color,
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Tabella riepilogo domini ───────────────────────────────────────────────
  Widget _buildDomainTable() {
    if (_isLoadingAnalysis) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Riepilogo per Dominio',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            if (!_hasStandardProfile)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'La scala corrente non include tabelle di conversione: il punteggio standard non e disponibile.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  AppTheme.primaryColor.withValues(alpha: 0.08),
                ),
                columns: const [
                  DataColumn(label: Text('Acronimo')),
                  DataColumn(label: Text('Nome Esteso')),
                  DataColumn(label: Text('Punteggio Grezzo')),
                  DataColumn(label: Text('Punteggio Standard')),
                ],
                rows: _buildDomainRows(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildDomainRows() {
    if (_hasStandardProfile && _analysis != null) {
      return _analysis!.domini.asMap().entries.map((entry) {
        final index = entry.key;
        final domain = entry.value;
        final color = _domainColors[index % _domainColors.length];
        return DataRow(
          cells: [
            DataCell(_domainCodeChip(domain.codice, color)),
            DataCell(Text(domain.etichetta)),
            DataCell(Text(domain.punteggioDiretto.toString())),
            DataCell(
              Text(
                domain.punteggioStandard?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }).toList();
    }

    final domains = _eval?.domini ?? <DomainScore>[];
    return domains.asMap().entries.map((entry) {
      final index = entry.key;
      final domain = entry.value;
      final color = _domainColors[index % _domainColors.length];
      return DataRow(
        cells: [
          DataCell(_domainCodeChip(domain.codice, color)),
          DataCell(Text(domain.etichetta)),
          DataCell(Text(domain.punteggio.toString())),
          const DataCell(Text('—')),
        ],
      );
    }).toList();
  }

  Widget _domainCodeChip(String code, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  // ─── Lista risposte con editing inline ─────────────────────────────────────
  Widget _buildAnswersList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dettaglio Risposte',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('${_editableAnswers.length} domande',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _editableAnswers.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE8EEF8)),
              itemBuilder: (context, idx) => _buildAnswerRow(idx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow(int idx) {
    final answer = _editableAnswers[idx];
    final question = _findQuestion(answer.codiceDomanda);
    final availableScores = _getAvailableScores(answer.codiceDomanda);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          answer.codiceDomanda,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
      subtitle: question != null
          ? Text(
              question.testoDomanda,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary),
            )
          : null,
      title: Row(
        children: [
          ...availableScores.map((score) {
            final isSelected = answer.punteggio == score;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _editableAnswers[idx].punteggio = score),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFFDDE7F8),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      score.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          if (answer.nota != null && answer.nota!.isNotEmpty)
            const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textSecondary),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller:
                TextEditingController(text: answer.nota ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (answer.nota ?? '').length),
            onChanged: (val) => _editableAnswers[idx].nota = val,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Aggiungi una nota per questa risposta...',
              prefixIcon: const Icon(Icons.notes_outlined, size: 18),
              filled: true,
              fillColor: const Color(0xFFF3F8FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8EEF8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8EEF8)),
              ),
            ),
          ),
        ),
        if (question?.note != null && question!.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Nota item: ${question.note!}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Question? _findQuestion(String codiceDomanda) {
    for (final section in widget.scale.sezioni) {
      for (final question in section.domande) {
        if (question.codice == codiceDomanda) {
          return question;
        }
      }
    }
    return null;
  }

  List<int> _getAvailableScores(String codiceDomanda) {
    final question = _findQuestion(codiceDomanda);
    final scores = question?.opzioni.map((option) => option.punteggio).toSet().toList() ?? <int>[];
    scores.sort();
    return scores.isNotEmpty ? scores : <int>[1, 2, 3];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(24, 12),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LegendLinePainter({
    required this.color,
    required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final start = Offset(0, size.height / 2);
    final end = Offset(size.width, size.height / 2);

    if (dashed) {
      _DashedRadarMeanPainter.drawDashedSegment(
        canvas,
        start,
        end,
        paint,
      );
      return;
    }

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}

class _DashedRadarMeanPainter extends CustomPainter {
  final int axisCount;
  final Color color;
  final double levelFraction;

  const _DashedRadarMeanPainter({
    required this.axisCount,
    required this.color,
    required this.levelFraction,
  });

  static void drawDashedSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashLength = 7.0;
    const gapLength = 4.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;

    final direction = (end - start) / totalLength;
    double distance = 0;

    while (distance < totalLength) {
      final currentStart = start + (direction * distance);
      final currentEnd = start + (direction * math.min(distance + dashLength, totalLength));
      canvas.drawLine(currentStart, currentEnd, paint);
      distance += dashLength + gapLength;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (axisCount < 3) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) * 0.92 * levelFraction;
    final points = List<Offset>.generate(axisCount, (index) {
      final angle = (-math.pi / 2) + (2 * math.pi * index / axisCount);
      return Offset(
        center.dx + (radius * math.cos(angle)),
        center.dy + (radius * math.sin(angle)),
      );
    });

    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      drawDashedSegment(canvas, start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRadarMeanPainter oldDelegate) {
    return oldDelegate.axisCount != axisCount ||
        oldDelegate.color != color ||
        oldDelegate.levelFraction != levelFraction;
  }
}
