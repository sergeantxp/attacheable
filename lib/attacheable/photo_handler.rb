module Attacheable
  class PhotoHandler < Mongrel::HttpHandler
    def initialize(prefix, options)
      @prefix = prefix
      @class_name = options[:class_name]
      puts "initialized with prefix: #{prefix}"
    end

    def logger
      ActiveRecord::Base.logger
    end

    def process(request, response)
      if File.exists?(RAILS_ROOT+"/public#{@prefix}/#{request.params["PATH_INFO"]}")
        response.start(200) do |headers, out|
          headers["Content-Type"] = "image/jpeg"
          out.write(File.read(RAILS_ROOT+"/public#{@prefix}/#{request.params["PATH_INFO"]}"))
        end
        return
      end

      start_time = Time.now
      photo, data = @class_name.constantize.data_by_path_info(request.params["PATH_INFO"].split("/"))
      if photo
        response.start(200) do |headers, out|
          headers["Content-Type"] = photo.content_type
          out.write(data)
        end
      else
        response.start(404) do |headers, out|
          headers["Content-Type"] = "text/plain"
          out.write("No such image\n")
        end
      end
      logger.info "Processed request in #{Time.now - start_time} seconds\n  URI: #{request.params["REQUEST_URI"]}\n\n"
    rescue Exception => e
      logger.info "!! Internal server error\nURI: #{request.params["REQUEST_URI"]}\n#{e.backtrace.join("\n")}"
      logger.flush
      response.start(200) do |headers, out|
        headers["Content-Type"] = "text/plain"
        out.write("Some error on server\n")
      end
    end
  end
end