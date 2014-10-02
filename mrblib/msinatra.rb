begin; require 'mruby-io'; require 'mruby-socket'; require 'mruby-http'; rescue Exception; end

module Sinatic
  @content_type = nil
  @options = {:host => '127.0.0.1', :port => 8888}
  @routes = { 'GET' => [], 'POST' => [] }
  @shutdown = false
  def self.route(method, path, opts, &block)
    @routes[method] << [path, opts, block]
  end
  def self.content_type(type)
    @content_type = type
  end
  def self.set(key, value)
    @options[key] = value
  end
  def self.do(r)
    route = @routes[r.method].select {|path| path[0] == r.path}
    if route.size > 0
      param = {}
      if r.headers['Content-Type'] == 'application/x-www-form-urlencoded'
        r.body.split('&').each do |x|
          tokens = x.split('=', 2)
          if tokens && tokens.size == 2
            param[tokens[0]] = HTTP::URL::decode(tokens[1])
          end
        end
      end
      @content_type = 'text/html; charset=utf-8'
      bb = route[0][2].call(r, param)
      if bb.class.to_s == 'Array'
        bb = bb[0]
      end
      return [
        "HTTP/1.0 200 OK",
        "Content-Type: #{@content_type}",
        "Content-Length: #{bb.size}",
        "", ""].join("\r\n") + bb
    end
    if r.method == 'GET' && r.path
      f = nil
      begin
        file = r.path + (r.path[-1] == '/' ? 'index.html' : '')
        f = File.open("static#{file}")
        bb = f.read
        ext = file.split(".")[-1]
        ctype = ['txt', 'html', 'css'].index(ext) ? "text/" + ext :
                ['js'].index(ext) ? "text/javascript" :
                 'application/octet-stream'
        return [
            "HTTP/1.0 200 OK",
            "Content-Type: #{ctype}; charset=utf-8",
            "Content-Length: #{bb.size}",
            "", ""].join("\r\n") + bb
      rescue File::NoFileError
        return [
            "HTTP/1.0 404 Not Found",
            "Content-Type: text/plain; charset=utf-8",
            "", "Not Found"].join("\r\n")
      rescue RuntimeError
      ensure
        f.close if f
      end
    end
    return "HTTP/1.0 404 Not Found\r\nContent-Length: 10\r\n\r\nNot Found\n"
  end
  def self.shutdown?
    @shutdown
  end
  def self.shutdown
    @shutdown = true
  end
  def self.run(options = {})
    s = TCPServer.new(@options[:host], @options[:port].to_i)
    while true
      c = s.accept
      begin
        line = ''
        lastch = ''
        while true
          ch = c.recv(1)
          line += ch
          break if line.rindex("\r\n\r\n") != nil
        end
        lines = line.split("\r\n")
        method, path, proto = lines.shift.split(" ", 3)
        body = ''
        if method == 'POST'
          header = {}
          lines.map {|x| x.split(":", 2)}.each do |x|
            header[x[0]] = x[1]
          end
          length = header["Content-Length"]
          if length.nil?
            begin
              while true
                body += c.read
              end
            rescue
            end
          else
            body += c.read(length)
          end
        end
        r = HTTP::Parser.new.parse_request(line + body)
        r.body = body
        bb = ::Sinatic.do(r)
        c.send(bb, 0)
      rescue RuntimeError
        c.send("HTTP/1.0 500 Internal Server Error\r\nContent-Length: 22\r\n\r\nInternal Server Error\n", 0)
      ensure
        c.close
      end
    end
  end
end

module Kernel
  def get(path, opts={}, &block)
    ::Sinatic.route 'GET', path, opts, &block
  end
  def post(path, opts={}, &block)
    ::Sinatic.route 'POST', path, opts, &block
  end
  def content_type(type)
    ::Sinatic.content_type type
  end
  def set(key, value)
    ::Sinatic.set key, type
  end
end

# vim: set fdm=marker:
