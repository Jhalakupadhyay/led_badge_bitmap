import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

void main() => runApp(const BadgeBitmapExampleApp());

class BadgeBitmapExampleApp extends StatelessWidget {
  const BadgeBitmapExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Badge Bitmap',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const BadgeBitmapPage(),
    );
  }
}

enum Source { builtInFont, styledText, image }

class BadgeBitmapPage extends StatefulWidget {
  const BadgeBitmapPage({super.key});

  @override
  State<BadgeBitmapPage> createState() => _BadgeBitmapPageState();
}

class _BadgeBitmapPageState extends State<BadgeBitmapPage> {
  final _widthController = TextEditingController(text: '44');
  final _heightController = TextEditingController(text: '11');
  final _textController = TextEditingController(text: 'Hello');

  Source _source = Source.builtInFont;
  ImageFit _fit = ImageFit.fitHeight;
  Uint8List? _imageBytes;
  BadgeBitmap? _bitmap;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    _imageBytes = await file.readAsBytes();
    await _generate();
  }

  Future<void> _generate() async {
    final width = int.tryParse(_widthController.text) ?? 0;
    final height = int.tryParse(_heightController.text) ?? 0;
    if (width <= 0 || height <= 0) {
      setState(() {
        _bitmap = null;
        _error = 'Width and height must be positive whole numbers.';
      });
      return;
    }
    final generator = BadgeBitmapGenerator(width: width, height: height);

    try {
      final bitmap = switch (_source) {
        Source.builtInFont => generator.fromText(_textController.text),
        Source.styledText => await generator.fromStyledText(
          _textController.text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Source.image =>
          _imageBytes == null
              ? null
              : generator.fromImage(_imageBytes!, fit: _fit),
      };
      setState(() {
        _bitmap = bitmap;
        _error = bitmap == null ? 'Pick an image to convert.' : null;
      });
    } on BadgeBitmapException catch (e) {
      setState(() {
        _bitmap = null;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bitmap = _bitmap;
    return Scaffold(
      appBar: AppBar(title: const Text('LED Badge Bitmap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _numberField(_widthController, 'Width')),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_heightController, 'Height')),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<Source>(
            segments: const [
              ButtonSegment(value: Source.builtInFont, label: Text('Font')),
              ButtonSegment(value: Source.styledText, label: Text('Styled')),
              ButtonSegment(value: Source.image, label: Text('Image')),
            ],
            selected: {_source},
            onSelectionChanged: (selection) {
              _source = selection.single;
              _generate();
            },
          ),
          const SizedBox(height: 16),
          if (_source == Source.image) ...[
            FilledButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Pick image'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ImageFit>(
              initialValue: _fit,
              decoration: const InputDecoration(labelText: 'Fit'),
              items: [
                for (final fit in ImageFit.values)
                  DropdownMenuItem(value: fit, child: Text(fit.name)),
              ],
              onChanged: (fit) {
                _fit = fit!;
                _generate();
              },
            ),
          ] else
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Text'),
              onChanged: (_) => _generate(),
            ),
          const SizedBox(height: 24),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (bitmap != null) ...[
            AspectRatio(
              aspectRatio: bitmap.width / bitmap.height,
              child: CustomPaint(painter: _LedPainter(bitmap)),
            ),
            const SizedBox(height: 16),
            Text('Hex segments', style: Theme.of(context).textTheme.titleSmall),
            SelectableText(
              bitmap.toHexSegments().join('\n'),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => _generate(),
    );
  }
}

/// Draws the bitmap as a grid of round LEDs.
class _LedPainter extends CustomPainter {
  _LedPainter(this.bitmap);

  final BadgeBitmap bitmap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final cell = size.width / bitmap.width;
    final on = Paint()..color = Colors.redAccent;
    final off = Paint()..color = Colors.grey.shade900;
    for (var y = 0; y < bitmap.height; y++) {
      for (var x = 0; x < bitmap.width; x++) {
        canvas.drawCircle(
          Offset((x + 0.5) * cell, (y + 0.5) * cell),
          cell * 0.4,
          bitmap.pixelAt(x, y) ? on : off,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LedPainter oldDelegate) => oldDelegate.bitmap != bitmap;
}
