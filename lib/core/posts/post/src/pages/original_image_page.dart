// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/display.dart';
import '../../../../../foundation/mobile.dart';
import '../../../../../foundation/platform.dart';
import '../../../../configs/config/providers.dart';
import '../../../../images/booru_image.dart';
import '../../../../widgets/widgets.dart';
import '../types/post.dart';

class OriginalImagePage extends ConsumerStatefulWidget {
  const OriginalImagePage({
    required this.imageUrl,
    required this.id,
    required this.aspectRatio,
    required this.contentSize,
    super.key,
  });

  OriginalImagePage.post(
    Post post, {
    super.key,
  }) : imageUrl = post.originalImageUrl,
       aspectRatio = post.aspectRatio,
       contentSize = Size(
         post.width,
         post.height,
       ),
       id = post.id;

  final String imageUrl;
  final int id;
  final double? aspectRatio;
  final Size? contentSize;

  @override
  ConsumerState<OriginalImagePage> createState() => _OriginalImagePageState();
}

class _OriginalImagePageState extends ConsumerState<OriginalImagePage> {
  Orientation? currentRotation;
  var overlay = true;
  var zoom = false;
  var turn = ValueNotifier<double>(0);
  
  // NOVO: Controller para manipular o zoom do InteractiveViewer
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentRotation = context.orientation;
    });
  }
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _pop(bool didPop) async {
    await setDeviceToAutoRotateMode();
    unawaited(showSystemStatus());

    if (mounted && !didPop) {
      Navigator.of(context).pop();
    }
  }

  // Lógica do Zoom "Fit Height"
  void _handleDoubleTap() {
    // Zoom atual (pegamos da matriz 4x4, posição [0])
    final double currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Size screenSize = MediaQuery.of(context).size;
    
    // Altura do conteúdo (Imagem)
    final double contentHeight = widget.contentSize?.height ?? 1.0;
    final double contentWidth = widget.contentSize?.width ?? 1.0;

    // Se o contentSize não estiver definido, aborta
    if (contentHeight == 1.0) return;

    // Calcula a escala necessária para a imagem preencher a altura da tela
    // No InteractiveViewer, o scale base (1.0) geralmente encaixa a imagem na largura (fit width) ou contain.
    // Precisamos calcular quanto dar de zoom para atingir a altura.
    
    // Assumindo que o estado inicial é "contain" (imagem inteira na tela):
    // A altura renderizada inicial é: screenSize.width / aspectRatio
    final double initialRenderedHeight = screenSize.width / (contentWidth / contentHeight);
    
    // Escala alvo = Altura da Tela / Altura Renderizada Inicial
    final double targetScale = screenSize.height / initialRenderedHeight;

    // Toggle: Se já estamos perto do alvo, volta pra 1.0. Se não, vai pro alvo.
    double newScale = 1.0;
    if ((currentScale - targetScale).abs() > 0.1 && currentScale < targetScale) {
       newScale = targetScale;
    }

    // Cria a nova matriz de transformação
    // Mantemos o centro alinhado
    final Matrix4 newMatrix = Matrix4.identity()
      ..translate(
        -((contentWidth * newScale - screenSize.width) / 2), 
        -((contentHeight * newScale - screenSize.height) / 2)
      )
      ..scale(newScale);
      
    // Aplica a animação (simplificado: setando valor direto, o InteractiveViewer anima se tiver physics?)
    // Para animar suavemente precisariamos de um AnimationController, 
    // mas vamos testar setando direto primeiro pra ver se funciona.
    _transformationController.value = Matrix4.identity()..scale(newScale);
    
    // Nota: Centralização exata com TransformationController é chata matemática.
    // Vamos tentar um scale simples primeiro.
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _pop(didPop);
            return;
          }

          _pop(didPop);
        },
        child: Focus(
          autofocus: true,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _setOverlay(!overlay);
        });
      },
      // NOVO: Detectar duplo clique aqui, em cima de tudo
      onDoubleTap: _handleDoubleTap,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: kToolbarHeight * 1.3,
          automaticallyImplyLeading: false,
          leading: AnimatedSwitcher(
            duration: Durations.extralong1,
            reverseDuration: const Duration(milliseconds: 10),
            child: overlay
                ? IconButton(
                    icon: const Icon(Symbols.close, color: Colors.white),
                    onPressed: () => _pop(false),
                  )
                : null,
          ),
          actions: [
            if (isMobilePlatform())
              AnimatedSwitcher(
                duration: Durations.extralong1,
                reverseDuration: const Duration(milliseconds: 10),
                child: overlay
                    ? IconButton(
                        onPressed: () {
                          if (currentRotation == Orientation.portrait) {
                            setState(() {
                              setDeviceToLandscapeMode();
                              currentRotation = Orientation.landscape;
                            });
                          } else {
                            setState(() {
                              setDeviceToPortraitMode();
                              currentRotation = Orientation.portrait;
                            });
                          }
                        },
                        color: Colors.white,
                        icon: currentRotation == Orientation.portrait
                            ? const Icon(Symbols.rotate_left)
                            : const Icon(Symbols.rotate_right),
                      )
                    : null,
              ),
            if (isDesktopPlatform())
              AnimatedSwitcher(
                duration: Durations.extralong1,
                reverseDuration: const Duration(milliseconds: 10),
                child: overlay
                    ? Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          onPressed: () => turn.value = (turn.value - 0.25) % 1,
                          color: Colors.white,
                          icon: const Icon(Symbols.rotate_left),
                        ),
                      )
                    : null,
              ),
          ],
        ),
        // TENTATIVA: Passar o controller para o InteractiveViewerExtended
        // Se der erro de "No named parameter transformationController", 
        // significa que o widget wrapper não expõe isso e teremos que editar widgets.dart
        body: InteractiveViewerExtended(
          transformationController: _transformationController, // <-- AQUI
          contentSize: widget.contentSize,
          onTransformationChanged: (details) {
            setState(() {
              zoom = details.isZoomed;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder(
                valueListenable: turn,
                builder: (context, value, child) => RotationTransition(
                  turns: AlwaysStoppedAnimation(value),
                  child: child,
                ),
                child: _buildImage(),
              ),
              AnimatedSwitcher(
                duration: Durations.extralong1,
                reverseDuration: const Duration(milliseconds: 10),
                child: overlay
                    ? ShadowGradientOverlay(
                        alignment: Alignment.topCenter,
                        colors: <Color>[
                          const Color.fromARGB(60, 0, 0, 0),
                          Colors.black12.withValues(alpha: 0),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return _ImageViewer(
      imageUrl: widget.imageUrl,
      aspectRatio: widget.aspectRatio,
      contentSize: widget.contentSize,
    );
  }

  void _setOverlay(bool value) {
    overlay = value;

    if (overlay) {
      showSystemStatus();
    } else {
      hideSystemStatus();
    }
  }
}

class _ImageViewer extends ConsumerStatefulWidget {
  const _ImageViewer({
    required this.imageUrl,
    required this.aspectRatio,
    required this.contentSize,
  });

  final String imageUrl;
  final double? aspectRatio;
  final Size? contentSize;

  @override
  ConsumerState<_ImageViewer> createState() => __ImageViewerState();
}

class __ImageViewerState extends ConsumerState<_ImageViewer> {
  final _controller = ExtendedImageController();

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BooruImage(
      config: ref.watchConfigAuth,
      imageUrl: widget.imageUrl,
      controller: _controller,
      borderRadius: BorderRadius.zero,
      aspectRatio: widget.aspectRatio,
      imageHeight: widget.contentSize?.height,
      imageWidth: widget.contentSize?.width,
      forceFill: true,
      placeholderWidget: ValueListenableBuilder(
        valueListenable: _controller.progress,
        builder: (context, progress, child) {
          return Center(
            child: CircularProgressIndicator(
              value: progress,
            ),
          );
        },
      ),
    );
  }
}
