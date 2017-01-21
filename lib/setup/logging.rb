require 'logging'

Logging.init :verbose, :info, :warn, :error

Logging.color_scheme(
  'default',
  levels: {
    info: :green,
    warn: :yellow,
    error: :red,
    verbose: :blue
  }
)

Logging.appenders.stdout(
  'stdout',
  layout: Logging.layouts.pattern(
    pattern: '%l: %m\n',
    color_scheme: 'default'
  )
)

LOGGER = Logging.logger['Setup']
LOGGER.add_appenders 'stdout'
