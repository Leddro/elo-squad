import 'package:material_ui/material_ui.dart';

/// Imagem redonda vinda da internet, com um ícone no lugar quando a URL é
/// `null` (Data Dragon fora do ar) ou a imagem falha ao carregar.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.url,
    required this.size,
    this.fallbackIcon = Icons.person,
  });

  final String? url;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(fallbackIcon, size: size * 0.55),
    );

    return ClipOval(
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
