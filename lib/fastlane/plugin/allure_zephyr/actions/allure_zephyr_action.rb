require 'fastlane/action'
require_relative '../helper/allure_zephyr_helper'

module Fastlane
  module Actions
    class AllureZephyrAction < Action
      def self.run(params)
        report_path = File.expand_path(params[:report_path])

        helper = Helper::AllureZephyrHelper.new(
          project: params[:project], 
          jira_api: params[:jira_api_url], 
          zephyr_api: params[:zephyr_api_url], 
          credentials: { username: params[:jira_username], password: params[:jira_password] },
          report_path: report_path,
          limit_by_project: params[:limit_by_project]
        )
        helper.execute_all(version: params[:version], cycle: params[:cycle])
      end

      def self.description
        "Publish Allure results to Zephyr"
      end

      def self.authors
        ["Nikita Ianenko"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "This plugin publishes test results from Allure to Zephyr, for those tests that have links included."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :report_path,
                               description: "Path to Allure report directory",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :project,
                               description: "JIRA project ID",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :jira_api_url,
                               description: "JIRA API URL (e.g. https://jira.example.com/rest/api/2)",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :zephyr_api_url,
                               description: "Zephyr API URL (e.g. https://jira.example.com/rest/zapi/latest)",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :jira_username,
                               description: "JIRA user name to log in",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :jira_password,
                               description: "JIRA password to log in",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :version,
                               description: "Version of the app that tests run against",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :cycle,
                               description: "Test cycle name",
                                  optional: false,
                                 is_string: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :limit_by_project,
                               description: "Project name to limit links by. By default, all links are parsed, even if they belong to different JIRA projects",
                                  optional: true,
                                 is_string: true,
                                      type: String,
                             default_value: nil),
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
