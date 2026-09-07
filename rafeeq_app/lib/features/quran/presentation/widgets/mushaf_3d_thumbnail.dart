import 'package:flutter/material.dart';
import 'dart:math';

/// A 3D-styled thumbnail widget that simulates an open Mushaf.
/// It renders a leather-like cover background and two small page overlays.
class Mushaf3DThumbnail extends StatelessWidget {
  final Color coverColor;
  final double width;
  final double height;

  const Mushaf3DThumbnail({
    super.key,
    required this.coverColor,
    this.width = 60,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Book Cover
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: coverColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 1,
                  offset: const Offset(-1, -1),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  coverColor.withOpacity(0.8),
                  coverColor,
                  coverColor.withOpacity(0.6),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // The spine shading
          Positioned(
            left: width / 2 - 2,
            child: Container(
              width: 4,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Left Page
          Positioned(
            left: 4,
            right: width / 2,
            top: 4,
            bottom: 4,
            child: Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(pi / 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7), // Warm paper color
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(1, 0),
                    ),
                  ],
                ),
                child: _buildPageLines(),
              ),
            ),
          ),

          // Right Page
          Positioned(
            left: width / 2,
            right: 4,
            top: 4,
            bottom: 4,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-pi / 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(-1, 0),
                    ),
                  ],
                ),
                child: _buildPageLines(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageLines() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          12,
          (index) => Container(
            height: 1,
            color: Colors.black.withOpacity(0.15),
            margin: EdgeInsets.symmetric(
              horizontal: index % 3 == 0 ? 4 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
