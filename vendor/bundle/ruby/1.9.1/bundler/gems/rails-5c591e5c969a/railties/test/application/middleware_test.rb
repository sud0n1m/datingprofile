require 'isolation/abstract_unit'
require 'stringio'

module ApplicationTests
  class MiddlewareTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "default middleware stack" do
      boot!

      assert_equal [
        "ActionDispatch::Static",
        "Rack::Lock",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "Rack::MethodOverride",
        "Rails::Rack::Logger", # must come after Rack::MethodOverride to properly log overridden methods
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::RemoteIp",
        "Rack::Sendfile",
        "ActionDispatch::Reloader",
        "ActionDispatch::Callbacks",
        "ActiveRecord::ConnectionAdapters::ConnectionManagement",
        "ActiveRecord::QueryCache",
        "ActionDispatch::Cookies",
        "ActionDispatch::Session::CookieStore",
        "ActionDispatch::Flash",
        "ActionDispatch::ParamsParser",
        "ActionDispatch::Head",
        "Rack::ConditionalGet",
        "Rack::ETag",
        "ActionDispatch::BestStandardsSupport"
      ], middleware
    end

    test "Rack::Cache is present when action_controller.perform_caching is set" do
      add_to_config "config.action_controller.perform_caching = true"

      boot!

      assert_equal "Rack::Cache", middleware.first
    end

    test "Rack::SSL is present when force_ssl is set" do
      add_to_config "config.force_ssl = true"
      boot!
      assert middleware.include?("Rack::SSL")
    end

    test "removing Active Record omits its middleware" do
      use_frameworks []
      boot!
      assert !middleware.include?("ActiveRecord::ConnectionAdapters::ConnectionManagement")
      assert !middleware.include?("ActiveRecord::QueryCache")
      assert !middleware.include?("ActiveRecord::IdentityMap::Middleware")
    end

    test "removes lock if allow concurrency is set" do
      add_to_config "config.allow_concurrency = true"
      boot!
      assert !middleware.include?("Rack::Lock")
    end

    test "removes static asset server if serve_static_assets is disabled" do
      add_to_config "config.serve_static_assets = false"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "can delete a middleware from the stack" do
      add_to_config "config.middleware.delete ActionDispatch::Static"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "includes show exceptions even action_dispatch.show_exceptions is disabled" do
      add_to_config "config.action_dispatch.show_exceptions = false"
      boot!
      assert middleware.include?("ActionDispatch::ShowExceptions")
    end

    test "removes ActionDispatch::Reloader if cache_classes is true" do
      add_to_config "config.cache_classes = true"
      boot!
      assert !middleware.include?("ActionDispatch::Reloader")
    end

    test "use middleware" do
      use_frameworks []
      add_to_config "config.middleware.use Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.last
    end

    test "insert middleware after" do
      add_to_config "config.middleware.insert_after ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.second
    end

    test "RAILS_CACHE does not respond to middleware" do
      add_to_config "config.cache_store = :memory_store"
      boot!
      assert_equal "Rack::Runtime", middleware.third
    end

    test "RAILS_CACHE does respond to middleware" do
      boot!
      assert_equal "Rack::Runtime", middleware.fourth
    end

    test "identity map is inserted" do
      add_to_config "config.active_record.identity_map = true"
      boot!
      assert middleware.include?("ActiveRecord::IdentityMap::Middleware")
    end

    test "insert middleware before" do
      add_to_config "config.middleware.insert_before ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.first
    end

    # ConditionalGet + Etag
    test "conditional get + etag middlewares handle http caching based on body" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          if params[:nothing]
            render :text => ""
          else
            render :text => "OMG"
          end
        end
      end

      etag = "5af83e3196bf99f440f31f2e1a6c9afe".inspect

      get "/"
      assert_equal 200, last_response.status
      assert_equal "OMG", last_response.body
      assert_equal "text/html; charset=utf-8", last_response.headers["Content-Type"]
      assert_equal "max-age=0, private, must-revalidate", last_response.headers["Cache-Control"]
      assert_equal etag, last_response.headers["Etag"]

      get "/", {}, "HTTP_IF_NONE_MATCH" => etag
      assert_equal 304, last_response.status
      assert_equal "", last_response.body
      assert_equal nil, last_response.headers["Content-Type"]
      assert_equal "max-age=0, private, must-revalidate", last_response.headers["Cache-Control"]
      assert_equal etag, last_response.headers["Etag"]

      get "/?nothing=true"
      puts last_response.body
      assert_equal 200, last_response.status
      assert_equal "", last_response.body
      assert_equal "text/html; charset=utf-8", last_response.headers["Content-Type"]
      assert_equal "no-cache", last_response.headers["Cache-Control"]
      assert_equal nil, last_response.headers["Etag"]
    end

    # Show exceptions middleware
    test "show exceptions middleware filter backtrace before logging" do
      my_middleware = Struct.new(:app) do
        def call(env)
          raise "Failure"
        end
      end

      make_basic_app do |app|
        app.config.middleware.use my_middleware
      end

      stringio = StringIO.new
      Rails.logger = Logger.new(stringio)

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_no_match(/action_dispatch/, stringio.string)
    end

    private

      def boot!
        require "#{app_path}/config/environment"
      end

      def middleware
        AppTemplate::Application.middleware.map(&:klass).map(&:name)
      end
  end
end
