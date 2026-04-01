require 'xcodeproj'
project_path = 'macos/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

# Avoid duplicate scripts
if target.shell_script_build_phases.none? { |phase| phase.name == 'Strip Extended Attributes' }
  # Add the shell script build phase
  phase = target.new_shell_script_build_phase('Strip Extended Attributes')
  phase.shell_script = "xattr -cr \"$CODESIGNING_FOLDER_PATH\""
  
  # Ensure the script runs before Code Signing 
  # Note: CodeSign runs natively AFTER all build phases, so placing this as the last Build Phase works perfectly!
  
  project.save
  puts 'Successfully added xattr stripping script to Xcode build phases!'
else
  puts 'Script already exists in build phases.'
end
