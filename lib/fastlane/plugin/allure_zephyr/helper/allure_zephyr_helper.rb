require 'fastlane_core/ui/ui'
require 'HTTParty'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class AllureZephyrHelper
      def initialize(project:, jira_api:, zephyr_api:, credentials:, report_path:, limit_by_project: nil)
        @tests = Hash.new
        @project = project
        @jira_api = jira_api
        @zephyr_api = zephyr_api
        @credentials = credentials
        get_all_statuses(report_path: report_path, limit_by_project: limit_by_project)
      end

      def get_all_statuses(report_path:, limit_by_project: nil)
        UI.message("Getting statuses of all tests from '#{report_path}'...")
        regex_status = /status": "(\w+)"/
        regex_url = limit_by_project.nil? ? /url.*\/([\w\d\-]+)"/ : /url.*(#{limit_by_project}-\d+)/
        pattern_links = "links"
        pattern_links_end = "]"

        path = "#{report_path}/data/test-cases"

        Dir.each_child(path) do |file|
          status = nil
          links_found = nil

          IO.foreach("#{path}/#{file}") do |line|
            if status.nil?
              status_match = line.match(regex_status)
              status = status_match[1].to_sym unless status_match.nil?
            elsif links_found.nil?
              links_found = true if line.include?(pattern_links)
            else
              url_match = line.match(regex_url)
              unless url_match.nil?
                key = url_match[1]
                @tests[key] = [status, nil] if @tests[key].nil? || (@tests[key][0] != status && @tests[key][0] == :passed)
                break if line.include?(pattern_links_end)
              end
            end
          end
        end
      end

      def execute_all(version:, cycle:, cloned_cycle_id:, build:, environment:, description:)
        statuses = Hash.new

        version_id = get_version_id(version_name: version)
        cycle_id = get_cycle_id(cycle_name: cycle,  version_id: version_id)
        if cycle_id.nil?
          create_cycle(cycle_name: cycle, version_id: version_id, cloned_cycle_id: cloned_cycle_id, build: build, environment: environment, description: description)
          cycle_id = get_cycle_id(cycle_name: cycle,  version_id: version_id)
          UI.user_error!("Can't get '#{cycle}' cycle identifer after successful creation.") if cycle_id.nil?
        end

        @tests.each do |ticket, value|
          execution = create_execution(
            ticket_number: ticket, 
            cycle_id: cycle_id, 
            version_id: version_id
          )
          @tests[ticket][1] = execution
          statuses[value[0]] = [] if statuses[value[0]].nil?
          statuses[value[0]] << execution
        end

        statuses.each do |status, executions|
          case status
          when :passed
            status_code = 1
          when :failed
            status_code = 2
          else
            status_code = 5
          end
          UI.message("Setting execution status for all '#{status}' tests...")
          execute(executions: executions, status: status_code)
        end
      end

      def create_execution(ticket_number:, cycle_id:, version_id:)
        UI.message("Creating execution for #{ticket_number}...")
        path = "#{@zephyr_api}/execution"

        ticket_id = get_ticket_id(ticket_number: ticket_number)
        body = {
          cycleId: cycle_id,
          issueId: ticket_id,
          projectId: @project,
          versionId: version_id,
        }
      
        response = HTTParty.post(path, { basic_auth: @credentials, headers: { "Content-Type": "application/json" }, body: body.to_json })
        UI.user_error!("Can't create execution for #{cycle_id} cycle. Expected code 200, got #{response.code}") unless response.code == 200
        parsed = JSON.parse(response.body)

        return parsed.keys[0]
      end

      def execute(executions:, status:)
        path = "#{@zephyr_api}/execution/updateBulkStatus"

        body = {
          executions: executions,
          status: status
        }

        response = HTTParty.put(path, { basic_auth: @credentials, headers: { "Content-Type": "application/json" }, body: body.to_json })
        UI.user_error!("Can't create execution for #{cycle_id} cycle. Expected code 200, got #{response.code}") unless response.code == 200
      end

      def get_version_id(version_name:)
        UI.message("Getting ID of version named '#{version_name}'...")
        return -1 if version_name == "Unscheduled"
      
        path = "#{@jira_api}/project/#{@project}/versions"
      
        response = HTTParty.get(path, { basic_auth: @credentials })
        UI.user_error!("Can't get versions of project #{@project}. Expected code 200, got #{response.code}") unless response.code == 200
        parsed = JSON.parse(response.body)
      
        parsed.each do |version|
          return version["id"] if version["name"] == version_name
        end
      
        UI.user_error!("Version '#{version_name}' couldn't be found!")
      end

      def get_cycle_id(cycle_name:, version_id:)
        UI.message("Checking if '#{cycle_name}' cycle already exists...")
        path = "#{@zephyr_api}/cycle?projectId=#{@project}&versionId=#{version_id}"
      
        response = HTTParty.get(path, { basic_auth: @credentials })
        UI.user_error!("Can't get cycles of project #{@project} with version #{version_id}. Expected code 200, got #{response.code}") unless response.code == 200
        parsed = JSON.parse(response.body)
      
        parsed.each do |id, cycle|
          next if id == "recordsCount"
          return id if cycle["name"] == cycle_name
        end
      
        return nil
      end

      def create_cycle(cycle_name:, version_id:, cloned_cycle_id:, build:, environment:, description:)
        UI.message("Creating cycle '#{cycle_name}'...")
        path = "#{@zephyr_api}/cycle"
      
        body = {
          clonedCycleId: cloned_cycle_id,
          name: cycle_name,
          build: build,
          environment: environment,
          description: description,
          projectId: @project,
          versionId: version_id,
          startDate: '',
          endDate: '',
          cloneCustomFields: false
        }
      
        response = HTTParty.post(path, { basic_auth: @credentials, headers: { "Content-Type": "application/json" }, body: body.to_json })
        UI.user_error!("Can't create cycle '#{cycle_name}'. Expected code 200, got #{response.code}") unless response.code == 200
        parsed = JSON.parse(response.body)
        jobProgressToken = parsed['jobProgressToken']
        if !jobProgressToken.nil?
          wait_for_job_progress(token: jobProgressToken)
        end
      end
      
      def get_ticket_id(ticket_number:)
        path = "#{@jira_api}/issue/#{ticket_number}"
      
        response = HTTParty.get(path, { basic_auth: @credentials })
        UI.user_error!("Can't get ticket ID of '#{ticket_number}'. Expected code 200, got #{response.code}") unless response.code == 200
        parsed = JSON.parse(response.body)
      
        return parsed["id"]
      end
      
      def wait_for_job_progress(token:)
        start = Time.now
        loop do
          response = HTTParty.get("#{@zephyr_api}/execution/jobProgress/#{token}", { basic_auth: @credentials, headers: { "Content-Type": "application/json" }})
          parsed = JSON.parse(response.body)
          progress = parsed['progress']
          break if progress == 1.0
          timeWaiting = Time.now - start
          UI.user_error!("Waiting for job with token #{token} timed out after #{timeWaiting} seconds.") if timeWaiting >= (ENV['ALLURE_ZEPHYR_PULLING_TIMEOUT'].to_f || 30.0)
          sleep(ENV['ALLURE_ZEPHYR_PULLING_INTERVAL'].to_f || 2.0)
        end
      end
    end
  end
end
