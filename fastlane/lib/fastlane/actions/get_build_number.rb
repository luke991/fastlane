module Fastlane
  module Actions
    class GetBuildNumberAction < Action
      require "shellwords"

      def self.run(params)
        # More information about how to set up your project and how it works:
        # https://developer.apple.com/library/ios/qa/qa1827/_index.html

        folder = params[:xcodeproj] ? File.join(params[:xcodeproj], "..") : "."

        command_prefix = [
          "cd",
          File.expand_path(folder).shellescape,
          "&&"
        ].join(" ")

        command = [
          command_prefix,
          "agvtool",
          "what-version",
          "-terse"
        ].join(" ")

        if Helper.test?
          Actions.lane_context[SharedValues::BUILD_NUMBER] = command
        else
          build_number = (Actions.sh command).split("\n").last.strip

          # Store the number in the shared hash
          Actions.lane_context[SharedValues::BUILD_NUMBER] = build_number
        end
        return build_number
      rescue => ex
        UI.error("Make sure to follow the steps to setup your Xcode project: https://developer.apple.com/library/ios/qa/qa1827/_index.html")
        raise ex
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get the build number of your project"
      end

      def self.details
        [
          "This action will return the current build number set on your project.",
          "You first have to set up your Xcode project, if you haven't done it already:",
          "https://developer.apple.com/library/ios/qa/qa1827/_index.html"
        ].join(" ")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                             env_name: "FL_BUILD_NUMBER_PROJECT",
                             description: "optional, you must specify the path to your main Xcode project if it is not in the project root directory",
                             optional: true,
                             verify_block: proc do |value|
                               UI.user_error!("Please pass the path to the project, not the workspace") if value.end_with? ".xcworkspace"
                               UI.user_error!("Could not find Xcode project") if !File.exist?(value) and !Helper.is_test?
                             end)
        ]
      end

      def self.output
        [
          ["BUILD_NUMBER", "The build number"]
        ]
      end

      def self.authors
        ["Liquidsoul"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include? platform
      end
    end
  end
end
