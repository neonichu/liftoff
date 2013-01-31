require 'xcodeproj'
include Xcodeproj::Project::Object

TODO_WARNING_SCRIPT = <<WARNING
KEYWORDS="TODO:|FIXME:|\\?\\?\\?:|\\!\\!\\!:"
find "${SRCROOT}" -ipath "${SRCROOT}/pods" -prune -o \\( -name "*.h" -or -name "*.m" \\) -print0 | xargs -0 egrep --with-filename --line-number --only-matching "($KEYWORDS).*\\$" | perl -p -e "s/($KEYWORDS)/ warning: \\$1/"
WARNING

HOSEY_WARNINGS = %w(
  GCC_WARN_INITIALIZER_NOT_FULLY_BRACKETED
  GCC_WARN_MISSING_PARENTHESES
  GCC_WARN_ABOUT_RETURN_TYPE
  GCC_WARN_SIGN_COMPARE
  GCC_WARN_CHECK_SWITCH_STATEMENTS
  GCC_WARN_UNUSED_FUNCTION
  GCC_WARN_UNUSED_LABEL
  GCC_WARN_UNUSED_VALUE
  GCC_WARN_UNUSED_VARIABLE
  GCC_WARN_SHADOW
  GCC_WARN_64_TO_32_BIT_CONVERSION
  GCC_WARN_ABOUT_MISSING_FIELD_INITIALIZERS
  GCC_WARN_ABOUT_MISSING_NEWLINE
  GCC_WARN_UNDECLARED_SELECTOR
  GCC_WARN_TYPECHECK_CALLS_TO_PRINTF
)

class XcodeprojHelper
  XCODE_PROJECT_PATH = Dir.glob("*.xcodeproj")

  def initialize
    @project = Xcodeproj::Project.new(xcode_project_file)
    @target = project_target
    @group = project_group
  end

  def treat_warnings_as_errors
    say 'Setting GCC_TREAT_WARNINGS_AS_ERRORS at the project level'
    @project.build_configurations.each do |configuration|
      configuration.build_settings['GCC_TREAT_WARNINGS_AS_ERROR'] = 'YES'
    end
    save_changes
  end

  def enable_hosey_warnings
    say 'Setting Hosey warnings at the project level'
    @project.build_configurations.each do |configuration|
      HOSEY_WARNINGS.each do |setting|
        configuration.build_settings[setting] = 'YES'
      end
    end
    save_changes
  end

  def enable_static_analyzer
    say 'Turning on Static Analyzer at the project level'
    @project.build_configurations.each do |configuration|
      configuration.build_settings['RUN_CLANG_STATIC_ANALYZER'] = 'YES'
    end
    save_changes
  end

  def set_indentation_level(level)
    say "Setting the project indentation level to #{level} spaces"
    project_attributes = @project.main_group.attributes
    project_attributes['indentWidth'] = level
    project_attributes['tabWidth'] = level
    project_attributes['usesTabs'] = 0
    save_changes
  end

  def add_todo_script_phase
    say 'Adding shell script build phase to warn on TODO and FIXME comments'
    add_shell_script_build_phase(TODO_WARNING_SCRIPT, 'Warn for TODO and FIXME comments')
  end

  def move_supporting_files_group
    say 'Moving Supporting Files group'
    group = thing_named(@group.groups, 'Supporting Files')
    if group
      group.remove_from_project
      group.path = @group.path
      @project.main_group << group
      save_changes
    end
  end

  def remove_info_plist_strings
    say 'Removing useless InfoPlist.strings file'

    phase = thing_named(@target.build_phases, 'ResourcesBuildPhase')
    if phase
      ref = thing_named(phase.files_references, 'InfoPlist.strings')
      if ref
        phase.remove_file_reference(ref)
      end
    end

    group = thing_named(@project.groups, 'Supporting Files')
    if group
      info_plist = thing_named(group.children, 'InfoPlist.strings')
      if info_plist
        info_plist.remove_from_project
      end
    end

		save_changes
	end
  end

  private

	def group_sort_by_type!(group)
		group.children.sort! do |x, y|
			if x.is_a?(PBXGroup) && y.is_a?(PBXFileReference)
				-1
			elsif x.is_a?(PBXFileReference) && y.is_a?(PBXGroup)
				1
			elsif x.respond_to?(:display_name) && y.respond_to?(:display_name)
				x.display_name <=> y.display_name
			else
				0
			end
		end
	end

  def project_group
    @project.groups.each do |group|
      group.path ? (return group) : true
    end
  end

  def project_target
    if @project_target.nil?
      available_targets = @project.targets.to_a
      available_targets.delete_if { |t| t.name =~ /Tests$/ }
      @project_target = available_targets.first

      if @project_target.nil?
        raise 'Could not locate a target in the given project.'
      end
    end

    @project_target
  end

  def thing_named(things, name)
    things.each do |thing|
      if thing.display_name == name
        return thing
      end
    end
    return nil
  end

  def xcode_project_file
    @xcode_project_file ||= XCODE_PROJECT_PATH.first

    if @xcode_project_file.nil?
       raise 'Can not run in a directory without an .xcodeproj file'
    end

    if @xcode_project_file == 'Pods.xcodeproj'
      raise 'Can not run in the Pods directory. $ cd .. maybe?'
    end

    @xcode_project_file
  end

  def add_shell_script_build_phase(script, name)
    unless build_phase_exists_with_name name
      @target.shell_script_build_phases.push('name' => name, 'shellScript' => script)
      save_changes
    end
  end

  def build_phase_exists_with_name(name)
    @target.build_phases.to_a.index { |phase| defined?(phase.name) && phase.name == name }
  end

  def save_changes
    @project.save_as xcode_project_file
  end
end
