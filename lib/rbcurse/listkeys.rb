module RubyCurses
  module ListKeys
    ## Note: keeping variables gives the false feeling that one can change the var anytime.
    # That was possible earlier, but now that i am binding the key at construction time
    # any changes to the vars after construction won't have an effect.
    def install_list_keys
      @KEY_ROW_SELECTOR ||= ?\C-x
      @KEY_GOTO_TOP ||= ?\M-0
      @KEY_GOTO_BOTTOM ||= ?\M-9
      #@KEY_ASK_FIND_FORWARD ||= ?\M-f
      #@KEY_ASK_FIND_BACKWARD ||= ?\M-F
      #@KEY_FIND_NEXT ||= ?\M-g
      #@KEY_FIND_PREV ||= ?\M-G
      @KEY_SCROLL_FORWARD ||= ?\C-n
      @KEY_SCROLL_BACKWARD ||= ?\C-p
      @KEY_SCROLL_RIGHT ||= ?\M-8
      @KEY_SCROLL_LEFT ||= ?\M-7

      @KEY_CLEAR_SELECTION ||= ?\M-e
      @KEY_PREV_SELECTION ||= ?\M-"
      @KEY_NEXT_SELECTION ||= ?\M-'

=begin
      bind_key(@KEY_ROW_SELECTOR)  { toggle_row_selection }
      bind_key(@KEY_GOTO_TOP)      { goto_top }
      bind_key(@KEY_GOTO_BOTTOM)   { goto_bottom }
      bind_key(@KEY_CLEAR_SELECTION) { clear_selection }
      bind_key(@KEY_ASK_FIND_FORWARD) { ask_search_forward }
      bind_key(@KEY_ASK_FIND_BACKWARD) { ask_search_backward }
      bind_key(@KEY_FIND_NEXT) { find_next }
      bind_key(@KEY_FIND_PREV) { find_prev }
=end
    end
  end
end
