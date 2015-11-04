class VNCTunnel
  attr_accessor :host, :port
  @uri              = nil
  @srv_socket       = nil
  @client_socket    = nil
  @read_from_server = nil

  def initialize(full_url)
    @uri = URI(full_url)
    logger.info(full_url)
    self.host = 'localhost'
    s         = TCPServer.new('127.0.0.1', 0)
    self.port = s.addr[1]
    s.close
    @read_from_server = true
  end

  def start
    client_srv = TCPServer.new('127.0.0.1', port)
    thr        = Thread.new do
      req         = "CONNECT #{@uri.path}?#{@uri.query} HTTP/1.1\r\n\r\n"
      @srv_socket = TCPSocket.open(@uri.host, 80)
      @srv_socket.print req
      header = @srv_socket.readline
      if header == "HTTP/1.1 200 OK\r\n"
        @srv_socket.each_line do |line|
          break if line == "\r\n"
        end
        listen client_srv
      else
        logger.error "Cannot connect to the conosle located at #{uri} reason: #{header}"
        fail "Cannot connect to the console located at #{uri} reason: #{header}"
      end
    end
  end

  def logger
    Rails.logger
  end

  private

  def listen(client_srv)
    @client_socket = client_srv.accept
    logger.debug 'VNCTunnel Client: client accepted'
    server_listen_thr = Thread.new do
      listen_from_server
    end
    begin
      loop do
        begin
          data = @client_socket.read_nonblock(1024)
          break if data.nil?
          @srv_socket.write(data)
        rescue IO::WaitReadable => e
          IO.select([@client_socket])
          retry
        end
      end
    rescue EOFError
    rescue Exception => e
      logger.error "VNCTunnel Client: unexpected exception #{e}"
    ensure
      @read_from_server = false
      @client_socket.close
      @srv_socket.close
    end
    logger.debug 'VNCTunnel Client is stopping'
  end

  def listen_from_server
    logger.debug 'VNCTunnel Server is listening'
    begin
      while @read_from_server
        begin
          data = @srv_socket.read_nonblock(1024)
          @client_socket.write(data)
        rescue IO::WaitReadable => e
          retry unless (IO.select([@srv_socket], nil, nil, 60)).nil?
        end
      end
    rescue EOFError
    rescue Exception => e
      logger.error "VNCTunnel Server: unexpected exception #{e}"
    end
    logger.debug('VNCTunnel Server is stopping')
  end
end
