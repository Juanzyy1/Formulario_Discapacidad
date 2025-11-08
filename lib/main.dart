import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formulario Accesible',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AccessibleFormScreen(),
    );
  }
}

class AccessibleFormScreen extends StatefulWidget {
  @override
  _AccessibleFormScreenState createState() => _AccessibleFormScreenState();
}

class _AccessibleFormScreenState extends State<AccessibleFormScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isListeningForCommand = false;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  TextEditingController _nombreController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _telefonoController = TextEditingController();
  TextEditingController _mensajeController = TextEditingController();

  String _selectedOption = 'Opción 1';
  bool _aceptoTerminos = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  _initSpeech() async {
    try {
      var available = await _speech.initialize(
        onError: (errorNotification) {
          print('Error: $errorNotification');
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          print('Status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        print("Speech recognition initialized");
      } else {
        print("Speech recognition not available");
      }
    } catch (e) {
      print("Error initializing speech: $e");
    }
  }

  // Escuchar comandos globales (ej. "enviar formulario") para enviar el formulario
  Future<void> _startListeningForSubmit() async {
    // Si se está reproduciendo TTS no iniciar
    if (_isSpeaking) return;

    // Si ya está en modo comando, detenerlo
    if (_isListeningForCommand) {
      setState(() => _isListeningForCommand = false);
      await _speech.stop();
      return;
    }

    // Detener cualquier escucha de campo activa para evitar colisiones
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    // Inicializar (si necesario) y escuchar
    var available = await _speech.initialize(
      onStatus: (status) {
        print('Command status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListeningForCommand = false);
        }
      },
      onError: (error) {
        print('Command error: $error');
        setState(() => _isListeningForCommand = false);
      },
    );

    if (!available) return;

    setState(() => _isListeningForCommand = true);

    await _speech.listen(
      onResult: (result) async {
        String recognized = result.recognizedWords;
        String low = recognized.toLowerCase();
        print('Command heard: $low');

        // Frases que activan el envío
        if (low.contains('enviar formulario') ||
            low.contains('enviar') ||
            low.contains('envía') ||
            low.contains('envia')) {
          // Confirmación por voz y enviar
          await _speech.stop();
          setState(() {
            _isListeningForCommand = false;
            _isListening = false;
          });
          _speak('Enviando formulario');
          _submitForm();
        }
      },
      localeId: 'es_ES',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: true,
    );
  }

  _initTts() async {
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);

    // Configurar el callback para cuando termine de hablar
    flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  _speak(String text) async {
    if (text.isNotEmpty) {
      setState(() => _isSpeaking = true);
      // Detener cualquier entrada de voz activa
      if (_isListening) {
        _speech.stop();
        setState(() => _isListening = false);
      }
      // Asegurarse de que cualquier instancia previa de TTS se detenga
      await flutterTts.stop();
      // Hablar el nuevo texto
      await flutterTts.speak(text);
      // El estado _isSpeaking se actualizará automáticamente cuando termine
      // gracias al setCompletionHandler configurado en _initTts
    }
  }

  // Función para leer la descripción de un campo
  _readFieldDescription(String fieldName, String description) {
    _speak("Campo $fieldName. $description");
  }

  // Normaliza texto reconocido por voz para formatear correos electrónicos
  String _normalizeEmailFromSpeech(String input) {
    if (input.trim().isEmpty) return input;

    String s = input.toLowerCase();

    // Reemplazar signos de puntuación problemáticos (coma, punto y coma) por espacio
    s = s.replaceAll(RegExp(r"[\,;]"), ' ');

    // Reemplazos de tokens hablados por símbolos
    s = s.replaceAll(RegExp(r"\barroba\b"), '@');
    s = s.replaceAll(RegExp(r"\bat\b"), '@');
    s = s.replaceAll(RegExp(r"\bpunto\b"), '.');
    s = s.replaceAll(RegExp(r"\bdot\b"), '.');
    s = s.replaceAll(RegExp(r"\bguion\b"), '-');
    s = s.replaceAll(RegExp(r"\bguión\b"), '-');

    // Normalizar espacios alrededor de @ y . (por si quedaron separados)
    s = s.replaceAll(RegExp(r"\s*@\s*"), '@');
    s = s.replaceAll(RegExp(r"\s*\.\s*"), '.');

    // Eliminar espacios remanentes
    s = s.replaceAll(RegExp(r"\s+"), '');

    return s;
  }

  _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (!_aceptoTerminos) {
        _speak("Debe aceptar los términos y condiciones");
        return;
      }

      _speak("Formulario enviado correctamente. Gracias por registrarse");
      // Aquí procesarías el formulario
    } else {
      _speak("Por favor, corrija los errores en el formulario");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FORMULARIO ACCESIBLE'),
        actions: [
          IconButton(
            icon: Icon(Icons.volume_up),
            onPressed:
                () => _speak(
                  "Formulario de registro. Complete todos los campos marcados como requeridos",
                ),
            tooltip: 'Leer instrucciones',
          ),
          // Botón para activar modo escucha de comando (enviar formulario)
          IconButton(
            icon: Icon(_isListeningForCommand ? Icons.mic : Icons.mic_none),
            onPressed: () => _startListeningForSubmit(),
            tooltip:
                _isListeningForCommand
                    ? 'Detener escucha de comando'
                    : 'Escuchar comando ("enviar")',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título con botón de lectura
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Complete el formulario:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.record_voice_over),
                    onPressed:
                        () => _speak(
                          "Formulario de registro. Complete todos los campos marcados con asterisco",
                        ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Campo Nombre
              _buildTextFieldWithSpeech(
                controller: _nombreController,
                label: 'Nombre completo *',
                hint: 'Ingrese su nombre completo',
                fieldName: 'Nombre completo',
                description: 'Requerido. Escriba su nombre y apellido',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su nombre';
                  }
                  return null;
                },
              ),

              SizedBox(height: 15),

              // Campo Email
              _buildTextFieldWithSpeech(
                controller: _emailController,
                label: 'Correo electrónico *',
                hint: 'ejemplo@correo.com',
                fieldName: 'Correo electrónico',
                description: 'Requerido. Ingrese un email válido',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su email';
                  }
                  if (!value.contains('@')) {
                    return 'Ingrese un email válido';
                  }
                  return null;
                },
              ),

              SizedBox(height: 15),

              // Campo Teléfono
              _buildTextFieldWithSpeech(
                controller: _telefonoController,
                label: 'Teléfono',
                hint: '+57 300 123 4567',
                fieldName: 'Teléfono',
                description: 'Opcional. Ingrese su número de contacto',
                keyboardType: TextInputType.phone,
              ),

              SizedBox(height: 15),

              // Dropdown con lectura
              _buildDropdownWithSpeech(),

              SizedBox(height: 15),

              // Campo Mensaje
              _buildTextFieldWithSpeech(
                controller: _mensajeController,
                label: 'Mensaje o comentarios',
                hint: 'Escriba su mensaje aquí...',
                fieldName: 'Mensaje',
                description: 'Opcional. Escriba cualquier comentario adicional',
                maxLines: 4,
              ),

              SizedBox(height: 20),

              // Checkbox términos
              _buildCheckboxWithSpeech(),

              SizedBox(height: 30),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: Icon(Icons.send),
                      label: Text('ENVIAR FORMULARIO'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.volume_up),
                    onPressed:
                        () => _speak(
                          "Botón enviar formulario. Presione para enviar la información",
                        ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Botón para leer todo el formulario
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _readFormSummary(),
                  icon: Icon(Icons.audio_file),
                  label: Text('LEER RESUMEN DEL FORMULARIO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startListening(TextEditingController controller) async {
    if (_isSpeaking) {
      // No permitir la entrada de voz mientras se están reproduciendo instrucciones
      return;
    }

    if (!_isListening) {
      var available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            String recognized = result.recognizedWords;
            String processed = recognized;
            if (controller == _emailController) {
              processed = _normalizeEmailFromSpeech(recognized);
            }
            setState(() {
              controller.text = processed;
            });
          },
          localeId: "es_ES",
          cancelOnError: true,
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  Widget _buildTextFieldWithSpeech({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String fieldName,
    required String description,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow, size: 18),
              onPressed: () => _readFieldDescription(fieldName, description),
              tooltip: 'Leer descripción',
            ),
          ],
        ),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
            suffixIcon: IconButton(
              icon: Icon(
                _isListeningForCommand
                    ? Icons.mic_off
                    : (_isSpeaking
                        ? Icons.mic_off
                        : (_isListening ? Icons.mic : Icons.mic_none)),
              ),
              onPressed:
                  (_isSpeaking || _isListeningForCommand)
                      ? null
                      : () => _startListening(controller),
              tooltip:
                  _isListeningForCommand
                      ? 'Modo comando activo - micrófono de campo deshabilitado'
                      : (_isSpeaking
                          ? 'Micrófono deshabilitado'
                          : 'Entrada por voz'),
            ),
          ),
          onTap: () => _readFieldDescription(fieldName, description),
        ),
      ],
    );
  }

  Widget _buildDropdownWithSpeech() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tipo de consulta *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow, size: 18),
              onPressed:
                  () => _speak(
                    "Tipo de consulta. Seleccione una opción del menú desplegable",
                  ),
              tooltip: 'Leer descripción',
            ),
          ],
        ),
        SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: _selectedOption,
          items:
              ['Opción 1', 'Opción 2', 'Opción 3', 'Opción 4'].map((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedOption = newValue!;
            });
            _speak("Seleccionado: $newValue");
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxWithSpeech() {
    return Row(
      children: [
        Checkbox(
          value: _aceptoTerminos,
          onChanged: (bool? value) {
            setState(() {
              _aceptoTerminos = value!;
            });
            _speak(value! ? "Términos aceptados" : "Términos no aceptados");
          },
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _aceptoTerminos = !_aceptoTerminos;
              });
              _speak(
                _aceptoTerminos
                    ? "Términos aceptados"
                    : "Términos no aceptados",
              );
            },
            child: Text(
              'Acepto los términos y condiciones *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.play_arrow, size: 18),
          onPressed:
              () => _speak(
                "Debe aceptar los términos y condiciones para continuar",
              ),
          tooltip: 'Leer descripción',
        ),
      ],
    );
  }

  void _readFormSummary() {
    String summary = """
      Resumen del formulario.
      Nombre: ${_nombreController.text.isEmpty ? 'No ingresado' : _nombreController.text}.
      Email: ${_emailController.text.isEmpty ? 'No ingresado' : _emailController.text}.
      Teléfono: ${_telefonoController.text.isEmpty ? 'No ingresado' : _telefonoController.text}.
      Tipo de consulta: $_selectedOption.
      Mensaje: ${_mensajeController.text.isEmpty ? 'No ingresado' : _mensajeController.text}.
      Términos: ${_aceptoTerminos ? 'Aceptados' : 'No aceptados'}.
    """;
    _speak(summary);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _mensajeController.dispose();
    flutterTts.stop();
    super.dispose();
  }
}
