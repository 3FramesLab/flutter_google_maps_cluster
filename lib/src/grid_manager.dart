// 1. Make sure GridManager properly initializes its grid
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GridManager {
  final int rowCount;
  final int columnCount;
  final double gridCellSize;
  late List<List<GridCell>> grid;

  GridManager({
    required this.rowCount,
    required this.columnCount,
    required this.gridCellSize,
  }) {
    // Initialize the grid with empty cells
    grid = List.generate(
      rowCount,
      (_) => List.generate(
        columnCount,
        (_) => GridCell(density: 0),
      ),
    );
  }

  void updateDensity(LatLng position) {
    final int row =
        ((position.latitude + 90) ~/ gridCellSize).clamp(0, rowCount - 1);
    final int column =
        ((position.longitude + 180) ~/ gridCellSize).clamp(0, columnCount - 1);
    grid[row][column].density++;
  }

  GridCell getCell(int row, int column) {
    // Ensure row and column are within bounds
    row = row.clamp(0, rowCount - 1);
    column = column.clamp(0, columnCount - 1);
    return grid[row][column];
  }
}

// 2. Add the missing GridCell class
class GridCell {
  double density;
  GridCell({required this.density});
}
