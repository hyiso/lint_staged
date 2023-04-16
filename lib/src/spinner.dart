const _kFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

class Spinner {
  int _index = 0;

  @override
  String toString() => _kFrames[_index++ % _kFrames.length];
}
