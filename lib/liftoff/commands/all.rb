command :all do |c|
  c.syntax = 'liftoff all'
  c.summary = 'Run all possible commands. (Default)'
  c.action do |args, options|
    unless args.empty?
      say "I don't know what to do with that!"
      say 'Run liftoff help to see a list of available commands'
      exit
    end

    xcode_helper = XcodeprojHelper.new
    xcode_helper.treat_warnings_as_errors
    xcode_helper.add_todo_script_phase
    xcode_helper.enable_hosey_warnings
    xcode_helper.enable_static_analyzer

    xcode_helper.handle_default_images
    xcode_helper.move_supporting_files_group
    xcode_helper.remove_info_plist_strings
    xcode_helper.sort_all_groups
    xcode_helper.set_deployment_target('5.1')

    git_helper = GitHelper.new
    git_helper.generate_files
    git_helper.stage_default_changes
  end
end
