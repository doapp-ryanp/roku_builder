# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Monitor development Logs
  class Monitor < Util

    # Initialize port config
    def init()
      @ports = {
        main: 8085,
        sg: 8089,
        task1: 8090,
        task2: 8091,
        task3: 8092,
        taskX: 8093,
        profiler: 8080,
      }
      @show_prompt = false
    end

    # Monitor a development log on the Roku device
    # @param type [Symbol] The log type to monitor
    def monitor(type:)
      telnet_config = { 'Host' => @roku_ip_address, 'Port' => @ports[type] }
      waitfor_config = { 'Match' => /./, 'Timeout' => false }

      thread = Thread.new(telnet_config, waitfor_config) {|telnet,waitfor|
        @logger.info "Monitoring #{type} console(#{telnet['Port']}) on #{telnet['Host'] }"
        connection = Net::Telnet.new(telnet)
        Thread.current[:connection] = connection
        all_text = ""
        while true
          connection.waitfor(waitfor) do |txt|
            all_text = manage_text(all_text: all_text, txt: txt)
          end
        end
      }

      init_readline()

      run_prompt(thread: thread)
    end

    private

    # Setup tab completeion for Readline
    def init_readline
      libedit = false
      begin
        Readline.vi_editing_mode
      rescue NotImplementedError
        libedit = true
      end

      commands = [
        "bsc", "bscs", "brkd", "bt", "classes", "cont", "cont", "down", "d",
        "exit", "gc", "help", "last", "list", "next", "print", "p", "?", "step",
        "s", "t", "over", "out", "up", "u", "var", "q"
      ].sort
      commands.collect { |i| i += ' '  } if libedit

      comp = proc { |s| commands.grep( /^#{Regexp.escape(s)}/  )  }

      Readline.completion_append_character = " "
      Readline.completion_proc = comp
    end

    # Check if needs to display prompt, displays prompt, and processes input
    def run_prompt(thread:)
      running = true
      @logger.unknown "Q to exit"
      while running
        begin
          if @show_prompt
            command = Readline.readline('BrightScript Debugger> ', true)
            if command =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == command
              Readline::HISTORY.pop
            end
            case command
            when "q"
              thread.exit
              running = false
            else
              @show_prompt = false
              thread[:connection].puts(command)
            end
          else
            sleep 0.01
          end
        rescue SystemExit, Interrupt
          thread[:connection].puts("\C-c")
        end
      end
    end

    # Handle text from telnet
    #  @param all_text [String] remaining partial line text
    #  @param txt [String] current string from telnet
    #  @return [String] remaining partial line text
    def manage_text(all_text:, txt:)
      all_text += txt
      while line = all_text.slice!(/^.*\n/) do
        puts line if !line.strip.empty?
      end
      if all_text.downcase == "BrightScript Debugger> ".downcase
        @show_prompt = true
        all_text = ""
      end
      all_text
    end
  end
end
