module Fastlane
  module Actions
    class SetupJenkinsAction < Action
      USED_ENV_NAMES = [
        "BACKUP_XCARCHIVE_DESTINATION",
        "DERIVED_DATA_PATH",
        "FL_CARTHAGE_DERIVED_DATA",
        "GYM_BUILD_PATH",
        "GYM_CODE_SIGNING_IDENTITY",
        "GYM_DERIVED_DATA_PATH",
        "GYM_OUTPUT_DIRECTORY",
        "GYM_RESULT_BUNDLE",
        "SCAN_DERIVED_DATA_PATH",
        "SCAN_OUTPUT_DIRECTORY",
        "SCAN_RESULT_BUNDLE",
        "XCODE_DERIVED_DATA_PATH"
      ].freeze

      def self.run(params)
        # Stop if not executed by CI
        if !Helper.is_ci? && !params[:force]
          UI.important "Not executed by Continuous Integration system."
          return
        end

        # Print table
        FastlaneCore::PrintTable.print_values(
          config: params,
          title: "Summary for Setup Jenkins Action"
        )

        # Keychain
        if params[:unlock_keychain] && params[:keychain_path]
          keychain_path = File.expand_path(params[:keychain_path])
          UI.message "Unlocking keychain: \"#{keychain_path}\"."
          Actions::UnlockKeychainAction.run(
            path: keychain_path,
            password: params[:keychain_password],
            add_to_search_list: params[:add_keychain_to_search_list],
            set_default: params[:set_default_keychain]
          )
        end

        # Code signing identity
        if params[:set_code_signing_identity] && params[:code_signing_identity]
          code_signing_identity = params[:code_signing_identity]
          UI.message "Set code signing identity: \"#{code_signing_identity}\"."
          ENV["GYM_CODE_SIGNING_IDENTITY"] = code_signing_identity
        end

        # Set output directory
        if params[:output_directory]
          output_directory_path = File.expand_path(params[:output_directory])
          UI.message "Set output directory path to: \"#{output_directory_path}\"."
          ENV["GYM_BUILD_PATH"] = output_directory_path
          ENV["GYM_OUTPUT_DIRECTORY"] = output_directory_path
          ENV["SCAN_OUTPUT_DIRECTORY"] = output_directory_path
          ENV["BACKUP_XCARCHIVE_DESTINATION"] = output_directory_path
        end

        # Set derived data
        if params[:derived_data_path]
          derived_data_path = File.expand_path(params[:derived_data_path])
          UI.message "Set derived data path to: \"#{derived_data_path}\"."
          ENV["DERIVED_DATA_PATH"] = derived_data_path # Used by clear_derived_data.
          ENV["XCODE_DERIVED_DATA_PATH"] = derived_data_path
          ENV["GYM_DERIVED_DATA_PATH"] = derived_data_path
          ENV["SCAN_DERIVED_DATA_PATH"] = derived_data_path
          ENV["FL_CARTHAGE_DERIVED_DATA"] = derived_data_path
        end

        # Set result bundle
        if params[:result_bundle]
          UI.message "Set result bundle."
          ENV["GYM_RESULT_BUNDLE"] = "YES"
          ENV["SCAN_RESULT_BUNDLE"] = "YES"
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Setup xcodebuild, gym and scan for easier Jenkins integration"
      end

      def self.details
        [
          "- Adds and unlocks keychains from Jenkins 'Keychains and Provisioning Profiles Plugin'",
          "- Sets code signing identity from Jenkins 'Keychains and Provisioning Profiles Plugin'",
          "- Sets output directory to './output' (gym, scan and backup_xcarchive).",
          "- Sets derived data path to './derivedData' (xcodebuild, gym, scan and clear_derived_data, carthage).",
          "- Produce result bundle (gym and scan)."
        ].join("\n")
      end

      def self.available_options
        [
          # General
          FastlaneCore::ConfigItem.new(key: :force,
                                       env_name: "FL_SETUP_JENKINS_FORCE",
                                       description: "Force setup, even if not executed by Jenkins",
                                       is_string: false,
                                       default_value: false),

          # Keychain
          FastlaneCore::ConfigItem.new(key: :unlock_keychain,
                                       env_name: "FL_SETUP_JENKINS_UNLOCK_KEYCHAIN",
                                       description: "Unlocks keychain",
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :add_keychain_to_search_list,
                                       env_name: "FL_SETUP_JENKINS_ADD_KEYCHAIN_TO_SEARCH_LIST",
                                       description: "Add to keychain search list",
                                       is_string: false,
                                       default_value: :replace),
          FastlaneCore::ConfigItem.new(key: :set_default_keychain,
                                       env_name: "FL_SETUP_JENKINS_SET_DEFAULT_KEYCHAIN",
                                       description: "Set keychain as default",
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :keychain_path,
                                       env_name: "KEYCHAIN_PATH",
                                       description: "Path to keychain",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :keychain_password,
                                       env_name: "KEYCHAIN_PASSWORD",
                                       description: "Keychain password",
                                       is_string: true,
                                       default_value: ""),

          # Code signing identity
          FastlaneCore::ConfigItem.new(key: :set_code_signing_identity,
                                       env_name: "FL_SETUP_JENKINS_SET_CODE_SIGNING_IDENTITY",
                                       description: "Set code signing identity from CODE_SIGNING_IDENTITY environment",
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :code_signing_identity,
                                       env_name: "CODE_SIGNING_IDENTITY",
                                       description: "Code signing identity",
                                       is_string: true,
                                       optional: true),

          # Xcode parameters
          FastlaneCore::ConfigItem.new(key: :output_directory,
                                       env_name: "FL_SETUP_JENKINS_OUTPUT_DIRECTORY",
                                       description: "The directory in which the ipa file should be stored in",
                                       is_string: true,
                                       default_value: "./output"),
          FastlaneCore::ConfigItem.new(key: :derived_data_path,
                                       env_name: "FL_SETUP_JENKINS_DERIVED_DATA_PATH",
                                       description: "The directory where build products and other derived data will go",
                                       is_string: true,
                                       default_value: "./derivedData"),
          FastlaneCore::ConfigItem.new(key: :result_bundle,
                                       env_name: "FL_SETUP_JENKINS_RESULT_BUNDLE",
                                       description: "Produce the result bundle describing what occurred will be placed",
                                       is_string: false,
                                       default_value: true)
        ]
      end

      def self.authors
        ["bartoszj"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
