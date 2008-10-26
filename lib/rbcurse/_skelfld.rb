<% xxx="I pity anyone who comes into this file hoping to make some sense" %>
fields = Array.new
<% fsh = @@fields_hash %>
<% wrap_after = @@wrap_after || 3 %>
<% lrow = 0; lcol = 0; %>
<% @@fields_hash["fieldlist"].each_index do |i| %>
<% f = @@fields_hash["fieldlist"][i] %>
<% fhash = @@fields_hash["fields"][f] %>
    #<%= f %>
    <% width = fhash["width"] || 10 
    height = fhash["height"] || 1 
    posx = fhash["position"][0] rescue (lrow+1)* (fsh["spacing"] || 1)
    lrow += 1
    # this is only for queries where there is little space
    lrow = 0 if i == wrap_after-1
    lcol += 30 if i == wrap_after
    posy = fhash["position"][1] rescue "qform_col+#{lcol}"
    fhash[:row] = posx
    #fhash[:col] = posy
    fhash[:label] = fhash["label"] # backward compat with Application.rb
    %>
    field = FIELD.new(<%= height %>, <%= width %>, <%= posx %>, form_col+<%= posy %>, 0, 0)
    field.user_object = <%=fhash.inspect %>
    field.user_object[:col] = form_col+<%= posy %>
    <% if fhash.include?"field_back" %>
    field.set_field_back(A_<%= fhash["field_back"] %>)
    <% end %>
    <% if fhash.include?"post_proc" %>
      field.user_object["post_proc"]=<%= fhash["post_proc"] %>
    <% end %>
    <% if fhash.include?"default" %>
    <% xx = eval(fhash["default"]) rescue nil; %>
      <% if !xx.nil? and xx.respond_to? :call %>
      field.user_object["default"]=<%= fhash["default"] %>
    <% end %>
    <% end %>
 <% if fhash.include?"opts_off"
    optsoff=fhash["opts_off"]
    optsoff.each { |opt|
 %> field.field_opts_off(<%= opt%>); 
      <% } %>
 <% end %>
 <% if fhash.include?"opts_on"
      optson=fhash["opts_on"]
      optson.each { |opt|
 %> field.field_opts_on(<%= opt%>); 
        <% } %>
 <% end %>
        <% 
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
 myatts=%w[just fore pad]
        myatts.each { |att|
          fatt="field_#{att}"
   if fhash.include?"#{att}" or fhash.include?"#{fatt}"
            attv = fhash[att] || fhash[fatt]
            if att == "fore" 
              attv = "Ncurses.COLOR_PAIR(#{attv})"
            end
 %> field.set_field_<%=att%>(<%= attv %>); 
   <% end %>
            <% } %>
    fields.push(field)
            <% end %>
            <% @@fields_hash["fieldlist"].each_index do |i| %>
            <% f = @@fields_hash["fieldlist"][i] %>
            <% fhash = @@fields_hash["fields"][f] %>
    #<%= f %>
            <% fieldtype = fhash["fieldtype"] || 'NOTSET_IGNORE'
            ft = fieldtype.to_s
            if fieldtype.is_a?(Array)
              ft=fieldtype[0].to_s
            end
            case ft
            when 'ALNUM' :  %>
    fields[<%= i %>].set_field_type(TYPE_ALNUM, <%= fhash["min_data_width"] ||  0 %>);
              <% when 'ALPHA' :  %>
    fields[<%= i %>].set_field_type(TYPE_ALPHA, <%= fhash["min_data_width"]||  0 %>);
              <% when 'INTEGER' :  %>
              <% if fhash["range"] == nil 
              fhash["range"] = [0,10000]
              end %>
    fields[<%= i %>].set_field_type(TYPE_INTEGER, <%= fhash["padding"] || 2 %>,<%= fhash["range"][0] || 0 %>,<%= fhash["range"][1] || 10000 %> );
    fields[<%= i %>].set_field_just(JUSTIFY_RIGHT)
              <% when 'NUMERIC' :  %>
              <% if fhash["range"] == nil 
              fhash["range"] = [0,10000]
              end %>
    fields[<%= i %>].set_field_type(TYPE_NUMERIC, <%= fhash["padding"] || 2 %>,<%= fhash["range"][0] ||  0 %>,<%= fhash["range"][1] || 10000 %> );
    fields[<%= i %>].set_field_just(JUSTIFY_RIGHT)
              <% when 'ENUM' :  %>
    fields[<%= i %>].set_field_type(TYPE_ENUM, <%= fhash["values"] %>,<%= fhash["checkcase"] || false %>,<%= fhash["checkunique"] || false %> );
              <% when 'REGEXP' :  %>
    fields[<%= i %>].set_field_type(TYPE_REGEXP, "<%= fhash["fieldtype"][1] %>");
              <% when 'CUSTOM' :  %>
    customtype<%= i %> = FIELDTYPE.new(<%= fhash["fieldtype"][1]%>,<%= fhash["fieldtype"][2]%>)
    fields[<%= i %>].set_field_type(customtype<%= i %>);
              <% else %>
              <% end %>
              <% end %>
 ###- SET FIELD DEFAULTS THIS IS DONE BY set_default in the form no need here
            <% @@fields_hash["fieldlist"].each_index do |i| %>
            <% f = @@fields_hash["fieldlist"][i] %>
            <% fhash = @@fields_hash["fields"][f] %>
    #<%= f %>
            <% fielddef = fhash["default"] 
                if fielddef != nil %>
                  #fields[<%= i %>].set_value(<%= fielddef %>.to_s)
                  #fields[<%= i %>].set_field_status(false) # won't be seen as modified
                  <% end 
              end %>
