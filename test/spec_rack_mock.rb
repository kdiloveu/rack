require 'yaml'
require 'rack/mock'
require 'rack/request'
require 'rack/response'

context "Rack::MockRequest" do
  App = lambda { |env|
    req = Rack::Request.new(env)

    env["mock.postdata"] = env["rack.input"].read
    if req.GET["error"]
      env["rack.errors"].puts req.GET["error"]
      env["rack.errors"].flush
    end

    Rack::Response.new(env.to_yaml,
                       req.GET["status"] || 200,
                       "Content-Type" => "text/yaml").finish
  }

  specify "should return a MockResponse" do
    res = Rack::MockRequest.new(App).get("")
    res.should.be.kind_of Rack::MockResponse
  end

  specify "should provide sensible defaults" do
    res = Rack::MockRequest.new(App).get("")

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "example.org"
    env["SERVER_PORT"].should.equal "80"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/"
    env["rack.url_scheme"].should.equal "http"
  end

  specify "should allow posting" do
    res = Rack::MockRequest.new(App).get("", :input => "foo")
    env = YAML.load(res.body)
    env["mock.postdata"].should.equal "foo"

    res = Rack::MockRequest.new(App).get("", :input => StringIO.new("foo"))
    env = YAML.load(res.body)
    env["mock.postdata"].should.equal "foo"
  end

  specify "should use all parts of an URL" do
    res = Rack::MockRequest.new(App).
      get("https://bla.example.org:9292/meh/foo?bar")
    res.should.be.kind_of Rack::MockResponse

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "bla.example.org"
    env["SERVER_PORT"].should.equal "9292"
    env["QUERY_STRING"].should.equal "bar"
    env["PATH_INFO"].should.equal "/meh/foo"
    env["rack.url_scheme"].should.equal "https"
  end

  specify "should behave valid according to the Rack spec" do
    lambda {
      res = Rack::MockRequest.new(App).
        get("https://bla.example.org:9292/meh/foo?bar", :lint => true)
    }.should.not.raise(Rack::Lint::LintError)
  end
end

context "Rack::MockResponse" do
  specify "should provide access to the HTTP status" do
    res = Rack::MockRequest.new(App).get("")
    res.should.be.successful
    res.should.be.ok

    res = Rack::MockRequest.new(App).get("/?status=404")
    res.should.not.be.successful
    res.should.be.client_error
    res.should.be.not_found

    res = Rack::MockRequest.new(App).get("/?status=501")
    res.should.not.be.successful
    res.should.be.server_error

    res = Rack::MockRequest.new(App).get("/?status=307")
    res.should.be.redirect

    res = Rack::MockRequest.new(App).get("/?status=201", :lint => true)
    res.should.be.empty
  end

  specify "should provide access to the HTTP headers" do
    res = Rack::MockRequest.new(App).get("")
    res.should.include "Content-Type"
    res.headers["Content-Type"].should.equal "text/yaml"
    res.original_headers["Content-Type"].should.equal "text/yaml"
    res["Content-Type"].should.equal "text/yaml"
    res.content_type.should.equal "text/yaml"
    res.content_length.should.be.nil
  end

  specify "should provide access to the HTTP body" do
    res = Rack::MockRequest.new(App).get("")
    res.body.should =~ /rack/
    res.should =~ /rack/
    res.should.match /rack/
  end

  specify "should provide access to the Rack errors" do
    res = Rack::MockRequest.new(App).get("/?error=foo", :lint => true)
    res.should.be.ok
    res.errors.should.not.be.empty
    res.errors.should.include "foo"
  end

  specify "should optionally make Rack errors fatal" do
    lambda {
      Rack::MockRequest.new(App).get("/?error=foo", :fatal => true)
    }.should.raise(Rack::MockRequest::FatalWarning)
  end
end