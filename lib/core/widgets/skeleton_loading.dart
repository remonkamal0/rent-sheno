import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonContainer({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(
      begin: 0.35,
      end: 0.8,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonContainer(width: 140, height: 16),
                SkeletonContainer(width: 80, height: 20, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonContainer(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            const SkeletonContainer(width: 200, height: 14),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const SkeletonContainer(width: 110, height: 12),
          ],
        ),
      ),
    );
  }
}

class SkeletonResidenceCard extends StatelessWidget {
  const SkeletonResidenceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonContainer(
            width: double.infinity,
            height: 160,
            borderRadius: 12,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonContainer(width: 120, height: 18, borderRadius: 10),
                SizedBox(height: 12),
                SkeletonContainer(width: 200, height: 24),
                SizedBox(height: 6),
                SkeletonContainer(width: 100, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
