require 'logging'

Logging.init :debug, :verbose, :info, :warn, :success, :error, :fatal

Logging.appenders.stdout(
  'stdout',
  layout: Logging.layouts.pattern(pattern: '%-7l %m\n'))

Logging.logger['Setup'].add_appenders 'stdout'

def set_logger_level(level)
  Logging.logger['Setup'].level = level
end
