import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/custom_appbar.dart';

class AnalyzeScreen extends StatefulWidget {
  final String filePath;

  const AnalyzeScreen({super.key, required this.filePath});

  @override
  // ignore: library_private_types_in_public_api
  _AnalyzeScreenState createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  late File file;
  late int fileSize;
  double progress = 0.0;
  int linesRead = 0;
  int error500Count = 0;
  int slowRequestsCount = 0;
  late DateTime startTime;
  late DateTime endTime;
  double readSpeed = 0.0;

  Map<String, int> error500Urls = {};
  Map<String, int> slowRequestUrls = {};
  bool isAnalyzing = false;

  static const int batchSize = 1000;
  List<String> lineBatch = [];

  @override
  void initState() {
    super.initState();
    file = File(widget.filePath);
    fileSize = file.lengthSync();
  }

  Future<void> _processFile() async {
    if (isAnalyzing) return;

    setState(() {
      isAnalyzing = true;
      linesRead = 0;
      error500Count = 0;
      slowRequestsCount = 0;
      error500Urls.clear();
      slowRequestUrls.clear();
      progress = 0.0;
      readSpeed = 0.0;
    });

    startTime = DateTime.now();

    final lines = await _readFileLines();

    final chunkedLines = _chunkList(lines, batchSize);

    final results = await _processChunksInParallel(chunkedLines);

    // Combina los resultados
    for (var result in results) {
      error500Count += result['error500Count'] as int;
      slowRequestsCount += result['slowRequestsCount'] as int;

      (result['error500Urls'] as Map<String, int>).forEach((url, count) {
        error500Urls[url] = (error500Urls[url] ?? 0) + count;
      });

      (result['slowRequestUrls'] as Map<String, int>).forEach((url, count) {
        slowRequestUrls[url] = (slowRequestUrls[url] ?? 0) + count;
      });
    }

    endTime = DateTime.now();
    final elapsedTime = endTime.difference(startTime).inMilliseconds / 1000.0;

    setState(() {
      //linesRead = lines.length;
      isAnalyzing = false;
      progress = 1.0;
      readSpeed = elapsedTime > 0 ? fileSize / 1024 / elapsedTime : 0.0;
    });
  }

  Future<List<String>> _readFileLines() async {
    final lines = <String>[];
    final inputStream =
        file.openRead().transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in inputStream) {
      lines.add(line);
    }

    return lines;
  }

  List<List<String>> _chunkList(List<String> list, int chunkSize) {
    final chunks = <List<String>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(
          i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  Future<List<Map<String, dynamic>>> _processChunksInParallel(
      List<List<String>> chunks) async {
    final results = <Map<String, dynamic>>[];
    final chunkCount = chunks.length;

    for (int i = 0; i < chunkCount; i++) {
      final result = await _processChunkInIsolate(chunks[i]);
      results.add(result);

      // Actualizar el progreso y las líneas procesadas
      setState(() {
        linesRead += chunks[i].length;
        progress = linesRead / fileSize;
      });
    }

    return results;
  }

  static Future<Map<String, dynamic>> _processChunkInIsolate(
      List<String> chunk) async {
    final port = ReceivePort();
    await Isolate.spawn(_isolateEntryPoint, [chunk, port.sendPort]);

    return await port.first as Map<String, dynamic>;
  }

  static void _isolateEntryPoint(List<dynamic> args) {
    final chunk = args[0] as List<String>;
    final sendPort = args[1] as SendPort;

    final result = _processBatch(chunk);
    sendPort.send(result);
  }

  static Map<String, dynamic> _processBatch(List<String> batch) {
    int error500Count = 0;
    int slowRequestsCount = 0;
    final error500Urls = <String, int>{};
    final slowRequestUrls = <String, int>{};

    for (final line in batch) {
      if (line.contains('500')) {
        error500Count++;
        final url = _extractUrlFromLine(line);
        if (url.isNotEmpty) {
          error500Urls[url] = (error500Urls[url] ?? 0) + 1;
        }
      }

      final parts = line.split(' ');
      final responseTime = int.tryParse(parts.last);

      if (responseTime != null && responseTime > 200) {
        slowRequestsCount++;
        final url = _extractUrlFromLine(line);
        if (url.isNotEmpty) {
          slowRequestUrls[url] = (slowRequestUrls[url] ?? 0) + 1;
        }
      }
    }

    return {
      'error500Count': error500Count,
      'slowRequestsCount': slowRequestsCount,
      'error500Urls': error500Urls,
      'slowRequestUrls': slowRequestUrls,
    };
  }

  static String _extractUrlFromLine(String line) {
    final urlPattern = RegExp(r'(GET|POST)\s([^\s]+)');
    final match = urlPattern.firstMatch(line);
    return match?.group(2) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    // No se realizan cambios en el build
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: 'Analizando Log',
        backEnabled: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Procesando el archivo:',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.filePath.split('/').last,
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'Velocidad de lectura',
                    value: '${readSpeed.toStringAsFixed(2)} KB/s',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoCard(
                    title: 'Líneas procesadas',
                    value: '$linesRead',
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'Errores 500',
                    value: '$error500Count',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoCard(
                    title: 'Solicitudes lentas',
                    value: '$slowRequestsCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (error500Urls.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: _buildInfoCard(
                  title: 'URL con más Errores 500',
                  value: _getMaxUrlFromMap(error500Urls),
                  isFullWidth: true,
                ),
              ),
            if (slowRequestUrls.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: _buildInfoCard(
                  title: 'URL con más Solicitudes Lentas',
                  value: _getMaxUrlFromMap(slowRequestUrls),
                  isFullWidth: true,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _buildInfoCard(
                title: 'Tamaño del archivo',
                value: '${(fileSize / 1024).toStringAsFixed(2)} KB',
                isFullWidth: true,
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _processFile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 60),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  isAnalyzing ? 'Analizando...' : 'Iniciar análisis',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getMaxUrlFromMap(Map<String, int> urlMap) {
    String maxUrl = '';
    int maxCount = 0;

    urlMap.forEach((url, count) {
      if (count > maxCount) {
        maxUrl = url;
        maxCount = count;
      }
    });

    return '$maxUrl ($maxCount)';
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    bool isFullWidth = false,
  }) {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
