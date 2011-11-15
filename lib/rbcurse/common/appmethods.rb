module RubyCurses
  module Utils
    private
    def _suspend clear=true
      return unless block_given?
      Ncurses.def_prog_mode
      if clear
        Ncurses.endwin 
        # NOTE: avoid false since screen remains half off
        # too many issues
      else
        system "/bin/stty sane"
      end
      yield if block_given?
      Ncurses.reset_prog_mode
      if !clear
        # Hope we don't screw your terminal up with this constantly.
        VER::stop_ncurses
        VER::start_ncurses  
        #@form.reset_all # not required
      end
      @form.repaint if @form
      @window.wrefresh if @window
      Ncurses::Panel.update_panels
    end
    #
    # Suspends to shell so user can execute commands.
    # Maybe not be able to get your prompt correctly.
    # 
    public
    def suspend
      _suspend(false) do
        system("tput cup 26 0")
        system("tput ed")
        system("echo Enter C-d to return to application")
        system (ENV['PS1']='\s-\v\$ ') if ENV['SHELL']== '/bin/bash'
        system(ENV['SHELL']);
      end
    end

    #
    # Displays application help using either array provided
    # or checking for :help_text method
    # @param [Array] help text
    def display_app_help help_array= nil
      if help_array
        arr = help_array
      elsif respond_to? :help_text
        arr = help_text
      else
        arr = []
        arr << "    NO HELP SPECIFIED FOR APP #{self}  "
        arr << "    "
        arr << "     --- General help ---          "
        arr << "    F10         -  exit application "
        arr << "    Alt-x       -  select commands  "
        arr << "    :           -  select commands  "
        arr << "    "
      end
      case arr
      when String
        arr = arr.split("\n")
      when Array
      end
      w = arr.max_by(&:length).length

      require 'rbcurse/extras/viewer'
      RubyCurses::Viewer.view(arr, :layout => [2, 10, [4+arr.size, 24].min, w+2],:close_key => KEY_RETURN, :title => "<Enter> to close", :print_footer => true) do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      t.attr = :reverse
      end
    end
    #
    # prompts user for unix command and displays output in viewer
    # 
    def shell_output
      cmd = get_string("Enter shell command:", 50)
      if cmd && !cmd.empty?
        run_command cmd
      end
    end

    #
    # executes given command and displays in viewer
    # @param [String] unix command, e.g., git -st
    def run_command cmd
      # http://whynotwiki.com/Ruby_/_Process_management#What_happens_to_standard_error_.28stderr.29.3F
      require 'rbcurse/extras/viewer'
      begin
        res = `#{cmd} 2>&1`
      rescue => ex
        res = ex.to_s
        res << ex.backtrace.join("\n") 
      end
      res.gsub!("\t","   ")
      RubyCurses::Viewer.view(res.split("\n"), :close_key => KEY_RETURN, :title => "<Enter> to close, M-l M-h to scroll")
    end
    def shell_out command
      @window.hide
      Ncurses.endwin
      system command
      Ncurses.refresh
      #Ncurses.curs_set 0  # why ?
      @window.show
    end
  end # utils
end # module RubyC
include RubyCurses::Utils
