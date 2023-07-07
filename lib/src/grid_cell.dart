class GridCell {
  final int row;
  final int column;
  int density;

  GridCell({required this.row, required this.column, this.density = 0});
}
