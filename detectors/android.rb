require_relative '../config_helper'

branch = ARGV[0]
unless branch
  puts "\e[31mBranch not specified\e[0m"
  exit 0
end

gradle_files = Dir.glob(File.join("**/build.gradle"), File::FNM_CASEFOLD)

exit 0 if gradle_files.count == 0

puts
puts "\e[32mAndroid gradle project detected\e[0m"

config_helper = ConfigHelper.new

gradlew_files = Dir.glob('./**/gradlew', File::FNM_CASEFOLD)

gradlew_path = nil

if !gradlew_files.nil? && gradlew_files.count > 0
  gradlew_files.each do |gradlew|
    if gradlew_path.nil?
      gradlew_path = gradlew
    else
      new_splits = gradlew.split(File::SEPARATOR)
      splits = gradlew_path.split(File::SEPARATOR)

      if !splits.nil? && !new_splits.nil? && splits.count > new_splits.count
        gradlew_path = gradlew
      end
    end
  end
end

gradlew_or_gradle = 'gradle'
if gradlew_path
  puts
  puts " -> Gradle wrapper (gradlew) found - using it: #{gradlew_path}"
  gradlew_or_gradle = gradlew_path

  unless File.executable?(gradlew_or_gradle)
    puts " (i) Missing executable permission on gradlew file, adding it now. Path: #{gradlew_or_gradle}"

    File.chmod(0770, gradlew_or_gradle)
  end
else
  puts
  puts " -> No gradle wrapper (gradlew) found - using gradle directly"
end

puts
puts "gradlew_or_gradle: #{gradlew_or_gradle}"

gradle_files.each do |gradle_file|
  configurations = []

  puts ""
  puts "\e[32mInspecting gradle file at path: #{gradle_file}\e[0m"
  puts " -> Inspecting output of: $ #{gradlew_or_gradle} tasks --build-file '#{gradle_file}'"
  IO.popen "#{gradlew_or_gradle} tasks --build-file '#{gradle_file}'" do |io|
    is_build_tasks_section = false
    io.each do |line|
      if !is_build_tasks_section && line.match(/^Build tasks/)
        is_build_tasks_section = true
        next
      else
        if line.strip.empty?
          is_build_tasks_section = false
          next
        end
      end
      if is_build_tasks_section
        next if line.start_with? '--'
        if match = line.match(/^(?<configuration>assemble\S+)(\s*-\s*.*)*/)
          (configurations ||= []) << match.captures[0]
        end
      end
    end
  end

  puts "Assemble configurations (except 'assemble'):"
  if configurations.count > 0
    configurations.each { |configuration| puts configuration }
    puts "#{configurations.count} in total"

    config_helper.save("android", branch, {
      name: gradle_file,
      path: gradle_file,
      schemes: configurations,
      gradlew_path: gradlew_path
    })
  else
    puts "\e[31mNo configuration found\e[0m"
  end
end
