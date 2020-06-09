ENV["RAILS_ENV"] = "test"
require "knapsack_pro"
KnapsackPro::Adapters::RSpecAdapter.bind

require "spec_helper"

require File.expand_path("../config/environment", __dir__)
require "rspec/rails"
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Add additional requires below this line. Rails is not loaded until this point!

require "percy"
require "pundit/matchers"
require "pundit/rspec"
require "webmock/rspec"
require "test_prof/recipes/rspec/before_all"
require "test_prof/recipes/rspec/let_it_be"
require "test_prof/recipes/rspec/sample"
require "sidekiq/testing"
require "validate_url/rspec_matcher"

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
Dir[Rails.root.join("spec/system/shared_examples/**/*.rb")].sort.each { |f| require f }
Dir[Rails.root.join("spec/models/shared_examples/**/*.rb")].sort.each { |f| require f }
Dir[Rails.root.join("spec/jobs/shared_examples/**/*.rb")].sort.each { |f| require f }
Dir[Rails.root.join("spec/workers/shared_examples/**/*.rb")].sort.each { |f| require f }
Dir[Rails.root.join("spec/initializers/shared_examples/**/*.rb")].sort.each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

# Disable internet connection with Webmock
# allow browser websites, so that "webdrivers" can access their binaries
# see <https://github.com/titusfortner/webdrivers/wiki/Using-with-VCR-or-WebMock>
allowed_sites = [
  "https://chromedriver.storage.googleapis.com",
  "https://github.com/mozilla/geckodriver/releases",
  "https://selenium-release.storage.googleapis.com",
  "https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver",
  "api.knapsackpro.com",
]
WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_sites)

RSpec::Matchers.define_negated_matcher :not_change, :change

Rack::Attack.enabled = false

# `browser`, a dependency of `field_test`, starting from version 3.0
# considers the empty user agent a bot, which will fail tests as we
# explicitly configure field tests to exclude bots
# see https://github.com/fnando/browser/blob/master/CHANGELOG.md#300
Browser::Bot.matchers.delete(Browser::Bot::EmptyUserAgentMatcher)

module Devise
  module Test
    module IntegrationHelpers
      def sign_in(resource, scope: nil)
        scope ||= Devise::Mapping.find_scope!(resource)
        puts("SIGN_IN user SCOPE: #{scope}")
        login_as(resource, scope: scope)
      end
    end
  end
end

module Warden
  module Test
    module Helpers
      def login_as(user, opts = {})
        Warden.on_next_request do |proxy|
          opts[:event] ||= :authentication
          puts("USER: #{user} OPTS: #{opts}")
          proxy.set_user(user, opts)
        end
      end
    end
  end
end

module Warden
  class Proxy
    def set_user(user, opts = {})
      scope = (opts[:scope] ||= @config.default_scope)

      # Get the default options from the master configuration for the given scope
      opts = (@config[:scope_defaults][scope] || {}).merge(opts)
      opts[:event] ||= :set_user
      @users[scope] = user

      if opts[:store] != false && opts[:event] != :fetch
        options = env[ENV_SESSION_OPTIONS]
        if options
          if options.frozen?
            env[ENV_SESSION_OPTIONS] = options.merge(renew: true).freeze
          else
            options[:renew] = true
          end
        end
        session_serializer.store(user, scope)
      end

      run_callbacks = opts.fetch(:run_callbacks, true)
      manager._run_callbacks(:after_set_user, user, self, opts) if run_callbacks

      r = @users[scope]
      puts("SET_USER RESULT: #{r}")
      r
    end
  end
end

# module Warden
#   module Hooks

#     # Hook to _run_callbacks asserting for conditions.
#     def _run_callbacks(kind, *args) #:nodoc:
#       options = args.last # Last callback arg MUST be a Hash

#       send("_#{kind}").each do |callback, conditions|
#         invalid = conditions.find do |key, value|
#           value.is_a?(Array) ? !value.include?(options[key]) : (value != options[key])
#         end

#         callback.call(*args) unless invalid
#       end
#     end
#   end
# end

# module Pundit
#   class << self
#     # Retrieves the policy for the given record, initializing it with the
#     # record and user and finally throwing an error if the user is not
#     # authorized to perform the given action.
#     #
#     # @param user [Object] the user that initiated the action
#     # @param record [Object] the object we're checking permissions of
#     # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`)
#     # @param policy_class [Class] the policy class we want to force use of
#     # @raise [NotAuthorizedError] if the given query method returned false
#     # @return [Object] Always returns the passed object record
#     def authorize(user, record, query, policy_class: nil)
#       policy = policy_class ? policy_class.new(user, record) : policy!(user, record)

#       raise NotAuthorizedError, query: query, record: record, policy: policy unless policy.public_send(query)

#       record.is_a?(Array) ? record.last : record
#     end
#   end

#   protected

#   # @return [Boolean] whether authorization has been performed, i.e. whether
#   #                   one {#authorize} or {#skip_authorization} has been called
#   def pundit_policy_authorized?
#     !!@_pundit_policy_authorized
#   end

#   # Raises an error if authorization has not been performed, usually used as an
#   # `after_action` filter to prevent programmer error in forgetting to call
#   # {#authorize} or {#skip_authorization}.
#   #
#   # @see https://github.com/varvet/pundit#ensuring-policies-and-scopes-are-used
#   # @raise [AuthorizationNotPerformedError] if authorization has not been performed
#   # @return [void]
#   def verify_authorized
#     raise AuthorizationNotPerformedError, self.class unless pundit_policy_authorized?
#   end

#   # Retrieves the policy for the given record, initializing it with the record
#   # and current user and finally throwing an error if the user is not
#   # authorized to perform the given action.
#   #
#   # @param record [Object] the object we're checking permissions of
#   # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`).
#   #   If omitted then this defaults to the Rails controller action name.
#   # @param policy_class [Class] the policy class we want to force use of
#   # @raise [NotAuthorizedError] if the given query method returned false
#   # @return [Object] Always returns the passed object record
#   def authorize(record, query = nil, policy_class: nil)
#     puts "AUTHORIZE #{record}"
#     puts "ACTION NAME #{action_name}"
#     query ||= "#{action_name}?"

#     @_pundit_policy_authorized = true

#     policy = policy_class ? policy_class.new(pundit_user, record) : policy(record)

#     raise NotAuthorizedError, query: query, record: record, policy: policy unless policy.public_send(query)

#     record.is_a?(Array) ? record.last : record
#   end
# end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.include ApplicationHelper
  config.include ActionMailer::TestHelper
  config.include ActiveJob::TestHelper
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include FactoryBot::Syntax::Methods
  config.include OmniauthHelpers
  config.include SidekiqTestHelpers
  config.include ElasticsearchHelpers

  config.before(:suite) do
    Search::Cluster.recreate_indexes
  end

  config.before do
    # Worker jobs shouldn't linger around between tests
    Sidekiq::Worker.clear_all
  end

  config.around(:each, elasticsearch_reset: true) do |example|
    Search::Cluster.recreate_indexes
    example.run
    Search::Cluster.recreate_indexes
  end

  config.around(:each, :elasticsearch) do |ex|
    klasses = Array.wrap(ex.metadata[:elasticsearch]).map do |search_class|
      Search.const_get(search_class)
    end
    klasses.each { |klass| clear_elasticsearch_data(klass) }
    ex.run
  end

  config.around(:each, throttle: true) do |example|
    Rack::Attack.enabled = true
    example.run
    Rack::Attack.enabled = false
  end

  config.after do
    SiteConfig.clear_cache
  end

  # Only turn on VCR if :vcr is included metadata keys
  config.around do |ex|
    if ex.metadata.key?(:vcr)
      ex.run
    else
      VCR.turned_off { ex.run }
    end
  end

  # Allow testing with Stripe's test server. BE CAREFUL
  if config.filter_manager.inclusions.rules.include?(:live)
    WebMock.allow_net_connect!
    StripeMock.toggle_live(true)
    Rails.logger.info("Running **live** tests against Stripe...")
  end

  config.before do
    stub_request(:any, /res.cloudinary.com/).to_rack("dsdsdsds")

    stub_request(:post, /api.fastly.com/).
      to_return(status: 200, body: "".to_json, headers: {})

    stub_request(:post, /api.bufferapp.com/).
      to_return(status: 200, body: { fake_text: "so fake" }.to_json, headers: {})

    # for twitter image cdn
    stub_request(:get, /twimg.com/).
      to_return(status: 200, body: "", headers: {})

    stub_request(:any, /api.mailchimp.com/).
      to_return(status: 200, body: "", headers: {})

    stub_request(:any, /dummyimage.com/).
      to_return(status: 200, body: "", headers: {})

    stub_request(:post, "http://www.google-analytics.com/collect").
      to_return(status: 200, body: "", headers: {})

    stub_request(:any, /robohash.org/).
      with(headers:
            {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "User-Agent" => "Ruby"
            }).to_return(status: 200, body: "", headers: {})
    # Prevent Percy.snapshot from trying to hit the agent while not in use

    allow(Percy).to receive(:snapshot)
  end

  config.after do
    Timecop.return
  end

  config.after(:suite) do
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        "api.knapsackpro.com",
      ],
    )
  end

  OmniAuth.config.test_mode = true
  OmniAuth.config.logger = Rails.logger

  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Explicitly set a seed and time to ensure deterministic Percy snapshots.
  # config.around(:each, percy: true) do |example|
  #   Timecop.freeze("2020-05-13T10:00:00Z")
  #   prev_random_seed = Faker::Config.random
  #   Faker::Config.random = Random.new(42)

  #   example.run

  #   Faker::Config.random = prev_random_seed
  #   Timecop.return
  # end
end
