require 'abstract_unit'

class CookiesTest < ActionController::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
      head :ok
    end

    def set_with_with_escapable_characters
      cookies["that & guy"] = "foo & bar => baz"
      head :ok
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def authenticate_for_fourteen_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      cookies["login"]     = "XJ-122"
      head :ok
    end

    def access_frozen_cookies
      cookies["will"] = "work"
      head :ok
    end

    def logout
      cookies.delete("user_name")
      head :ok
    end

    def delete_cookie_with_path
      cookies.delete("user_name", :path => '/beaten')
      head :ok
    end

    def authenticate_with_http_only
      cookies["user_name"] = { :value => "david", :httponly => true }
      head :ok
    end

    def authenticate_with_secure
      cookies["user_name"] = { :value => "david", :secure => true }
      head :ok
    end

    def set_permanent_cookie
      cookies.permanent[:user_name] = "Jamie"
      head :ok
    end

    def set_signed_cookie
      cookies.signed[:user_id] = 45
      head :ok
    end

    def raise_data_overflow
      cookies.signed[:foo] = 'bye!' * 1024
      head :ok
    end

    def tampered_cookies
      cookies[:tampered] = "BAh7BjoIZm9vIghiYXI%3D--123456780"
      cookies.signed[:tampered]
      head :ok
    end

    def set_permanent_signed_cookie
      cookies.permanent.signed[:remember_me] = 100
      head :ok
    end

    def delete_and_set_cookie
      cookies.delete :user_name
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def set_cookie_with_domain
      cookies[:user_name] = {:value => "rizwanreza", :domain => :all}
      head :ok
    end

    def delete_cookie_with_domain
      cookies.delete(:user_name, :domain => :all)
      head :ok
    end

    def set_cookie_with_domain_and_tld
      cookies[:user_name] = {:value => "rizwanreza", :domain => :all, :tld_length => 2}
      head :ok
    end

    def delete_cookie_with_domain_and_tld
      cookies.delete(:user_name, :domain => :all, :tld_length => 2)
      head :ok
    end

    def set_cookie_with_domains
      cookies[:user_name] = {:value => "rizwanreza", :domain => %w(example1.com example2.com .example3.com)}
      head :ok
    end

    def delete_cookie_with_domains
      cookies.delete(:user_name, :domain => %w(example1.com example2.com .example3.com))
      head :ok
    end

    def symbol_key
      cookies[:user_name] = "david"
      head :ok
    end

    def string_key
      cookies['user_name'] = "dhh"
      head :ok
    end

    def symbol_key_mock
      cookies[:user_name] = "david" if cookies[:user_name] == "andrew"
      head :ok
    end

    def string_key_mock
      cookies['user_name'] = "david" if cookies['user_name'] == "andrew"
      head :ok
    end

    def noop
      head :ok
    end
  end

  tests TestController

  def setup
    super
    @request.env["action_dispatch.secret_token"] = "b3c631c314c0bbca50c1b2843150fe33"
    @request.host = "www.nextangle.com"
  end

  def test_key_methods
    assert !request.cookie_jar.key?(:foo)
    assert !request.cookie_jar.has_key?("foo")

    request.cookie_jar[:foo] = :bar
    assert request.cookie_jar.key?(:foo)
    assert request.cookie_jar.has_key?("foo")
  end

  def test_setting_cookie
    get :authenticate
    assert_cookie_header "user_name=david; path=/"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_with_escapable_characters
    get :set_with_with_escapable_characters
    assert_cookie_header "that+%26+guy=foo+%26+bar+%3D%3E+baz; path=/"
    assert_equal({"that & guy" => "foo & bar => baz"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days_with_symbols
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_cookie_header "user_name=david; path=/; HttpOnly"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_secure
    @request.env["HTTPS"] = "on"
    get :authenticate_with_secure
    assert_cookie_header "user_name=david; path=/; secure"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_secure_in_development
    Rails.env.stubs(:development?).returns(true)
    get :authenticate_with_secure
    assert_cookie_header "user_name=david; path=/; secure"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_not_setting_cookie_with_secure
    get :authenticate_with_secure
    assert_not_cookie_header "user_name=david; path=/; secure"
    assert_not_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT\nlogin=XJ-122; path=/"
    assert_equal({"login" => "XJ-122", "user_name" => "david"}, @response.cookies)
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end

  def test_expiring_cookie
    get :logout
    assert_cookie_header "user_name=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
    assert_equal({"user_name" => nil}, @response.cookies)
  end

  def test_delete_cookie_with_path
    get :delete_cookie_with_path
    assert_cookie_header "user_name=; path=/beaten; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  def test_cookies_persist_throughout_request
    response = get :authenticate
    assert response.headers["Set-Cookie"] =~ /user_name=david/
  end

  def test_permanent_cookie
    get :set_permanent_cookie
    assert_match(/Jamie/, @response.headers["Set-Cookie"])
    assert_match(%r(#{20.years.from_now.utc.year}), @response.headers["Set-Cookie"])
  end

  def test_signed_cookie
    get :set_signed_cookie
    assert_equal 45, @controller.send(:cookies).signed[:user_id]
  end

  def test_accessing_nonexistant_signed_cookie_should_not_raise_an_invalid_signature
    get :set_signed_cookie
    assert_nil @controller.send(:cookies).signed[:non_existant_attribute]
  end

  def test_permanent_signed_cookie
    get :set_permanent_signed_cookie
    assert_match(%r(#{20.years.from_now.utc.year}), @response.headers["Set-Cookie"])
    assert_equal 100, @controller.send(:cookies).signed[:remember_me]
  end

  def test_delete_and_set_cookie
    get :delete_and_set_cookie
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_raise_data_overflow
    assert_raise(ActionDispatch::Cookies::CookieOverflow) do
      get :raise_data_overflow
    end
  end

  def test_tampered_cookies
    assert_nothing_raised do
      get :tampered_cookies
      assert_response :success
    end
  end

  def test_raises_argument_error_if_missing_secret
    assert_raise(ArgumentError, nil.inspect) {
      @request.env["action_dispatch.secret_token"] = nil
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, ''.inspect) {
      @request.env["action_dispatch.secret_token"] = ""
      get :set_signed_cookie
    }
  end

  def test_raises_argument_error_if_secret_is_probably_insecure
    assert_raise(ArgumentError, "password".inspect) {
      @request.env["action_dispatch.secret_token"] = "password"
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, "secret".inspect) {
      @request.env["action_dispatch.secret_token"] = "secret"
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, "12345678901234567890123456789".inspect) {
      @request.env["action_dispatch.secret_token"] = "12345678901234567890123456789"
      get :set_signed_cookie
    }
  end

  def test_cookie_with_all_domain_option
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com; path=/"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_australian_style_tld
    @request.host = "nextangle.com.au"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com.au; path=/"
  end

  def test_cookie_with_all_domain_option_using_uk_style_tld
    @request.host = "nextangle.co.uk"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.co.uk; path=/"
  end

  def test_cookie_with_all_domain_option_using_host_with_port
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_localhost
    @request.host = "localhost"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_all_domain_option_using_ipv4_address
    @request.host = "192.168.1.1"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_all_domain_option_using_ipv6_address
    @request.host = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_deleting_cookie_with_all_domain_option
    get :delete_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=; domain=.nextangle.com; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  def test_cookie_with_all_domain_option_and_tld_length
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com; path=/"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld_and_tld_length
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_host_with_port_and_tld_length
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_deleting_cookie_with_all_domain_option_and_tld_length
    get :delete_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=; domain=.nextangle.com; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  def test_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example1.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=example1.com; path=/"
  end

  def test_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_several_preset_domains_using_shared_domain
    @request.host = "example3.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.example3.com; path=/"
  end

  def test_deletings_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example2.com"
    get :delete_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=; domain=example2.com; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  def test_deletings_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    get :delete_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  
  def test_cookies_hash_is_indifferent_access
      get :symbol_key
      assert_equal "david", cookies[:user_name]
      assert_equal "david", cookies['user_name']
      get :string_key
      assert_equal "dhh", cookies[:user_name]
      assert_equal "dhh", cookies['user_name']
  end



  def test_setting_request_cookies_is_indifferent_access
    @request.cookies.clear
    @request.cookies[:user_name] = "andrew"
    get :string_key_mock
    assert_equal "david", cookies[:user_name]

    @request.cookies.clear
    @request.cookies['user_name'] = "andrew"
    get :symbol_key_mock
    assert_equal "david", cookies['user_name']
  end

  def test_cookies_retained_across_requests
    get :symbol_key
    assert_equal "user_name=david; path=/", @response.headers["Set-Cookie"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_nil @response.headers["Set-Cookie"]
    assert_equal "user_name=david", @request.env['HTTP_COOKIE']
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_nil @response.headers["Set-Cookie"]
    assert_equal "user_name=david", @request.env['HTTP_COOKIE']
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_can_be_cleared
    get :symbol_key
    assert_equal "user_name=david; path=/", @response.headers["Set-Cookie"]
    assert_equal "david", cookies[:user_name]

    @request.cookies.clear
    get :noop
    assert_nil @response.headers["Set-Cookie"]
    assert_nil @request.env['HTTP_COOKIE']
    assert_nil cookies[:user_name]

    get :symbol_key
    assert_equal "user_name=david; path=/", @response.headers["Set-Cookie"]
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_are_escaped
    @request.cookies[:user_ids] = '1;2'
    get :noop
    assert_equal "user_ids=1%3B2", @request.env['HTTP_COOKIE']
    assert_equal "1;2", cookies[:user_ids]
  end

  private
    def assert_cookie_header(expected)
      header = @response.headers["Set-Cookie"]
      if header.respond_to?(:to_str)
        assert_equal expected.split("\n").sort, header.split("\n").sort
      else
        assert_equal expected.split("\n"), header
      end
    end

    def assert_not_cookie_header(expected)
      header = @response.headers["Set-Cookie"]
      if header.respond_to?(:to_str)
        assert_not_equal expected.split("\n").sort, header.split("\n").sort
      else
        assert_not_equal expected.split("\n"), header
      end
    end
end

class CookiesIntegrationTest < ActionDispatch::IntegrationTest
  SessionKey = '_myapp_session'
  SessionSecret = 'b3c631c314c0bbca50c1b2843150fe33'

  class TestController < ActionController::Base
    def dont_set_cookies
      head :ok
    end

    def set_cookies
      cookies["that"] = "hello"
      head :ok
    end
  end

  def test_setting_cookies_raises_after_stream_back_to_client
    with_test_route_set do
      get '/set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar['alert'] = 'alert'
        cookies['alert'] = 'alert'
      }
    end
  end

  def test_setting_cookies_raises_after_stream_back_to_client_even_without_cookies
    with_test_route_set do
      get '/dont_set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar['alert'] = 'alert'
      }
    end
  end

  def test_setting_permanent_cookies_raises_after_stream_back_to_client
    with_test_route_set do
      get '/set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar.permanent['alert'] = 'alert'
        cookies['alert'] = 'alert'
      }
    end
  end

  def test_setting_permanent_cookies_raises_after_stream_back_to_client_even_without_cookies
    with_test_route_set do
      get '/dont_set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar.permanent['alert'] = 'alert'
      }
    end
  end

  def test_setting_signed_cookies_raises_after_stream_back_to_client
    with_test_route_set do
      get '/set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar.signed['alert'] = 'alert'
        cookies['alert'] = 'alert'
      }
    end
  end

  def test_setting_signed_cookies_raises_after_stream_back_to_client_even_without_cookies
    with_test_route_set do
      get '/dont_set_cookies'
      assert_raise(ActionDispatch::ClosedError) {
        request.cookie_jar.signed['alert'] = 'alert'
      }
    end
  end

  private

  # Overwrite get to send SessionSecret in env hash
  def get(path, parameters = nil, env = {})
    env["action_dispatch.secret_token"] ||= SessionSecret
    super
  end

  def with_test_route_set
    with_routing do |set|
      set.draw do
        match ':action', :to => CookiesIntegrationTest::TestController
      end

      @app = self.class.build_app(set) do |middleware|
        middleware.use ActionDispatch::Cookies
        middleware.delete "ActionDispatch::ShowExceptions"
      end

      yield
    end
  end
end
