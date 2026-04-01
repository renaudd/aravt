require 'xcodeproj'
project_path = 'macos/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

phase = target.shell_script_build_phases.find { |p| p.name == 'Strip Extended Attributes' }
if phase
  # Force this script to run EVERY single build without fail
  phase.always_out_of_date = '1'
  project.save
  puts 'Successfully enforced ALWAYS RUN on Strip Extended Attributes phase!'
else
  puts 'Phase not found!'
end
