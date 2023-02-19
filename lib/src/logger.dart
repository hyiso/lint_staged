import 'package:cli_util/cli_logging.dart';

Logger _logger = Logger.verbose(logTime: false);

Logger get logger => _logger;

set debug(bool debug) =>
    _logger = debug ? Logger.verbose(logTime: false) : Logger.standard();
