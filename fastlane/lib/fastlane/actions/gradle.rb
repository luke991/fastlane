require "pathname"
require "shellwords"

module Fastlane
  module Actions
    module SharedValues
      GRADLE_APK_OUTPUT_PATH = :GRADLE_APK_OUTPUT_PATH
      GRADLE_ALL_APK_OUTPUT_PATHS = :GRADLE_ALL_APK_OUTPUT_PATHS
      GRADLE_FLAVOR = :GRADLE_FLAVOR
      GRADLE_BUILD_TYPE = :GRADLE_BUILD_TYPE
    end

    class GradleAction < Action
      def self.run(params)
        task = params[:task]
        flavor = params[:flavor]
        build_type = params[:build_type]

        gradle_task = [task, flavor, build_type].join

        project_dir = params[:project_dir]

        gradle_path_param = params[:gradle_path] || "./gradlew"

        # Get the path to gradle, if it's an absolute path we take it as is, if it's relative we assume it's relative to the project_dir
        gradle_path = if Pathname.new(gradle_path_param).absolute?
                        File.expand_path(gradle_path_param)
                      else
                        File.expand_path(File.join(project_dir, gradle_path_param))
                      end

        # Ensure we ended up with a valid path to gradle
        UI.user_error!("Couldn't find gradlew at path '#{File.expand_path(gradle_path)}'") unless File.exist?(gradle_path)

        # Construct our flags
        flags = []
        flags << "-p #{project_dir.shellescape}"
        flags << params[:properties].map { |k, v| "-P#{k.to_s.shellescape}=#{v.to_s.shellescape}" }.join(" ") unless params[:properties].nil?
        flags << params[:flags] unless params[:flags].nil?

        # Run the actual gradle task
        gradle = Helper::GradleHelper.new(gradle_path: gradle_path)

        # If these were set as properties, then we expose them back out as they might be useful to others
        Actions.lane_context[SharedValues::GRADLE_BUILD_TYPE] = build_type if build_type
        Actions.lane_context[SharedValues::GRADLE_FLAVOR] = flavor if flavor

        # We run the actual gradle task
        result = gradle.trigger(task: gradle_task,
                                serial: params[:serial],
                                flags: flags.join(" "),
                                print_command: params[:print_command],
                                print_command_output: params[:print_command_output])

        # If we didn't build, then we return now, as it makes no sense to search for apk's in a non-`assemble` scenario
        return result unless task.start_with?("assemble")

        apk_search_path = File.join(project_dir, "*", "build", "outputs", "apk", "*.apk")

        # Our apk is now built, but there might actually be multiple ones that were built if a flavor was not specified in a multi-flavor project (e.g. `assembleRelease`), however we're not interested in unaligned apk's...
        new_apks = Dir[apk_search_path].reject { |path| path =~ /^.*-unaligned.apk$/i }
        new_apks = new_apks.map { |path| File.expand_path(path) }

        # We expose all of these new apk's
        Actions.lane_context[SharedValues::GRADLE_ALL_APK_OUTPUT_PATHS] = new_apks

        # We also take the most recent apk to return as SharedValues::GRADLE_APK_OUTPUT_PATH, this is the one that will be relevant for most projects that just build a single build variant (flavor + build type combo). In multi build variants this value is undefined
        last_apk_path = new_apks.sort_by(&File.method(:mtime)).last
        Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH] = File.expand_path(last_apk_path) if last_apk_path

        # Give a helpful message in case there were no new apk's. Remember we're only running this code when assembling, in which case we certainly expect there to be an apk
        UI.message('Couldn\'t find any new signed apk files...') if new_apks.empty?

        return result
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "All gradle related actions, including building and testing your Android app"
      end

      def self.details
        [
          "Run `./gradlew tasks` to get a list of all available gradle tasks for your project"
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :task,
                                       env_name: "FL_GRADLE_TASK",
                                       description: 'The gradle task you want to execute, e.g. `assemble` or `test`. For tasks such as `assembleMyFlavorRelease` you should use gradle(task: \'assemble\', flavor: \'Myflavor\', build_type: \'Release\')',
                                       optional: false,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :flavor,
                                       env_name: "FL_GRADLE_FLAVOR",
                                       description: "The flavor that you want the task for, e.g. `MyFlavor`. If you are running the `assemble` task in a multi-flavor project, and you rely on Actions.lane_context[Actions.SharedValues::GRADLE_APK_OUTPUT_PATH] then you must specify a flavor here or else this value will be undefined",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :build_type,
                                       env_name: "FL_GRADLE_BUILD_TYPE",
                                       description: "The build type that you want the task for, e.g. `Release`. Useful for some tasks such as `assemble`",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :flags,
                                       env_name: "FL_GRADLE_FLAGS",
                                       description: "All parameter flags you want to pass to the gradle command, e.g. `--exitcode --xml file.xml`",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :project_dir,
                                       env_name: "FL_GRADLE_PROJECT_DIR",
                                       description: "The root directory of the gradle project. Defaults to `.`",
                                       default_value: ".",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :gradle_path,
                                       env_name: "FL_GRADLE_PATH",
                                       description: "The path to your `gradlew`. If you specify a relative path, it is assumed to be relative to the `project_dir`",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :properties,
                                       env_name: "FL_GRADLE_PROPERTIES",
                                       description: "Gradle properties to be exposed to the gradle script",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :serial,
                                       env_name: "FL_ANDROID_SERIAL",
                                       description: "Android serial, wich device should be used for this command",
                                       is_string: true,
                                       default_value: ""),
          FastlaneCore::ConfigItem.new(key: :print_command,
                                       env_name: "FL_GRADLE_PRINT_COMMAND",
                                       description: "Control whether the generated Gradle command is printed as output before running it (true/false)",
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :print_command_output,
                                       env_name: "FL_GRADLE_PRINT_COMMAND_OUTPUT",
                                       description: "Control whether the output produced by given Gradle command is printed while running (true/false)",
                                       is_string: false,
                                       default_value: true)
        ]
      end

      def self.output
        [
          ["GRADLE_APK_OUTPUT_PATH", "The path to the newly generated apk file. Undefined in a multi-variant assemble scenario"],
          ["GRADLE_ALL_APK_OUTPUT_PATHS", 'When running a multi-variant `assemble`, the array of signed apk\'s that were generated'],
          ["GRADLE_FLAVOR", "The flavor, e.g. `MyFlavor`"],
          ["GRADLE_BUILD_TYPE", "The build type, e.g. `Release`"]
        ]
      end

      def self.return_value
        "The output of running the gradle task"
      end

      def self.authors
        ["KrauseFx", "lmirosevic"]
      end

      def self.is_supported?(platform)
        platform == :android || platform == :ios
      end
    end
  end
end
