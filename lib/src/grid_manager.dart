import 'package:flutter_google_maps_cluster/src/grid_cell.dart';
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
    grid = List.generate(rowCount, (row) {
      return List.generate(columnCount, (column) {
        return GridCell(row: row, column: column);
      });
    });
  }

  void updateDensity(LatLng position) {
    final int row =
        ((position.latitude + 90) ~/ gridCellSize).clamp(0, rowCount - 1);
    final int column =
        ((position.longitude + 180) ~/ gridCellSize).clamp(0, columnCount - 1);
    grid[row][column].density++;
  }

  GridCell getCell(int row, int column) {
    return grid[row][column];
  }
}
