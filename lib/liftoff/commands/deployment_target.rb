command :deployment_target do |c|
  c.syntax = 'liftoff deployment_target'
  c.summary = 'Set deployment target to iOS 5.1.'
  c.description = ''

  c.action do
    XcodeprojHelper.new.set_deployment_target('5.1')
  end
end
