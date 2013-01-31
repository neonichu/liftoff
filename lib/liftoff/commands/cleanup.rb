command :cleanup do |c|
  c.syntax = 'liftoff cleanup'
  c.summary = 'Cleanup the project.'
  c.description = ''

  c.action do
    xcode_helper = XcodeprojHelper.new
    xcode_helper.handle_default_images
    xcode_helper.move_supporting_files_group
    xcode_helper.remove_info_plist_strings
    xcode_helper.sort_all_groups
  end
end
