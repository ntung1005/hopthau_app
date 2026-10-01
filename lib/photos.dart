import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'theme.dart';

/// Chọn ảnh từ máy, nén nhẹ, upload lên Storage qua URL ký sẵn của BE. Trả về URL công khai.
/// Người dùng huỷ: danh sách rỗng.
Future<List<String>> pickAndUploadPhotos({int max = 10}) async {
  final files = await ImagePicker().pickMultiImage(limit: max, maxWidth: 1920, imageQuality: 82);
  final urls = <String>[];
  for (final f in files.take(max)) {
    final type = f.mimeType ?? (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    final slot = await api.postAuth('/uploads', {'content_type': type}) as Map<String, dynamic>;
    final res =
        await http.put(Uri.parse(slot['upload_url'] as String), headers: {'Content-Type': type}, body: await f.readAsBytes());
    if (res.statusCode >= 300) throw ApiException(res.statusCode, 'upload_failed');
    urls.add(slot['public_url'] as String);
  }
  return urls;
}

/// Lưới ảnh; bấm để xem to. [onRemove] có thì hiện nút xoá trên từng ảnh.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid(this.urls, {super.key, this.onRemove, this.size = 88});

  final List<String> urls;
  final void Function(String url)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in urls)
          Stack(children: [
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(child: Image.network(u, fit: BoxFit.contain)),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.field),
                child: Image.network(u,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: size, height: size, color: AppColors.field, child: const Icon(Icons.broken_image_outlined))),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => onRemove!(u),
                  child: const CircleAvatar(
                      radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                ),
              ),
          ]),
      ]);
}

/// Ô chọn ảnh trong form: ảnh đã chọn + nút thêm.
class PhotoPicker extends StatefulWidget {
  const PhotoPicker({super.key, required this.photos, required this.onChanged, this.max = 10});

  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int max;

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  var _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final added = await pickAndUploadPhotos(max: widget.max - widget.photos.length);
      if (added.isNotEmpty) widget.onChanged([...widget.photos, ...added]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tải được ảnh, thử lại nhé')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.photos.isNotEmpty) ...[
          PhotoGrid(widget.photos, onRemove: (u) => widget.onChanged([...widget.photos]..remove(u))),
          const SizedBox(height: 8),
        ],
        if (widget.photos.length < widget.max)
          OutlinedButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_busy ? 'Đang tải ảnh...' : 'Thêm ảnh (${widget.photos.length}/${widget.max})'),
          ),
      ]);
}
