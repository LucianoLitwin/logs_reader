import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/custom_appbar.dart';
import 'analyze_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedFilePath;

  Future<void> _chooseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      setState(() {
        selectedFilePath = result.files.single.path;
      });
    }
  }

  void _clearFileSelection() {
    setState(() {
      selectedFilePath = null;
    });
  }

  void _analyzeFile(BuildContext context) {
    if (selectedFilePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalyzeScreen(filePath: selectedFilePath!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: 'Analizando Log',
        backEnabled:
            false, // Establece si el icono de retroceso debe ser visible
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido a la aplicación de procesamiento de logs',
              style: GoogleFonts.roboto(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta aplicación te permite procesar archivos de logs grandes de manera eficiente. Puedes cargar archivos y ver métricas útiles sobre el rendimiento del servidor.',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Please choose a file to upload',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _chooseFile,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedFilePath != null
                            ? selectedFilePath!.split('/').last
                            : 'Click to choose a .txt file',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (selectedFilePath != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        onPressed: _clearFileSelection,
                      ),
                    if (selectedFilePath == null)
                      const Icon(Icons.file_upload, color: Colors.white),
                  ],
                ),
              ),
            ),
            const Spacer(), // Esto empuja el botón hacia abajo
            Align(
              alignment: Alignment.bottomCenter, // Centra el botón
              child: ElevatedButton(
                onPressed: selectedFilePath != null
                    ? () => _analyzeFile(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(200, 60), // Aumenta el tamaño del botón
                  backgroundColor:
                      selectedFilePath != null ? Colors.blue : Colors.grey,
                ),
                child: Text(
                  'Analizar',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
