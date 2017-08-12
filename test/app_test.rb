ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'fileutils'


require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    {"rack.session" => {username: 'admin', password: 'secret'}}
  end

  def session
    last_request.env["rack.session"]
  end

  def test_contents
    create_document "about.txt"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_document
    create_document "about.txt", "Hello"

    get '/about.txt'

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Hello"
  end

  def test_false_file
    get '/random.ext',{}, {"rack.session" => {username: "admin", password: "secret"}}
    assert_equal 302, last_response.status
    assert_equal "random.ext does not exist", session[:message]

    get last_response['Location']

    assert_equal 200, last_response.status
  end

  def test_md_file
    create_document "/about.md", "#Ruby is..."
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_edit_page
    create_document '/changes.txt'
    get '/changes.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_submitting_edits
    post '/changes.txt', {new_content: "Hello minitest"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated!", session[:message]


    get last_response['Location'], {}, admin_session
    
    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Hello minitest"

  end

  def test_new_file
    get '/document/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<button"
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "Enter name of new document"
  end

  def test_submit_new_file
    post '/document/new', {new_doc: "test.txt"}, admin_session

    assert_equal "test.txt has been created", session[:message]

    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt"
  end

  def test_create_invalid_file
    post '/document/new', {new_doc: "test"}, admin_session

    assert_includes last_response.body, "File extension must be .md or .txt"
  end

  def test_delete_file
    create_document "/test.txt"

    post '/test.txt/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt was deleted", session[:message]

    get last_response['Location'], {}, admin_session
    assert_equal 200, last_response.status
  end

  def test_redirect_login_page_if_not_signed_in
    get '/'

    assert_equal 302, last_response.status
    get last_response['Location']
    assert_nil session[:username]

  end

  def test_sign_in_correct_credentials
    post "/users/signin", {:username => "admin", :password => "secret"}
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign out"

    post "/users/signout"
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'Username'
    assert_includes last_response.body, 'Password'
  end

  def test_sign_in_incorrect_credentials
    post "/users/signin", {username: "something", password: "something"}

    assert_nil session[:username]
    assert_equal 422, last_response.status

    get '/'

    assert_equal 302, last_response.status
  end

  # Ensures that non-signed in users are redirected if making sensitive requests
  # blocking access to the form used to submit changes does not preclude making a
  # post request with the appropriate information to submit the change directly
  # without use of the convenient form used to make changes. Therefore access must be
  # blocked for both get and post requests

  def test_block_access_edit_form
    create_document "test.txt"
    get '/test.txt/edit'

    assert_equal "You must be signed in to do that", session[:message]
    assert_equal 302, last_response.status
    assert_nil session[:username]
  end

  def test_block_access_submit_edits
    post '/test.txt'

    assert_equal "You must be signed in to do that", session[:message]
    assert_equal 302, last_response.status
    assert_nil session[:username]
  end

  def test_block_access_new_document_form
    get '/document/new'

    assert_equal "You must be signed in to do that", session[:message]
    assert_equal 302, last_response.status
    assert_nil session[:username]

  end

  def test_block_access_submit_new_document
    post '/document/new', {new_doc: "file.txt"}

    assert_equal "You must be signed in to do that", session[:message]
    assert_equal 302, last_response.status
    assert_nil session[:username]
  end

  def test_block_access_delete_document
    create_document "test.txt"
    post '/test.txt/delete'

    assert_equal "You must be signed in to do that", session[:message]
    assert_equal 302, last_response.status
    assert_nil session[:username]
  end
end