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

  def sign_in
    post "/users/signin", username: 'admin', password: 'secret'
  end

  def test_contents
    sign_in
    create_document "about.txt"
    create_document "changes.txt"

    get "/"

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
    sign_in
    get '/random.ext'

    assert_equal 302, last_response.status


    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "random.ext does not exist"
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
    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_submitting_edits
    sign_in
    post '/changes.txt', new_content: "Hello minitest"
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, "changes.txt has been updated!"

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Hello minitest"

  end

  def test_new_file
    get '/document/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<button"
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "Enter name of new document"
  end

  def test_submit_new_file
    post '/document/new', new_doc: "test.txt"

    get last_response['Location']
    assert_includes last_response.body, "test.txt has been created"

    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt"
  end

  def test_error_false_file
    post '/document/new', new_doc: "test"

    assert_includes last_response.body, "File extension must be .md or .txt"
  end

  def test_delete_file
    sign_in
    create_document "/test.txt"
    post '/test.txt/delete'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt was deleted"
  end

  def test_redirect_login_page_if_not_signed_in
    get '/'

    assert_equal 302, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"

  end

  def test_sign_in_correct_credentials
    post "/users/signin", username: "admin", password: "secret"

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "Sign out"

    post "/users/signout"
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'Username'
    assert_includes last_response.body, 'Password'
  end

  def test_sign_in_incorrect_credentials
    post "/users/signin", username: "something", password: "something"

    assert_includes last_response.body, "Invalid credentials"
    assert_equal 422, last_response.status
  end

end