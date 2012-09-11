require 'digest/md5'
require 'action_view'

class NegativeCaptcha
  attr_accessor :fields,
    :values,
    :secret,
    :spinner,
    :message,
    :timestamp,
    :error

  TEST_MODE = false
  def self.test_mode=(value)
    const_set("TEST_MODE", value)
  end

  def initialize(opts)
    self.secret = opts[:secret] ||
      Digest::MD5.hexdigest("this_is_a_secret_key")

    if opts.has_key?(:params)
      self.timestamp = opts[:params][:timestamp] || Time.now.to_i
    else
      self.timestamp = Time.now.to_i
    end

    self.spinner = Digest::MD5.hexdigest(
      ([timestamp, secret] + Array(opts[:spinner])).join('-')
    )

    self.message = opts[:message] || <<-MESSAGE
Please try again.
This usually happens because an automated script attempted to submit this form.
    MESSAGE

    self.fields = opts[:fields].inject({}) do |hash, field_name|
      hash[field_name] = TEST_MODE ? "test-#{field_name}" : Digest::MD5.hexdigest(
        [field_name, spinner, secret].join('-')
      )

      hash
    end

    self.values = {}
    self.error = "No params provided"

    if opts[:params] && (opts[:params][:spinner] || opts[:params][:timestamp])
      process(opts[:params])
    end
  end

  def [](name)
    fields[name]
  end

  def valid?
    error.nil? || error == "" || error.empty?
  end

  def process(params)
    timestamp_age = (Time.now.to_i - params[:timestamp].to_i).abs

    if params[:timestamp].nil? || timestamp_age > 86400
      self.error = "Error: Invalid timestamp.  #{message}"
    elsif params[:spinner] != spinner
      self.error = "Error: Invalid spinner.  #{message}"
    elsif fields.keys.detect {|name| params[name] && params[name].length > 0}
      self.error = <<-ERROR
Error: Hidden form fields were submitted that should not have been. #{message}
      ERROR

      false
    else
      self.error = ""

      fields.each do |name, encrypted_name|
        self.values[name] = params[encrypted_name]
      end
    end
  end
end


require 'negative_captcha/view_helpers'
require "negative_captcha/form_builder"

class ActionView::Base
  include NegativeCaptchaHelpers
end
