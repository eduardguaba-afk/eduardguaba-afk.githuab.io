import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pluto_grid/pluto_grid.dart';
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DisciplinaryDashboardApp());
}

class DisciplinaryDashboardApp extends StatelessWidget {
  const DisciplinaryDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF0A2540);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: darkBlue,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Panel de Gestión Disciplinaria – Junta Revisora',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 14),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5EAF0)),
          ),
        ),
      ),
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DisciplinaryCase {
  DisciplinaryCase({
    required this.expediente,
    required this.servidorPublico,
    required this.unidad,
    required this.fechaRevision,
    required this.mes,
    required this.tipoFalta,
    required this.medida,
    required this.fundamentoLegal,
    required this.observaciones,
    required this.provincia,
  });

  final String expediente;
  final String servidorPublico;
  final String unidad;
  final DateTime fechaRevision;
  final String mes;
  final String tipoFalta;
  final String medida;
  final String fundamentoLegal;
  final String observaciones;
  final String provincia;

  DisciplinaryCase copyWith({
    String? expediente,
    String? servidorPublico,
    String? unidad,
    DateTime? fechaRevision,
    String? mes,
    String? tipoFalta,
    String? medida,
    String? fundamentoLegal,
    String? observaciones,
    String? provincia,
  }) {
    return DisciplinaryCase(
      expediente: expediente ?? this.expediente,
      servidorPublico: servidorPublico ?? this.servidorPublico,
      unidad: unidad ?? this.unidad,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      mes: mes ?? this.mes,
      tipoFalta: tipoFalta ?? this.tipoFalta,
      medida: medida ?? this.medida,
      fundamentoLegal: fundamentoLegal ?? this.fundamentoLegal,
      observaciones: observaciones ?? this.observaciones,
      provincia: provincia ?? this.provincia,
    );
  }

  Map<String, dynamic> toMap() => {
        'Expediente': expediente,
        'Servidor Público': servidorPublico,
        'Unidad': unidad,
        'Fecha Revisión': DateFormat('yyyy-MM-dd').format(fechaRevision),
        'Mes': mes,
        'Tipo Falta': tipoFalta,
        'Medida': medida,
        'Fundamento Legal': fundamentoLegal,
        'Observaciones': observaciones,
        'Provincia': provincia,
      };

  static DisciplinaryCase fromMap(Map<String, dynamic> json) {
    final DateTime fecha = DateTime.tryParse(json['Fecha Revisión'] as String? ?? '') ?? DateTime.now();
    return DisciplinaryCase(
      expediente: json['Expediente'] as String? ?? '',
      servidorPublico: json['Servidor Público'] as String? ?? '',
      unidad: json['Unidad'] as String? ?? '',
      fechaRevision: fecha,
      mes: json['Mes'] as String? ?? DateFormat('MMMM', 'es').format(fecha),
      tipoFalta: json['Tipo Falta'] as String? ?? 'No especificado',
      medida: json['Medida'] as String? ?? 'Otros',
      fundamentoLegal: json['Fundamento Legal'] as String? ?? '',
      observaciones: json['Observaciones'] as String? ?? '',
      provincia: json['Provincia'] as String? ?? 'No definida',
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<DisciplinaryCase> _allCases = _seedData();

  DateTimeRange? _dateRange;
  String? _selectedProvincia;
  String? _selectedTipoFalta;
  String? _selectedMedida;

  // PlutoGrid state
  late final PlutoGridStateManager _gridManager;
  bool _gridReady = false;

  // Trend segmentation toggle
  String _trendSegment = 'Provincia'; // or 'Medida'

  static List<DisciplinaryCase> _seedData() {
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    final List<Map<String, String>> sample = [
      {
        'Expediente': 'EXP-001',
        'Servidor Público': 'Juan Pérez',
        'Unidad': 'Dirección Norte',
        'Fecha Revisión': '2025-08-01',
        'Mes': 'Agosto',
        'Tipo Falta': 'Grave',
        'Medida': 'Destitución',
        'Fundamento Legal': 'Art. 88 Ley 590-16',
        'Observaciones': 'Falta reiterada',
        'Provincia': 'Santiago',
      },
      {
        'Expediente': 'EXP-002',
        'Servidor Público': 'Ana Gómez',
        'Unidad': 'Comando Sur',
        'Fecha Revisión': '2025-09-03',
        'Mes': 'Septiembre',
        'Tipo Falta': 'Leve',
        'Medida': 'No medida',
        'Fundamento Legal': 'Art. 92 Ley 107-13',
        'Observaciones': 'Archivo por falta de pruebas',
        'Provincia': 'La Vega',
      },
    ];

    // Add synthetic data for variety
    final List<String> provincias = <String>['Santiago', 'La Vega', 'Distrito Nacional', 'Santo Domingo', 'San Cristóbal'];
    final List<String> unidades = <String>['Dirección Norte', 'Comando Sur', 'Unidad Central', 'Dirección Este'];
    final List<String> faltas = <String>['Leve', 'Grave', 'Muy grave'];
    final List<String> medidas = <String>['Destitución', 'Sanción', 'No medida', 'Otros'];
    final DateTime start = DateTime(2025, 1, 1);
    final math.Random rng = math.Random(42);
    for (int i = 3; i <= 60; i++) {
      final DateTime d = start.add(Duration(days: rng.nextInt(270)));
      final String mes = DateFormat('MMMM', 'es').format(d);
      sample.add({
        'Expediente': 'EXP-${i.toString().padLeft(3, '0')}',
        'Servidor Público': 'Servidor $i',
        'Unidad': unidades[rng.nextInt(unidades.length)],
        'Fecha Revisión': fmt.format(d),
        'Mes': mes[0].toUpperCase() + mes.substring(1),
        'Tipo Falta': faltas[rng.nextInt(faltas.length)],
        'Medida': medidas[rng.nextInt(medidas.length)],
        'Fundamento Legal': rng.nextBool() ? 'Art. 88 Ley 590-16' : 'Art. 92 Ley 107-13',
        'Observaciones': rng.nextBool() ? 'Observación $i' : '—',
        'Provincia': provincias[rng.nextInt(provincias.length)],
      });
    }
    return sample.map((m) => DisciplinaryCase.fromMap(m)).toList();
  }

  List<DisciplinaryCase> get _filteredCases {
    return _allCases.where((c) {
      if (_dateRange != null) {
        if (c.fechaRevision.isBefore(_dateRange!.start) || c.fechaRevision.isAfter(_dateRange!.end)) {
          return false;
        }
      }
      if (_selectedProvincia != null && _selectedProvincia!.isNotEmpty && c.provincia != _selectedProvincia) {
        return false;
      }
      if (_selectedTipoFalta != null && _selectedTipoFalta!.isNotEmpty && c.tipoFalta != _selectedTipoFalta) {
        return false;
      }
      if (_selectedMedida != null && _selectedMedida!.isNotEmpty && c.medida != _selectedMedida) {
        return false;
      }
      return true;
    }).toList();
  }

  // Provinces to approximate coordinates (Dominican Republic)
  static const Map<String, LatLng> _provinceCenters = <String, LatLng>{
    'Santiago': LatLng(19.4517, -70.6970),
    'La Vega': LatLng(19.2210, -70.5296),
    'Distrito Nacional': LatLng(18.4861, -69.9312),
    'Santo Domingo': LatLng(18.5100, -69.9000),
    'San Cristóbal': LatLng(18.4167, -70.1167),
  };

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Rango de fechas',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      currentDate: now,
      initialDateRange: _dateRange,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(secondary: Theme.of(context).colorScheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    setState(() => _dateRange = res);
  }

  void _resetFilters() {
    setState(() {
      _dateRange = null;
      _selectedProvincia = null;
      _selectedTipoFalta = null;
      _selectedMedida = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<DisciplinaryCase> cases = _filteredCases;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            SizedBox(
              width: 36,
              height: 36,
              child: Image.asset(
                'assets/logo.png',
                errorBuilder: (BuildContext context, Object error, StackTrace? st) {
                  return CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.shield, color: theme.colorScheme.primary),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Panel de Gestión Disciplinaria – Junta Revisora',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton.tonalIcon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              _dateRange == null
                  ? 'Rango de fechas'
                  : '${DateFormat('dd MMM yyyy', 'es').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy', 'es').format(_dateRange!.end)}',
            ),
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter<String>(
            hint: 'Provincia',
            value: _selectedProvincia,
            onChanged: (String? v) => setState(() => _selectedProvincia = v),
            items: _allCases.map((e) => e.provincia).toSet().toList()..sort(),
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter<String>(
            hint: 'Tipo de falta',
            value: _selectedTipoFalta,
            onChanged: (String? v) => setState(() => _selectedTipoFalta = v),
            items: _allCases.map((e) => e.tipoFalta).toSet().toList()..sort(),
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter<String>(
            hint: 'Medida',
            value: _selectedMedida,
            onChanged: (String? v) => setState(() => _selectedMedida = v),
            items: _allCases.map((e) => e.medida).toSet().toList()..sort(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Limpiar filtros',
            onPressed: _resetFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton.extended(
            heroTag: 'excel',
            onPressed: () => _exportExcel(cases),
            label: const Text('Excel'),
            icon: const Icon(Icons.grid_on),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'pdf',
            onPressed: () => _exportPdf(cases),
            label: const Text('PDF'),
            icon: const Icon(Icons.picture_as_pdf),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _showAddCaseDialog,
            label: const Text('Agregar caso'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildDashboard(cases),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String hint,
    required T? value,
    required ValueChanged<T?> onChanged,
    required List<T> items,
  }) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 220, height: 44),
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        items: <DropdownMenuItem<T>>[
          const DropdownMenuItem<T>(
            value: null,
            child: Text('Todos'),
          ),
          ...items.map((T e) => DropdownMenuItem<T>(value: e, child: Text('$e'))),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildDashboard(List<DisciplinaryCase> cases) {
    final EdgeInsets pad = const EdgeInsets.all(16);
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 1200;

    final Map<String, double> kpis = _computeKpis(cases);

    return SingleChildScrollView(
      key: ValueKey<int>(cases.length + (_dateRange?.hashCode ?? 0)),
      padding: pad,
      child: Column(
        children: <Widget>[
          // KPIs
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _kpiCard('Casos revisados', kpis['total']!.toInt().toString(), Icons.folder_open),
              _kpiCard('% Destituciones', '${kpis['pct_d']!.toStringAsFixed(1)}%', Icons.gavel),
              _kpiCard('% Sanciones', '${kpis['pct_s']!.toStringAsFixed(1)}%', Icons.rule),
              _kpiCard('% No medidas', '${kpis['pct_n']!.toStringAsFixed(1)}%', Icons.block),
              _kpiCard('% Otros', '${kpis['pct_o']!.toStringAsFixed(1)}%', Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 16),
          // Charts row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _chartCard(title: 'Distribución de medidas', width: isWide ? size.width * 0.32 : size.width - 32, child: _pieMedidas(cases)),
              _chartCard(title: 'Casos por unidad de adscripción', width: isWide ? size.width * 0.32 : size.width - 32, child: _barsUnidades(cases)),
              _chartCard(title: 'Medidas por tipo de falta (apilado)', width: isWide ? size.width * 0.32 : size.width - 32, child: _stackedMedidasPorFalta(cases)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _chartCard(
                title: 'Evolución mensual por ${_trendSegment.toLowerCase()}',
                width: isWide ? size.width * 0.48 : size.width - 32,
                trailing: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'Provincia', label: Text('Provincia')),
                    ButtonSegment<String>(value: 'Medida', label: Text('Medida')),
                  ],
                  selected: <String>{_trendSegment},
                  onSelectionChanged: (Set<String> s) => setState(() => _trendSegment = s.first),
                ),
                child: _trendMensual(cases),
              ),
              _chartCard(title: 'Distribución geográfica por provincia', width: isWide ? size.width * 0.48 : size.width - 32, child: _mapa(cases)),
            ],
          ),
          const SizedBox(height: 16),
          _dataTableCard(cases),
        ],
      ),
    );
  }

  Map<String, double> _computeKpis(List<DisciplinaryCase> cases) {
    final int total = cases.length;
    double pct(String medida) => total == 0 ? 0 : (cases.where((c) => c.medida == medida).length * 100.0) / total;
    return <String, double>{
      'total': total.toDouble(),
      'pct_d': pct('Destitución'),
      'pct_s': pct('Sanción'),
      'pct_n': pct('No medida'),
      'pct_o': pct('Otros'),
    };
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 250,
      height: 100,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.bodyMedium!.copyWith(color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Text(value, style: theme.textTheme.headlineMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required Widget child,
    double? width,
    Widget? trailing,
  }) {
    return SizedBox(
      width: width,
      height: 340,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pieMedidas(List<DisciplinaryCase> cases) {
    final Map<String, int> counts = cases.groupListsBy((c) => c.medida).mapValues((l) => l.length);
    final List<String> order = <String>['Destitución', 'Sanción', 'No medida', 'Otros'];
    final List<Color> colors = <Color>[
      const Color(0xFF1F77B4), // azul
      const Color(0xFF7F7F7F), // gris
      const Color(0xFF17BECF), // teal
      const Color(0xFFBCBD22), // oliva
    ];
    final int total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(child: Text('Sin datos'));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          for (int i = 0; i < order.length; i++)
            PieChartSectionData(
              color: colors[i],
              value: (counts[order[i]] ?? 0).toDouble(),
              title: '${((counts[order[i]] ?? 0) * 100 / total).toStringAsFixed(0)}%\n${order[i]}',
              radius: 90,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _barsUnidades(List<DisciplinaryCase> cases) {
    final Map<String, int> counts = cases.groupListsBy((c) => c.unidad).mapValues((l) => l.length);
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final int n = math.min(sorted.length, 6);
    final List<MapEntry<String, int>> top = sorted.take(n).toList();
    if (top.isEmpty) return const Center(child: Text('Sin datos'));
    final int maxVal = top.map((e) => e.value).fold<int>(0, math.max);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double v, TitleMeta m) {
                final int i = v.toInt();
                if (i < 0 || i >= top.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(top[i].key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: top[i].value.toDouble(),
                  width: 24,
                  color: const Color(0xFF0A2540),
                  borderRadius: BorderRadius.circular(8),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal.toDouble(),
                    color: const Color(0xFFE9EEF3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stackedMedidasPorFalta(List<DisciplinaryCase> cases) {
    final List<String> faltas = _allCases.map((e) => e.tipoFalta).toSet().toList()..sort();
    final List<String> medidas = <String>['Destitución', 'Sanción', 'No medida', 'Otros'];
    final Map<String, Map<String, int>> table = <String, Map<String, int>>{};
    for (final String falta in faltas) {
      table[falta] = <String, int>{ for (final String m in medidas) m: 0 };
    }
    for (final DisciplinaryCase c in cases) {
      table[c.tipoFalta]?[c.medida] = (table[c.tipoFalta]?[c.medida] ?? 0) + 1;
    }
    final int maxVal = table.values.expand((m) => m.values).fold<int>(0, math.max);
    if (maxVal == 0) return const Center(child: Text('Sin datos'));

    final List<Color> colors = <Color>[
      const Color(0xFF1F77B4),
      const Color(0xFF7F7F7F),
      const Color(0xFF17BECF),
      const Color(0xFFBCBD22),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double v, TitleMeta m) {
                final int i = v.toInt();
                if (i < 0 || i >= faltas.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(faltas[i], style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < faltas.length; i++)
            BarChartGroupData(
              x: i,
              groupVertically: true,
              barRods: [
                for (int j = 0; j < medidas.length; j++)
                  BarChartRodData(
                    toY: (table[faltas[i]]?[medidas[j]] ?? 0).toDouble(),
                    color: colors[j],
                    width: 26,
                    borderRadius: BorderRadius.circular(4),
                  ),
              ],
            ),
        ],
        barTouchData: BarTouchData(enabled: true),
      ),
    );
  }

  Widget _trendMensual(List<DisciplinaryCase> cases) {
    final List<String> meses = <String>[
      'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];

    final Map<String, Map<int, int>> series = <String, Map<int, int>>{}; // key -> monthIndex -> count
    if (_trendSegment == 'Provincia') {
      for (final String prov in _allCases.map((e) => e.provincia).toSet()) {
        series[prov] = <int, int>{};
      }
      for (final DisciplinaryCase c in cases) {
        final int m = c.fechaRevision.month - 1;
        series[c.provincia]![m] = (series[c.provincia]![m] ?? 0) + 1;
      }
    } else {
      final List<String> medidas = <String>['Destitución', 'Sanción', 'No medida', 'Otros'];
      for (final String m in medidas) {
        series[m] = <int, int>{};
      }
      for (final DisciplinaryCase c in cases) {
        final int m = c.fechaRevision.month - 1;
        series[c.medida]![m] = (series[c.medida]![m] ?? 0) + 1;
      }
    }

    final List<Color> palette = <Color>[
      const Color(0xFF1F77B4),
      const Color(0xFF7F7F7F),
      const Color(0xFF17BECF),
      const Color(0xFFBCBD22),
      const Color(0xFF9467BD),
      const Color(0xFFE377C2),
    ];

    final List<LineChartBarData> lines = <LineChartBarData>[];
    int colorIdx = 0;
    for (final MapEntry<String, Map<int, int>> entry in series.entries) {
      final List<FlSpot> pts = <FlSpot>[];
      for (int i = 0; i < 12; i++) {
        pts.add(FlSpot(i.toDouble(), (entry.value[i] ?? 0).toDouble()));
      }
      lines.add(
        LineChartBarData(
          spots: pts,
          isCurved: true,
          color: palette[colorIdx % palette.length],
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      );
      colorIdx++;
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (double v, TitleMeta m) {
                final int i = v.toInt();
                if (i < 0 || i >= meses.length) return const SizedBox.shrink();
                return Text(meses[i].substring(0, 3));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lines,
      ),
    );
  }

  Widget _mapa(List<DisciplinaryCase> cases) {
    final Map<String, int> counts = cases.groupListsBy((c) => c.provincia).mapValues((l) => l.length);
    final List<Marker> markers = <Marker>[];
    for (final MapEntry<String, int> e in counts.entries) {
      final LatLng? center = _provinceCenters[e.key];
      if (center == null) continue;
      final int count = e.value;
      final double size = (20 + math.log(count + 1) * 12).clamp(16, 40);
      markers.add(
        Marker(
          point: center,
          width: size,
          height: size,
          child: Tooltip(
            message: '${e.key}: $count',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A2540).withOpacity(0.85),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(18.9, -70.3),
          initialZoom: 7.0,
          interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const <String>['a', 'b', 'c'],
            userAgentPackageName: 'disciplinary_dashboard',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  Widget _dataTableCard(List<DisciplinaryCase> cases) {
    return SizedBox(
      height: 480,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text('Casos (editable)', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Refrescar tabla',
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildPlutoGrid(cases),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlutoGrid(List<DisciplinaryCase> cases) {
    final List<PlutoColumn> columns = <PlutoColumn>[
      PlutoColumn(title: 'Expediente', field: 'Expediente', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Servidor Público', field: 'Servidor Público', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Unidad', field: 'Unidad', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Fecha Revisión', field: 'Fecha Revisión', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Mes', field: 'Mes', type: PlutoColumnType.text(), readOnly: true),
      PlutoColumn(title: 'Tipo Falta', field: 'Tipo Falta', type: PlutoColumnType.select(<String>['Leve','Grave','Muy grave'])),
      PlutoColumn(title: 'Medida', field: 'Medida', type: PlutoColumnType.select(<String>['Destitución','Sanción','No medida','Otros'])),
      PlutoColumn(title: 'Fundamento Legal', field: 'Fundamento Legal', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Observaciones', field: 'Observaciones', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Provincia', field: 'Provincia', type: PlutoColumnType.text()),
    ];

    final List<PlutoRow> rows = <PlutoRow>[
      for (final DisciplinaryCase c in cases)
        PlutoRow(cells: {
          for (final MapEntry<String, dynamic> e in c.toMap().entries) e.key: PlutoCell(value: e.value),
        }),
    ];

    return PlutoGrid(
      columns: columns,
      rows: rows,
      onLoaded: (PlutoGridOnLoadedEvent e) {
        _gridManager = e.stateManager;
        _gridReady = true;
        _gridManager.setShowColumnFilter(true);
      },
      onChanged: (PlutoGridOnChangedEvent e) {
        if (!_gridReady) return;
        final int rowIdx = e.rowIdx;
        final PlutoRow row = _gridManager.refRows[rowIdx];
        final Map<String, dynamic> map = <String, dynamic>{
          for (final MapEntry<String, PlutoCell> cell in row.cells.entries) cell.key: cell.value.value,
        };
        final DisciplinaryCase updated = DisciplinaryCase.fromMap(map);
        final String exp = updated.expediente;
        final int idx = _allCases.indexWhere((c) => c.expediente == exp);
        if (idx != -1) {
          setState(() => _allCases[idx] = updated);
        }
      },
      configuration: PlutoGridConfiguration(
        style: PlutoGridStyleConfig(
          gridBorderColor: const Color(0xFFE5EAF0),
          activatedColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          activatedBorderColor: Theme.of(context).colorScheme.primary,
        ),
        columnFilter: PlutoGridColumnFilterConfig(),
      ),
    );
  }

  Future<void> _showAddCaseDialog() async {
    final GlobalKey<FormState> key = GlobalKey<FormState>();
    final TextEditingController expediente = TextEditingController();
    final TextEditingController servidor = TextEditingController();
    final TextEditingController unidad = TextEditingController();
    final TextEditingController fundamento = TextEditingController();
    final TextEditingController observaciones = TextEditingController();
    DateTime fecha = DateTime.now();
    String provincia = _selectedProvincia ?? 'Santiago';
    String tipoFalta = _selectedTipoFalta ?? 'Leve';
    String medida = _selectedMedida ?? 'Otros';

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Agregar caso'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(child: TextFormField(controller: expediente, decoration: const InputDecoration(labelText: 'Expediente'), validator: (v) => (v==null||v.isEmpty)?'Requerido':null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: servidor, decoration: const InputDecoration(labelText: 'Servidor Público'))),
                    ]),
                    Row(children: <Widget>[
                      Expanded(child: TextFormField(controller: unidad, decoration: const InputDecoration(labelText: 'Unidad'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialDate: fecha,
                            );
                            if (picked != null) {
                              fecha = picked;
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Fecha Revisión', border: OutlineInputBorder()),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(DateFormat('yyyy-MM-dd').format(fecha)),
                                const Icon(Icons.date_range),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                    Row(children: <Widget>[
                      Expanded(child: _smallDropdown<String>('Provincia', provincia, (v)=> provincia=v!, _allCases.map((e)=>e.provincia).toSet().toList()..sort())),
                      const SizedBox(width: 12),
                      Expanded(child: _smallDropdown<String>('Tipo Falta', tipoFalta, (v)=> tipoFalta=v!, <String>['Leve','Grave','Muy grave'])),
                    ]),
                    Row(children: <Widget>[
                      Expanded(child: _smallDropdown<String>('Medida', medida, (v)=> medida=v!, <String>['Destitución','Sanción','No medida','Otros'])),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: fundamento, decoration: const InputDecoration(labelText: 'Fundamento Legal'))),
                    ]),
                    TextFormField(controller: observaciones, decoration: const InputDecoration(labelText: 'Observaciones')),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                final String mes = DateFormat('MMMM', 'es').format(fecha);
                final DisciplinaryCase c = DisciplinaryCase(
                  expediente: expediente.text,
                  servidorPublico: servidor.text,
                  unidad: unidad.text,
                  fechaRevision: fecha,
                  mes: mes[0].toUpperCase()+mes.substring(1),
                  tipoFalta: tipoFalta,
                  medida: medida,
                  fundamentoLegal: fundamento.text,
                  observaciones: observaciones.text,
                  provincia: provincia,
                );
                setState(() => _allCases.add(c));
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _smallDropdown<T>(String label, T value, ValueChanged<T?> onChanged, List<T> items) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      items: items.map((T e)=> DropdownMenuItem<T>(value: e, child: Text('$e'))).toList(),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Future<void> _exportExcel(List<DisciplinaryCase> cases) async {
    final xl.Excel book = xl.Excel.createExcel();
    final xl.Sheet sheet = book['Casos'];
    final List<String> headers = <String>[
      'Expediente','Servidor Público','Unidad','Fecha Revisión','Mes','Tipo Falta','Medida','Fundamento Legal','Observaciones','Provincia'
    ];
    sheet.appendRow(headers);
    for (final DisciplinaryCase c in cases) {
      sheet.appendRow(headers.map((h) => c.toMap()[h]).toList());
    }
    final List<int>? bytes = book.save(fileName: 'panel_gestion.xlsx');
    if (bytes == null) return;
    final Uint8List data = Uint8List.fromList(bytes);
    await FileSaver.instance.saveFile(name: 'panel_gestion', ext: 'xlsx', bytes: data, mimeType: MimeType.microsoftExcel);
  }

  Future<void> _exportPdf(List<DisciplinaryCase> cases) async {
    final pw.Document doc = pw.Document();
    final List<String> headers = <String>[
      'Expediente','Servidor Público','Unidad','Fecha Revisión','Tipo Falta','Medida','Provincia'
    ];
    doc.addPage(
      pw.MultiPage(
        build: (pw.Context ctx) => <pw.Widget>[
          pw.Text('Panel de Gestión Disciplinaria – Junta Revisora', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: headers,
            data: <List<String>>[
              for (final DisciplinaryCase c in cases)
                <String>[
                  c.expediente,
                  c.servidorPublico,
                  c.unidad,
                  DateFormat('yyyy-MM-dd').format(c.fechaRevision),
                  c.tipoFalta,
                  c.medida,
                  c.provincia,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE9EEF3)),
            border: null,
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat f) async => doc.save());
  }
}

