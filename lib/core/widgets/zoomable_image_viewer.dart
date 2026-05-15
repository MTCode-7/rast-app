import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ZoomableImageViewer extends StatefulWidget {
  final String imageUrl;
  final List<String>? imageUrls;
  final VoidCallback? onDismiss;
  final String? heroTag;

  const ZoomableImageViewer({
    super.key,
    required this.imageUrl,
    this.imageUrls,
    this.onDismiss,
    this.heroTag,
  });

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls?.indexOf(widget.imageUrl) ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls ?? [widget.imageUrl];
    final isMultipleImages = images.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            widget.onDismiss?.call();
          },
        ),
        title: isMultipleImages
            ? Text(
                '${_currentIndex + 1}/${images.length}',
                style: const TextStyle(color: Colors.white),
              )
            : null,
        centerTitle: true,
      ),
      body: isMultipleImages
          ? PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: _getImageProvider(images[index]),
                  initialScale: PhotoViewComputedScale.contained * 0.8,
                  heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
                );
              },
              itemCount: images.length,
              loadingBuilder: (context, event) => Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: event == null
                        ? 0
                        : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            )
          : PhotoView(
              imageProvider: _getImageProvider(widget.imageUrl),
              initialScale: PhotoViewComputedScale.contained * 0.8,
              heroAttributes: PhotoViewHeroAttributes(
                tag: widget.heroTag ?? widget.imageUrl,
              ),
              loadingBuilder: (context, event) => Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: event == null
                        ? 0
                        : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'فشل تحميل الصورة',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('http')) {
      return CachedNetworkImageProvider(url);
    }
    return NetworkImage(url);
  }
}

class TappableImage extends StatelessWidget {
  final String imageUrl;
  final List<String>? imageUrls;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const TappableImage({
    super.key,
    required this.imageUrl,
    this.imageUrls,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ZoomableImageViewer(
              imageUrl: imageUrl,
              imageUrls: imageUrls,
            ),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) =>
            placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildDefaultPlaceholder(),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
