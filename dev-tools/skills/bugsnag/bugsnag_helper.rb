#!/usr/bin/env ruby

require_relative 'bugsnag_api_client'

class BugsnagHelper
  def initialize
    @client = BugsnagApiClient.new
  end

  def list_errors(limit: 20, status: nil, severity: nil)
    @client.list_errors(limit: limit, status: status, severity: severity)
  end

  def get_error_details(error_id)
    @client.get_error_details(error_id)
  end

  def resolve_error(error_id)
    @client.resolve_error(error_id)
  end

  def get_error_events(error_id, limit: 10)
    @client.get_error_events(error_id, limit: limit)
  end

  def analyze_errors
    @client.analyze_errors
  end
end