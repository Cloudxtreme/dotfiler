require 'pathname'
require 'yaml'
require_relative './copy_task'

SCRIPT_PATH = Pathname(__FILE__).dirname()
APPLICATIONS_DIR = SCRIPT_PATH.parent.join('applications')
APPLICATIONS_CONFIG_FILES = APPLICATIONS_DIR.children.select { |app| app.extname == '.yml' }
DEFAULT_ROOT = "~/"
BACKUP_ROOT = "~/dotfiles"


# Returns the currently active label.
def setup_label
  '<win>'
end

def get_task(config_path)
  Setup::CopyTask.new(YAML.load(config_path.read()), setup_label, DEFAULT_ROOT, BACKUP_ROOT)
end

# Create a list of tasks to execute.
def get_tasks
  APPLICATIONS_CONFIG_FILES.map(&method(:get_task)).select(&:should_execute)
end

# TODO: allow to have user defined tasks with custom .yml files.
# TODO: define multiple commands.
# TODO: define command that pulls dotfiles from github.
# TODO: have a single command to perform initial setup (pull setup, install dependencies, git clone dotfiles, run setup restore).
# TODO: should be easy to have multiple account settings.
puts 'Backup Running'
get_tasks.each do |task|
  puts "> #{task.name}"
  task.backup
end
puts 'Backup Finished'